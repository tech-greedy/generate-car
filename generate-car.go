package main

import (
	"context"
	"fmt"
	"github.com/tech-greedy/go-generate-car/util"
	"io"
	"os"
)

func main() {
	ctx := context.Background()
	fileList := []util.Finfo{
		{
			Path:  "util/chunk.go",
			Name:  "chunk.go",
			Size:  8766,
			Start: 0,
			End:   0,
		},
		{
			Path:  "util/stream-commp.go",
			Name:  "stream-commp.go",
			Size:  4610,
			Start: 0,
			End:   0,
		},
	}

	parentPath := ""
	parallel := 1


	carF, err := os.Create("test.car")
	if err != nil {
		panic(err)
	}
	defer carF.Close()
	piper, pipew := io.Pipe()
	go func() {
		util.CalculateCommp(piper)
	}()

	writer := io.MultiWriter(carF, pipew)
	defer carF.Close()
	defer pipew.Close()
	ipld, cid, err := util.GenerateCar(ctx, fileList, parentPath, writer, parallel)
	if err != nil {
		panic(err)
	}
	fmt.Printf("ipld: %s\n", ipld)
	fmt.Printf("cid: %s\n", cid)

}