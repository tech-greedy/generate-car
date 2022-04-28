.PHONY: build ffi all

all: build

build:
	go build -ldflags "-s -w" -o generate-car ./generate-car.go
