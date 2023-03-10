package util

import (
	"bufio"
	"context"
	"encoding/json"
	"github.com/ipfs/go-blockservice"
	"github.com/ipfs/go-cid"
	"github.com/ipfs/go-datastore"
	bstore "github.com/ipfs/go-ipfs-blockstore"
	ipld "github.com/ipfs/go-ipld-format"
	"github.com/ipfs/go-merkledag"
	"github.com/ipfs/go-unixfs"
	uio "github.com/ipfs/go-unixfs/io"
	unixfs_pb "github.com/ipfs/go-unixfs/pb"
	"github.com/ipld/go-car"
	"github.com/pkg/errors"
	"io"
	"strings"
)

type FileInfo struct {
	Path  string
	Size  uint64
	Start uint64
	End   uint64
	Cid   string
}

type FsType int

const (
	Dir FsType = iota
	File
)

type FsEntry struct {
	Type       FsType
	Chunks     []FileInfo
	SubEntries map[string]*FsEntry
}

func getNode(ctx context.Context, entry *FsEntry, dagServ ipld.DAGService, fakeNodes []cid.Cid) (ipld.Node, []cid.Cid, error) {
	cidBuilder := merkledag.V1CidPrefix()
	switch entry.Type {
	case Dir:
		dir := uio.NewDirectory(dagServ)
		dir.SetCidBuilder(cidBuilder)
		for name, subEntry := range entry.SubEntries {
			subNode, newFakeNodes, err := getNode(ctx, subEntry, dagServ, fakeNodes)
			if err != nil {
				return nil, nil, errors.Wrapf(err, "failed to get node for sub entry %s", name)
			}
			fakeNodes = newFakeNodes
			err = dir.AddChild(ctx, name, subNode)
			if err != nil {
				return nil, nil, errors.Wrapf(err, "failed to add child %s to directory", name)
			}
		}
		node, err := dir.GetNode()
		if err != nil {
			return nil, nil, errors.Wrap(err, "failed to get node from directory")
		}
		err = dagServ.Add(ctx, node)
		if err != nil {
			return nil, nil, errors.Wrap(err, "failed to add node to dag service")
		}
		return node, fakeNodes, nil
	case File:
		if len(entry.Chunks) == 1 {
			cid, err := cid.Parse(entry.Chunks[0].Cid)
			if err != nil {
				return nil, nil, errors.Wrap(err, "failed to parse cid")
			}
			node := NewFakeFSNode(entry.Chunks[0].Size, cid)
			// Add to dag service temporarily and delete later because this is a fake node
			err = dagServ.Add(ctx, node)
			if err != nil {
				return nil, nil, errors.Wrap(err, "failed to add node to dag service")
			}
			fakeNodes = append(fakeNodes, cid)
			return &node, fakeNodes, nil
		} else {
			node := unixfs.NewFSNode(unixfs_pb.Data_File)
			var links []ipld.Link
			for _, chunk := range entry.Chunks {
				size := chunk.End - chunk.Start
				cid, err := cid.Parse(chunk.Cid)
				if err != nil {
					return nil, nil, errors.Wrap(err, "failed to parse cid")
				}
				links = append(links, ipld.Link{
					Name: "",
					Cid:  cid,
					Size: size,
				})
				node.AddBlockSize(size)
			}
			nodeBytes, err := node.GetBytes()
			if err != nil {
				return nil, nil, errors.Wrap(err, "failed to get bytes from fs node")
			}
			pbNode := merkledag.NodeWithData(nodeBytes)
			pbNode.SetCidBuilder(merkledag.V1CidPrefix())
			for _, link := range links {
				err = pbNode.AddRawLink("", &link)
				if err != nil {
					return nil, nil, errors.Wrap(err, "failed to add link to node")
				}
			}
			err = dagServ.Add(ctx, pbNode)
			if err != nil {
				return nil, nil, errors.Wrap(err, "failed to add node to dag service")
			}
			return pbNode, fakeNodes, nil
		}
	}
	return nil, nil, errors.New("invalid entry type")
}

func GenerateIpldCar(ctx context.Context, input io.Reader, writer io.Writer) (cid.Cid, error) {
	scanner := bufio.NewScanner(input)
	blockStore := bstore.NewBlockstore(datastore.NewMapDatastore())
	dagServ := merkledag.NewDAGService(blockservice.New(blockStore, nil))
	rootDir := FsEntry{
		Type:       Dir,
		SubEntries: make(map[string]*FsEntry),
	}
	// Fill up the tree with Type, Chunks and SubEntries
	for scanner.Scan() {
		line := scanner.Text()
		var finfo FileInfo
		err := json.Unmarshal([]byte(line), &finfo)
		if err != nil {
			return cid.Undef, errors.Wrap(err, "failed to unmarshal json")
		}

		relPath := finfo.Path
		relSegments := strings.Split(relPath, "/")
		pos := &rootDir
		for i, seg := range relSegments {
			last := i == len(relSegments)-1
			subEntry, ok := pos.SubEntries[seg]
			if !ok {
				if last {
					// Must be a file
					subEntry = &FsEntry{
						Type:   File,
						Chunks: make([]FileInfo, 0),
					}
					subEntry.Chunks = append(subEntry.Chunks, finfo)
				} else {
					// Must be a directory
					subEntry = &FsEntry{
						Type:       Dir,
						SubEntries: make(map[string]*FsEntry),
					}
				}
				pos.SubEntries[seg] = subEntry
				pos = subEntry
			} else {
				if last {
					// Must be a file
					subEntry.Chunks = append(subEntry.Chunks, finfo)
				} else {
					// Must be a directory
					pos = subEntry
				}
			}
		}
	}

	// Now iterate over the tree and create the IPLD nodes
	fakeNodes := make([]cid.Cid, 0)
	rootNode, newFakeNodes, err := getNode(ctx, &rootDir, dagServ, fakeNodes)
	if err != nil {
		return cid.Undef, errors.Wrap(err, "failed to get root node")
	}
	// Remove the fake nodes from dag service so that they don't get written to the car file
	err = dagServ.RemoveMany(ctx, newFakeNodes)
	if err != nil {
		return cid.Undef, errors.Wrap(err, "failed to remove fake nodes from dag service")
	}
	err = car.WriteCar(ctx, dagServ, []cid.Cid{rootNode.Cid()}, writer, merkledag.IgnoreMissing())
	if err != nil {
		return cid.Undef, errors.Wrap(err, "failed to write car file")
	}
	return rootNode.Cid(), nil
}
