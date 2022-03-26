package util

import (
	"github.com/filecoin-project/go-commp-utils/writer"
	"github.com/ipfs/go-cidutil/cidenc"
	"github.com/multiformats/go-multibase"
	"golang.org/x/xerrors"
	"io"
)

func CalculateCommp(reader io.Reader) (commCid string, pieceSize uint64, err error) {
	w := &writer.Writer{}
	_, err = io.CopyBuffer(w, reader, make([]byte, writer.CommPBuf))
	if err != nil {
		return "", 0, xerrors.Errorf("copy into commp writer: %w", err)
	}

	commp, err := w.Sum()
	if err != nil {
		return "", 0, xerrors.Errorf("computing commP failed: %w", err)
	}

	encoder := cidenc.Encoder{Base: multibase.MustNewEncoder(multibase.Base32)}
	return encoder.Encode(commp.PieceCID), uint64(commp.PieceSize.Unpadded().Padded()), nil
}
