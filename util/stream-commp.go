package util

import (
	"bufio"
	commcid "github.com/filecoin-project/go-fil-commcid"
	commp "github.com/filecoin-project/go-fil-commp-hashhash"
	"github.com/ipfs/go-cid"
	cbor "github.com/ipfs/go-ipld-cbor"
	"io"
	"io/ioutil"
	"log"
)

type CarHeader struct {
	Roots   []cid.Cid
	Version uint64
}

func init() {
	cbor.RegisterCborType(CarHeader{})
}

const BufSize = (4 << 20) / 128 * 127

func CalculateCommpHashHash(reader io.Reader, PadPieceSize uint64) (commCid cid.Cid, pieceSize uint64, err error) {
	cp := new(commp.Calc)
	streamBuf := bufio.NewReaderSize(
		io.TeeReader(reader, cp),
		BufSize,
	)
	var streamLen int64
	// read out remainder into the hasher, if any
	n, err := io.Copy(ioutil.Discard, streamBuf)
	streamLen += n
	if err != nil && err != io.EOF {
		log.Printf("unexpected error at offset %d: %s\n", streamLen, err)
		return
	}

	rawCommP, pieceSize, err := cp.Digest()
	if err != nil {
		log.Println(err)
		return
	}

	if PadPieceSize > 0 {
		rawCommP, err = commp.PadCommP(
			rawCommP,
			pieceSize,
			PadPieceSize,
		)
		if err != nil {
			log.Println(err)
			return
		}
		pieceSize = PadPieceSize
	}

	commCid, err = commcid.DataCommitmentV1ToCID(rawCommP)
	if err != nil {
		log.Println(err)
		return
	}
	return
}
