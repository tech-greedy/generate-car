package main

import (
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"github.com/google/uuid"
	"github.com/tech-greedy/go-generate-car/util"
	"io"
	"os"
	"path"
	"strconv"
)

type CommpResult struct {
	commp     string
	pieceSize uint64
}

type Result struct {
	Ipld      *util.FsNode
	DataCid   string
	PieceCid  string
	PieceSize uint64
}

func main() {
	ctx := context.Background()
	reader := bufio.NewReader(os.Stdin)
	buf := new(bytes.Buffer)
	_, err := buf.ReadFrom(reader)
	if err != nil {
		panic(err)
	}
	var fileList []util.Finfo
	err = json.Unmarshal(buf.Bytes(), &fileList)
	if err != nil {
		panic(err)
	}

	// ./generate-car [parentPath] [outPath] [parallelism]
	parentPath := ""
	if len(os.Args) >= 2 {
		parentPath = os.Args[1]
	}

	outPath := "."
	if len(os.Args) >= 3 {
		outPath = os.Args[2]
	}

	parallel := 3
	if len(os.Args) >= 4 {
		parallel, _ = strconv.Atoi(os.Args[2])
	}

	outFilename := uuid.New().String() + ".car"
	carF, err := os.Create(path.Join(outPath, outFilename))
	if err != nil {
		panic(err)
	}
	piper, pipew := io.Pipe()
	ch := make(chan CommpResult)
	go func() {
		commp, pieceSize, err := util.CalculateCommp(piper)
		if err != nil {
			panic(err)
		}
		ch <- CommpResult{commp: commp, pieceSize: pieceSize}
	}()

	writer := io.MultiWriter(carF, pipew)
	ipld, cid, err := util.GenerateCar(ctx, fileList, parentPath, writer, parallel)
	if err != nil {
		panic(err)
	}
	err = pipew.Close()
	if err != nil {
		panic(err)
	}
	err = carF.Close()
	if err != nil {
		panic(err)
	}
	err = os.Rename(path.Join(outPath, outFilename), path.Join(outPath, cid+".car"))
	if err != nil {
		panic(err)
	}
	commpResult := <-ch
	output, err := json.Marshal(Result{
		Ipld:      ipld,
		DataCid:   cid,
		PieceCid:  commpResult.commp,
		PieceSize: commpResult.pieceSize,
	})
	if err != nil {
		panic(err)
	}
	fmt.Println(string(output))
}
