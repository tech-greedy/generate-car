package util

import (
	"github.com/ipfs/go-cid"
	ipld "github.com/ipfs/go-ipld-format"
	"github.com/pkg/errors"
)

type FakeFSNode struct {
	size uint64
	cid  cid.Cid
}

var ErrEmptyNode error = errors.New("fake fs node")

func NewFakeFSNode(size uint64, cid cid.Cid) FakeFSNode {
	return FakeFSNode{size: size, cid: cid}
}

func (f FakeFSNode) RawData() []byte {
	return nil
}

func (f FakeFSNode) Cid() cid.Cid {
	return f.cid
}

func (f FakeFSNode) String() string {
	return "FakeFSNode - " + f.cid.String()
}

func (f FakeFSNode) Loggable() map[string]interface{} {
	return nil
}

func (f FakeFSNode) Resolve(path []string) (interface{}, []string, error) {
	return nil, nil, ErrEmptyNode
}

func (f FakeFSNode) Tree(path string, depth int) []string {
	return nil
}

func (f FakeFSNode) ResolveLink(path []string) (*ipld.Link, []string, error) {
	return nil, nil, ErrEmptyNode
}

func (f FakeFSNode) Copy() ipld.Node {
	return &FakeFSNode{size: f.size, cid: f.cid}
}

func (f FakeFSNode) Links() []*ipld.Link {
	return nil
}

func (f FakeFSNode) Stat() (*ipld.NodeStat, error) {
	return &ipld.NodeStat{}, nil
}

func (f FakeFSNode) Size() (uint64, error) {
	return f.size, nil
}
