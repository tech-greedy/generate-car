package util

import (
	"fmt"
	"github.com/filecoin-project/go-commp-utils/writer"
	"github.com/ipfs/go-cidutil/cidenc"
	"github.com/multiformats/go-multibase"
	"golang.org/x/xerrors"
	"io"
)

func CalculateCommp(reader io.Reader) (commCid string, err error) {
	w := &writer.Writer{}
	_, err = io.CopyBuffer(w, reader, make([]byte, writer.CommPBuf))
	if err != nil {
		return "", xerrors.Errorf("copy into commp writer: %w", err)
	}

	commp, err := w.Sum()
	if err != nil {
		return "", xerrors.Errorf("computing commP failed: %w", err)
	}

	encoder := cidenc.Encoder{Base: multibase.MustNewEncoder(multibase.Base32)}

	fmt.Println("CommP CID: ", encoder.Encode(commp.PieceCID))
	fmt.Println("Piece size: ", uint64(commp.PieceSize.Unpadded().Padded()))
	return encoder.Encode(commp.PieceCID), nil
}