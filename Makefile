.PHONY: build ffi all test

all: build

build:
	go build -ldflags "-s -w" -o generate-car ./generate-car.go

test:
	bundle2.7 exec rspec -f d
