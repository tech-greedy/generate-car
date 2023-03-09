.PHONY: build ffi all test

all: build

build:
	go build -ldflags "-s -w" -o generate-car ./cmd/generate-car/generate-car.go
	go build -ldflags "-s -w" -o generate-ipld-car ./cmd/generate-ipld-car/main.go

test:
	bundle exec rspec -f d
