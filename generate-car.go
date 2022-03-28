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

type Input struct {
	ParentPath  string
	OutPath     string
	Parallelism int
	FileList    []util.Finfo
}

func main() {
	ctx := context.Background()
	reader := bufio.NewReader(os.Stdin)
	buf := new(bytes.Buffer)
	_, err := buf.ReadFrom(reader)
	if err != nil {
		panic(err)
	}
	var input Input
	err = json.Unmarshal(buf.Bytes(), &input)
	if err != nil {
		panic(err)
	}

	if input.Parallelism == 0 {
		input.Parallelism = 1
	}

	if input.OutPath == "" {
		input.OutPath = "."
	}

	outFilename := uuid.New().String() + ".car"
	carF, err := os.Create(path.Join(input.OutPath, outFilename))
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
	ipld, cid, err := util.GenerateCar(ctx, input.FileList, input.ParentPath, writer, input.Parallelism)
	if err != nil {
		carF.Close()
		pipew.Close()
		os.Remove(path.Join(input.OutPath, outFilename))
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
	err = os.Rename(path.Join(input.OutPath, outFilename), path.Join(input.OutPath, cid+".car"))
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
