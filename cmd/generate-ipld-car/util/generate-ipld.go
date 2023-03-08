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
	"path/filepath"
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

func getNode(ctx context.Context, entry *FsEntry, dagServ ipld.DAGService) (ipld.Node, error) {
	cidBuilder := merkledag.V1CidPrefix()
	switch entry.Type {
	case Dir:
		dir := uio.NewDirectory(dagServ)
		dir.SetCidBuilder(cidBuilder)
		for name, subEntry := range entry.SubEntries {
			subNode, err := getNode(ctx, subEntry, dagServ)
			if err != nil {
				return nil, errors.Wrap(err, "failed to get node for sub entry")
			}
			err = dir.AddChild(ctx, name, subNode)
			if err != nil {
				return nil, errors.Wrap(err, "failed to add child to directory")
			}
		}
		node, err := dir.GetNode()
		if err != nil {
			return nil, errors.Wrap(err, "failed to get node from directory")
		}
		err = dagServ.Add(ctx, node)
		if err != nil {
			return nil, errors.Wrap(err, "failed to add node to dag service")
		}
		return node, nil
	case File:
		if len(entry.Chunks) == 1 {
			cid, err := cid.Parse(entry.Chunks[0].Cid)
			if err != nil {
				return nil, errors.Wrap(err, "failed to parse cid")
			}
			node := NewFakeFSNode(entry.Chunks[0].Size, cid)
			/* Do not add to dag service because this is a fake node
			err = dagServ.Add(ctx, node)
			if err != nil {
				return nil, errors.Wrap(err, "failed to add node to dag service")
			}
			*/
			return &node, nil
		} else {
			node := unixfs.NewFSNode(unixfs_pb.Data_File)
			var links []ipld.Link
			for _, chunk := range entry.Chunks {
				size := chunk.End - chunk.Start
				cid, err := cid.Parse(chunk.Cid)
				if err != nil {
					return nil, errors.Wrap(err, "failed to parse cid")
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
				return nil, errors.Wrap(err, "failed to get bytes from fs node")
			}
			pbNode := merkledag.NodeWithData(nodeBytes)
			pbNode.SetCidBuilder(merkledag.V1CidPrefix())
			for _, link := range links {
				err = pbNode.AddRawLink("", &link)
				if err != nil {
					return nil, errors.Wrap(err, "failed to add link to node")
				}
			}
			err = dagServ.Add(ctx, pbNode)
			if err != nil {
				return nil, errors.Wrap(err, "failed to add node to dag service")
			}
			return pbNode, nil
		}
	}
	return nil, errors.New("invalid entry type")
}

func GenerateIpldCar(ctx context.Context, input io.Reader, parent string, writer io.Writer) (cid.Cid, error) {
	scanner := bufio.NewScanner(input)
	parentPath, err := filepath.Abs(parent)
	if err != nil {
		return cid.Undef, errors.Wrap(err, "failed to get absolute path of parent")
	}

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

		fPath, err := filepath.Abs(finfo.Path)
		if err != nil {
			return cid.Undef, errors.Wrap(err, "failed to get absolute path of file")
		}

		relPath, err := filepath.Rel(parentPath, fPath)
		relSegments := strings.Split(relPath, string(filepath.Separator))
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
	rootNode, err := getNode(ctx, &rootDir, dagServ)
	if err != nil {
		return cid.Undef, errors.Wrap(err, "failed to get root node")
	}
	err = car.WriteCar(ctx, dagServ, []cid.Cid{rootNode.Cid()}, writer, merkledag.IgnoreMissing())
	if err != nil {
		return cid.Undef, errors.Wrap(err, "failed to write car file")
	}
	return rootNode.Cid(), nil
}
