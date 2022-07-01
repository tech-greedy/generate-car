package util

import (
	"context"
	"fmt"
	"os"
	"testing"
)

type noopWriter struct {
}

func (nw *noopWriter) Write(p []byte) (n int, err error) {
	return len(p), nil
}

func TestGenerateCar(t *testing.T) {
	fmt.Println(os.Getwd())
	carF, err := os.Create("../test/test.car")
	dag, cid, cidMap, err := GenerateCar(context.TODO(), []Finfo{
		{
			Path:  "../test/test.txt",
			Size:  4038,
			Start: 1,
			End:   4038,
		},
	}, "../", "", carF)
	fmt.Println(dag)
	fmt.Println(cid)
	fmt.Println(err)
	fmt.Println(cidMap)
}
