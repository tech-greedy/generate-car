package main

import (
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"github.com/google/uuid"
	"github.com/ipfs/go-cid"
	"github.com/tech-greedy/go-generate-car/util"
	"github.com/urfave/cli/v2"
	"io"
	"log"
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

type Input []util.Finfo

func main() {
	ctx := context.TODO()
	app := &cli.App{
		Name:  "generate-car",
		Usage: "generate car archive from list of files and compute commp in the mean time",
		Flags: []cli.Flag{
			&cli.StringFlag{
				Name:    "input",
				Aliases: []string{"i"},
				Usage:   "File to read list of files, or '-' if from stdin",
				Value:   "-",
			},
			&cli.Uint64Flag{
				Name:    "piece-size",
				Aliases: []string{"s"},
				Usage:   "Target piece size, default to minimum possible value",
				Value:   0,
			},
			&cli.StringFlag{
				Name:    "out-dir",
				Aliases: []string{"o"},
				Usage:   "Output directory to save the car file",
				Value:   ".",
			},
			&cli.StringFlag{
				Name:     "parent",
				Aliases:  []string{"p"},
				Usage:    "Parent path of the dataset",
				Required: true,
			},
		},
		Action: func(c *cli.Context) error {
			inputFile := c.String("input")
			pieceSize := c.Uint64("piece-size")
			outDir := c.String("out-dir")
			parent := c.String("parent")
			var inputBytes []byte
			if inputFile == "-" {
				reader := bufio.NewReader(os.Stdin)
				buf := new(bytes.Buffer)
				_, err := buf.ReadFrom(reader)
				if err != nil {
					return err
				}
				inputBytes = buf.Bytes()
			} else {
				bytes, err := os.ReadFile(inputFile)
				if err != nil {
					return err
				}
				inputBytes = bytes
			}
			var input Input
			err := json.Unmarshal(inputBytes, &input)
			if err != nil {
				return err
			}

			outFilename := uuid.New().String() + ".car"
			outPath := path.Join(outDir, outFilename)
			carF, err := os.Create(outPath)
			if err != nil {
				return err
			}
			piper, pipew := io.Pipe()
			ch := make(chan CommpResult)
			go func() {
				var commp cid.Cid
				var p uint64
				commp, p, err = util.CalculateCommpHashHash(piper, pieceSize)
				if err != nil {
					panic(err)
				}
				ch <- CommpResult{commp: commp.String(), pieceSize: p}
			}()

			writer := io.MultiWriter(carF, pipew)
			ipld, cid, err := util.GenerateCar(ctx, input, parent, writer)
			if err != nil {
				carF.Close()
				pipew.Close()
				os.Remove(outPath)
				return err
			}
			err = pipew.Close()
			if err != nil {
				return err
			}
			err = carF.Close()
			if err != nil {
				return err
			}
			err = os.Rename(outPath, path.Join(outDir, cid+".car"))
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
				return err
			}
			fmt.Println(string(output))
			return nil
		},
	}
	err := app.Run(os.Args)
	if err != nil {
		log.Fatal(err)
	}
}
