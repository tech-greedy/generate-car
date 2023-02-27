.PHONY: build ffi all test

all: build

build:
	go build -ldflags "-s -w" -o generate-car ./generate-car.go

test:
	bundle exec rspec -f d
