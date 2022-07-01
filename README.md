# go-generate-car
A simple CLI to generate car file and compute commp at the same time.

[![Pull Request](https://github.com/tech-greedy/go-generate-car/actions/workflows/pull-request.yml/badge.svg)](https://github.com/tech-greedy/go-generate-car/actions/workflows/pull-request.yml)

```shell
$ ./go-generate-car -h
NAME:
   generate-car - generate car archive from list of files and compute commp in the mean time

USAGE:
   generate-car [global options] command [command options] [arguments...]

COMMANDS:
   help, h  Shows a list of commands or help for one command

GLOBAL OPTIONS:
   --input value, -i value       File to read list of files, or '-' if from stdin (default: "-")
   --piece-size value, -s value  Target piece size, default to minimum possible value (default: 0)
   --out-dir value, -o value     Output directory to save the car file (default: ".")
   --tmp-dir value, -t value     Optionally copy the files to a temporary (and much faster) directory
   --parent value, -p value      Parent path of the dataset
   --help, -h                    show help (default: false)
```

The input file can be a text file that contains a list of file information SORTED by the path. i.e.
```json
[
  {
    "Path": "test/test.txt",
    "Size": 4038,
    "Start": 1000, # Inclusive
    "End": 2000 # Exclusive
  },
  {
    "Path": "test/test2.txt",
    "Size": 3089
  }
]
```

The tmp dir is useful when the dataset source is on slow storage such as NFS or S3FS/Goofys mount.