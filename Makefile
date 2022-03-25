.PHONY: build ffi all

all: ffi build

build:
	go build -ldflags "-s -w" -o generate-car ./generate-car.go

## FFI

ffi: 
	./extern/filecoin-ffi/install-filcrypto
