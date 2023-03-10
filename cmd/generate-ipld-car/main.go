package main

import (
	"bufio"
	"context"
	"encoding/json"
	"fmt"
	commcid "github.com/filecoin-project/go-fil-commcid"
	commp "github.com/filecoin-project/go-fil-commp-hashhash"
	"github.com/google/uuid"
	"github.com/pkg/errors"
	"github.com/tech-greedy/generate-car/cmd/generate-ipld-car/util"
	"github.com/urfave/cli/v2"
	"io"
	"os"
	"path"
	"path/filepath"
)

type Result struct {
	DataCid   string
	PieceCid  string
	PieceSize uint64
}

const BufSize = (4 << 20) / 128 * 127

func main() {
	app := &cli.App{
		Name:  "generate-ipld-car",
		Usage: "generate ipld car archive from list of files and compute commp in the mean time. The generated car file only contains the file and folder information, not the actual data.",
		Flags: []cli.Flag{
			&cli.StringFlag{
				Name:    "input",
				Aliases: []string{"i"},
				Usage:   "This is a ndjson file containing the list of files to be included in the car archive. If not specified, use stdin instead.",
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
		}, Action: func(c *cli.Context) error {
			inputFile := c.String("input")
			pieceSizeInput := c.Uint64("piece-size")
			outDir := c.String("out-dir")
			var in *os.File
			if inputFile == "-" {
				in = os.Stdin
			} else {
				inFile, err := os.Open(inputFile)
				if err != nil {
					return errors.Wrap(err, "failed to open input file")
				}

				in = inFile
			}

			defer in.Close()
			outFilename := uuid.New().String() + ".car"
			outPath := filepath.Join(outDir, outFilename)
			carF, err := os.Create(outPath)
			if err != nil {
				return errors.Wrap(err, "failed to create car file")
			}

			cp := new(commp.Calc)
			writer := bufio.NewWriterSize(io.MultiWriter(carF, cp), BufSize)
			cid, err := util.GenerateIpldCar(context.TODO(), in, writer)
			if err != nil {
				return errors.Wrap(err, "failed to generate car file")
			}
			err = writer.Flush()
			if err != nil {
				return errors.Wrap(err, "failed to flush writer")
			}
			err = carF.Close()
			if err != nil {
				return errors.Wrap(err, "failed to close car file")
			}
			rawCommP, pieceSize, err := cp.Digest()
			if err != nil {
				return errors.Wrap(err, "failed to compute commp")
			}
			if pieceSizeInput > 0 {
				rawCommP, err = commp.PadCommP(
					rawCommP,
					pieceSize,
					pieceSizeInput,
				)
				if err != nil {
					return err
				}
				pieceSize = pieceSizeInput
			}
			commCid, err := commcid.DataCommitmentV1ToCID(rawCommP)
			if err != nil {
				return errors.Wrap(err, "failed to convert commp to cid")
			}
			err = os.Rename(outPath, path.Join(outDir, commCid.String()+".car"))
			if err != nil {
				return errors.Wrap(err, "failed to rename car file")
			}
			output, err := json.Marshal(Result{
				DataCid:   cid.String(),
				PieceCid:  commCid.String(),
				PieceSize: pieceSize,
			})
			if err != nil {
				return errors.Wrap(err, "failed to marshal result")
			}
			fmt.Println(string(output))
			return nil
		},
	}
	err := app.Run(os.Args)
	if err != nil {
		panic(err)
	}
}
