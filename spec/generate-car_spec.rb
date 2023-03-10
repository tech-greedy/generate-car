require 'json'
require 'fileutils'

def importToIpfs(path)
  out = `ipfs add -Q --cid-version=1 #{path}`
  out.strip
end

describe "GenerateIpldCar" do
  after :each do
    FileUtils.rm_rf('test_ipld')
    FileUtils.rm_rf('test_output')
    FileUtils.rm_rf('test_ipld_out')
  end

  it 'should be able to resolve file via ipfs' do
    numberOfFiles = 5000
    cidMap = {}

    # Create a directory with a subdirectory that contains 10k small files
    FileUtils.mkdir_p('test_ipld/test_small_files')
    FileUtils.mkdir_p('test_output')
    numberOfFiles.times do |i|
      path = "test_ipld/test_small_files/#{i}.txt"
      File.write(path, i.to_s)
      cidMap[path] = importToIpfs(path)
    end

    # Create a directory with 10k subdirectories, each containing a single file
    FileUtils.mkdir_p('test_ipld/test_many_dirs')
    numberOfFiles.times do |i|
      FileUtils.mkdir_p("test_ipld/test_many_dirs/#{i}")
      path = "test_ipld/test_many_dirs/#{i}/#{i}.txt"
      File.write(path, i.to_s)
      cidMap[path] = importToIpfs(path)
    end

    # Create a file that is 100MB in size and the content randomly generated from a constant seed
    File.open('test_ipld/test_large_file.txt', 'wb') do |f|
      f.write(Random.new(0).bytes(100_000_000))
    end
    cidMap['test_ipld/test_large_file.txt'] = importToIpfs('test_ipld/test_large_file.txt')

    # Create a few files that are 1MB in size and the content randomly generated from a constant seed
    content = ''
    10.times do |i|
      path = "test_ipld/test_many_files_#{i}.txt"
      File.open(path, 'wb') do |f|
        fileContent = Random.new(i).bytes(1_000_000)
        content += fileContent
        f.write(fileContent)
      end
      cidMap[path] = importToIpfs(path)
    end

    # Create a file that comes from all aggregated content of above files
    File.open('test_ipld/test_aggregated_file.txt', 'wb') do |f|
      f.write(content)
    end

    # Create the input for generate-ipld-car
    File.open('test_output/test.ndjson', 'w') do |f|
      cidMap.each do |path, cid|
        size = File.size(path)
        f.write({Path: path, Cid: cid, Size: size, Start: 0, End: size}.to_json + "\n")
      end
      10.times do |i|
        target = 'test_ipld/test_aggregated_file.txt'
        path = "test_ipld/test_many_files_#{i}.txt"
        f.write({Path: target, Cid: cidMap[path], Size: 10_000_000, Start: i *  1_000_000, End: (i + 1) * 1_000_000}.to_json + "\n")
      end
    end

    out = `./generate-ipld-car -i test_output/test.ndjson -o test_output`
    puts out
    result = JSON.parse(out)
    dataCid = result['DataCid']
    pieceCid = result['PieceCid']

    # Now import the CAR file to ipfs
    out = `ipfs dag import test_output/#{pieceCid}.car`
    expect(out).to include dataCid
    expect(out).to include 'success'

    # Try get the file from ipfs and verify they are the same as the original files
    system("ipfs get #{dataCid} -o test_ipld_out")

    # Compare test_ipld and test_ipld_out folder to make sure they are the same
    expect(`diff -r test_ipld test_ipld_out/test_ipld`).to eq ''
  end
end

describe "GenerateCar" do
  after :each do
    FileUtils.rm_f(Dir['test/*.car'])
    FileUtils.rm_rf('generated_test')
    FileUtils.rm_rf('subfiles_test')
    FileUtils.rm_rf('tmpdir')
  end
  it 'should return expected error for non existing file' do
    stdout = `./generate-car -i test/test-overflow.json  -o test -p test -t tmpdir 2>&1`
    expect(stdout).to include 'EOF'
  end
  it 'should return expected error for non existing file' do
    stdout = `./generate-car -i test/test-nonexisting.json  -o test -p test -t tmpdir 2>&1`
    expect(stdout).to include 'no such file'
  end
  it 'should work for single file input' do
    expectIpld = %{
{
  "Name": "",
  "Hash": "bafybeiceqv4l23zs2766j3i2ros3zvatxmanelmnzk753ue525d6j4azgy",
  "Size": 0,
  "Link": [
    {
      "Name": "test.txt",
      "Hash": "bafkreibpk2zxqxtsnbijltzvz5hnsjwgmr6i5dte5fiuri2fgcpf52gtpq",
      "Size": 4038,
      "Link": null
    }
  ]
}
    }
    expectedCidMap = {""=>{"Cid"=>"bafybeiceqv4l23zs2766j3i2ros3zvatxmanelmnzk753ue525d6j4azgy", "IsDir"=>true}, "test.txt"=>{"Cid"=>"bafkreibpk2zxqxtsnbijltzvz5hnsjwgmr6i5dte5fiuri2fgcpf52gtpq", "IsDir"=>false}}
    stdout = `./generate-car -i test/test.json  -o test -p test -t tmpdir`
    result = JSON.parse(stdout)
    expectDataCid = JSON.parse(expectIpld)['Hash']
    expect(result['DataCid']).to eq(expectDataCid)
    streamCommpResult = `cat test/#{result['PieceCid']}.car | ~/go/bin/stream-commp 2>&1`
    expectCommp = streamCommpResult.lines.find{|line|line.include?'CommPCid'}.strip.split(' ')[1]
    expectPieceSize = streamCommpResult.lines.find{|line|line.include?'Padded piece'}.strip.split(' ')[-2].to_i
    expect(result['PieceCid']).to eq(expectCommp)
    expect(result['PieceSize']).to eq(expectPieceSize)
    expect(result['Ipld']).to eq(JSON.parse(expectIpld))
    expect(result['CidMap']).to eq(expectedCidMap)
  end

  it 'should work for files with parent path' do
    expectIpld = %{
{
  "Name": "",
  "Hash": "bafybeigivse44aebx2ipou7fvvejjighko4yvtcbrhcuoc4wx6xr2gtdwe",
  "Size": 0,
  "Link": [
    {
      "Name": "test",
      "Hash": "bafybeiceqv4l23zs2766j3i2ros3zvatxmanelmnzk753ue525d6j4azgy",
      "Size": 4095,
      "Link": [
        {
          "Name": "test.txt",
          "Hash": "bafkreibpk2zxqxtsnbijltzvz5hnsjwgmr6i5dte5fiuri2fgcpf52gtpq",
          "Size": 4038,
          "Link": null
        }
      ]
    }
  ]
}
    }
    expectedCidMap = {""=>{"IsDir"=>true, "Cid"=>"bafybeigivse44aebx2ipou7fvvejjighko4yvtcbrhcuoc4wx6xr2gtdwe"}, "test"=>{"IsDir"=>true, "Cid"=>"bafybeiceqv4l23zs2766j3i2ros3zvatxmanelmnzk753ue525d6j4azgy"}, "test/test.txt"=>{"IsDir"=>false, "Cid"=>"bafkreibpk2zxqxtsnbijltzvz5hnsjwgmr6i5dte5fiuri2fgcpf52gtpq"}}
    stdout = `./generate-car -i test/test.json -o test -p . -t tmpdir`
    result = JSON.parse(stdout)
    expectDataCid = JSON.parse(expectIpld)['Hash']
    expect(result['DataCid']).to eq(expectDataCid)
    streamCommpResult = `cat test/#{result['PieceCid']}.car | ~/go/bin/stream-commp 2>&1`
    expectCommp = streamCommpResult.lines.find{|line|line.include?'CommPCid'}.strip.split(' ')[1]
    expectPieceSize = streamCommpResult.lines.find{|line|line.include?'Padded piece'}.strip.split(' ')[-2].to_i
    expect(result['PieceCid']).to eq(expectCommp)
    expect(result['PieceSize']).to eq(expectPieceSize)
    expect(result['Ipld']).to eq(JSON.parse(expectIpld))
    expect(result['CidMap']).to eq(expectedCidMap)
  end

  it 'should work with partial file' do
    expectIpld = %{
{
  "Name": "",
  "Hash": "bafybeiejb5tmssizbrxv2p5q5tx34g4d424zylpp6fucp5m7bwiyhqxnxa",
  "Size": 0,
  "Link": [
    {
      "Name": "test.txt",
      "Hash": "bafkreihgspm7pi3bgf44lag72wmqkms27t2et7kbmkvt537p5h4drdgzse",
      "Size": 1000,
      "Link": null
    }
  ]
}
    }
    expectedCidMap = {""=>{"Cid"=>"bafybeiejb5tmssizbrxv2p5q5tx34g4d424zylpp6fucp5m7bwiyhqxnxa", "IsDir"=>true}, "test.txt"=>{"Cid"=>"bafkreihgspm7pi3bgf44lag72wmqkms27t2et7kbmkvt537p5h4drdgzse", "IsDir"=>false}}
    stdout = `./generate-car -i test/test-partial.json  -o test -p test -t tmpdir`
    result = JSON.parse(stdout)
    expectDataCid = JSON.parse(expectIpld)['Hash']
    expect(result['DataCid']).to eq(expectDataCid)
    streamCommpResult = `cat test/#{result['PieceCid']}.car | ~/go/bin/stream-commp 2>&1`
    expectCommp = streamCommpResult.lines.find{|line|line.include?'CommPCid'}.strip.split(' ')[1]
    expectPieceSize = streamCommpResult.lines.find{|line|line.include?'Padded piece'}.strip.split(' ')[-2].to_i
    expect(result['PieceCid']).to eq(expectCommp)
    expect(result['PieceSize']).to eq(expectPieceSize)
    expect(result['Ipld']).to eq(JSON.parse(expectIpld))
    expect(result['CidMap']).to eq(expectedCidMap)
  end

  it 'should work with multiple files' do
    expectIpld = %{
{
  "Name": "",
  "Hash": "bafybeige75p3h2b72aufmsjgtwqppiuf67nvd25vzugpc3xs2ab5gmsfwq",
  "Size": 0,
  "Link": [
    {
      "Name": "test.txt",
      "Hash": "bafkreibpk2zxqxtsnbijltzvz5hnsjwgmr6i5dte5fiuri2fgcpf52gtpq",
      "Size": 4038,
      "Link": null
    },
    {
      "Name": "test2.txt",
      "Hash": "bafkreihrzwmwtzh7ax25ue4txzeuhrr77a3okuqagez243z4dcd2wlz4my",
      "Size": 3089,
      "Link": null
    }
  ]
}
    }
    expectedCidMap = {""=>{"IsDir"=>true, "Cid"=>"bafybeige75p3h2b72aufmsjgtwqppiuf67nvd25vzugpc3xs2ab5gmsfwq"}, "test.txt"=>{"IsDir"=>false, "Cid"=>"bafkreibpk2zxqxtsnbijltzvz5hnsjwgmr6i5dte5fiuri2fgcpf52gtpq"}, "test2.txt"=>{"IsDir"=>false, "Cid"=>"bafkreihrzwmwtzh7ax25ue4txzeuhrr77a3okuqagez243z4dcd2wlz4my"}}
    stdout = `./generate-car -i test/test-multiple.json  -o test -p test -t tmpdir`
    result = JSON.parse(stdout)
    expectDataCid = JSON.parse(expectIpld)['Hash']
    expect(result['DataCid']).to eq(expectDataCid)
    streamCommpResult = `cat test/#{result['PieceCid']}.car | ~/go/bin/stream-commp 2>&1`
    expectCommp = streamCommpResult.lines.find{|line|line.include?'CommPCid'}.strip.split(' ')[1]
    expectPieceSize = streamCommpResult.lines.find{|line|line.include?'Padded piece'}.strip.split(' ')[-2].to_i
    expect(result['PieceCid']).to eq(expectCommp)
    expect(result['PieceSize']).to eq(expectPieceSize)
    expect(result['Ipld']).to eq(JSON.parse(expectIpld))
    expect(result['CidMap']).to eq(expectedCidMap)
  end

  it 'should work with file with wrong but larger size' do
    expectIpld = %{
{
  "Name": "",
  "Hash": "bafybeiceqv4l23zs2766j3i2ros3zvatxmanelmnzk753ue525d6j4azgy",
  "Size": 0,
  "Link": [
    {
      "Name": "test.txt",
      "Hash": "bafkreibpk2zxqxtsnbijltzvz5hnsjwgmr6i5dte5fiuri2fgcpf52gtpq",
      "Size": 4038,
      "Link": null
    }
  ]
}
    }
    stdout = `./generate-car -i test/test-larger.json  -o test -p test`
    result = JSON.parse(stdout)
    expectDataCid = JSON.parse(expectIpld)['Hash']
    expect(result['DataCid']).to eq(expectDataCid)
    streamCommpResult = `cat test/#{result['PieceCid']}.car | ~/go/bin/stream-commp 2>&1`
    expectCommp = streamCommpResult.lines.find{|line|line.include?'CommPCid'}.strip.split(' ')[1]
    expectPieceSize = streamCommpResult.lines.find{|line|line.include?'Padded piece'}.strip.split(' ')[-2].to_i
    expect(result['PieceCid']).to eq(expectCommp)
    expect(result['PieceSize']).to eq(expectPieceSize)
    expect(result['Ipld']).to eq(JSON.parse(expectIpld))
  end

  it 'should work with file with wrong but smaller size' do
    expectIpld = %{
{
  "Name": "",
  "Hash": "bafybeiceqv4l23zs2766j3i2ros3zvatxmanelmnzk753ue525d6j4azgy",
  "Size": 0,
  "Link": [
    {
      "Name": "test.txt",
      "Hash": "bafkreibpk2zxqxtsnbijltzvz5hnsjwgmr6i5dte5fiuri2fgcpf52gtpq",
      "Size": 4038,
      "Link": null
    }
  ]
}

    }
    stdout = `./generate-car -i test/test-smaller.json  -o test -p test`
    result = JSON.parse(stdout)
    expectDataCid = JSON.parse(expectIpld)['Hash']
    expect(result['DataCid']).to eq(expectDataCid)
    streamCommpResult = `cat test/#{result['PieceCid']}.car | ~/go/bin/stream-commp 2>&1`
    expectCommp = streamCommpResult.lines.find{|line|line.include?'CommPCid'}.strip.split(' ')[1]
    expectPieceSize = streamCommpResult.lines.find{|line|line.include?'Padded piece'}.strip.split(' ')[-2].to_i
    expect(result['PieceCid']).to eq(expectCommp)
    expect(result['PieceSize']).to eq(expectPieceSize)
    expect(result['Ipld']).to eq(JSON.parse(expectIpld))
  end
  it 'should work with symbolic link' do
    expectIpld = %{
{
  "Name": "",
  "Hash": "bafybeihis3bw7stnssjhnipnvytgduk4yf4wuaumw7fmklxzouvzvo5kyq",
  "Size": 0,
  "Link": [
    {
      "Name": "test-link.txt",
      "Hash": "bafkreibpk2zxqxtsnbijltzvz5hnsjwgmr6i5dte5fiuri2fgcpf52gtpq",
      "Size": 4038,
      "Link": null
    }
  ]
}
    }
    stdout = `./generate-car -i test/test-link.json  -o test -p test -t tmpdir`
    result = JSON.parse(stdout)
    expectDataCid = JSON.parse(expectIpld)['Hash']
    expect(result['DataCid']).to eq(expectDataCid)
    streamCommpResult = `cat test/#{result['PieceCid']}.car | ~/go/bin/stream-commp 2>&1`
    expectCommp = streamCommpResult.lines.find{|line|line.include?'CommPCid'}.strip.split(' ')[1]
    expectPieceSize = streamCommpResult.lines.find{|line|line.include?'Padded piece'}.strip.split(' ')[-2].to_i
    expect(result['PieceCid']).to eq(expectCommp)
    expect(result['PieceSize']).to eq(expectPieceSize)
    expect(result['Ipld']).to eq(JSON.parse(expectIpld))
  end

  it 'should abort with file not found' do
    system("./generate-car -i test/test-not-found.json  -o test -p test")
    expect($?.exitstatus).to eq(1)
  end

  it 'should abort with file without read permission' do
    FileUtils.chmod 0000, 'test/test-noread.json'
    system("./generate-car -i test/test-noread.json  -o test -p test")
    FileUtils.chmod 0644, 'test/test-noread.json'
    expect($?.exitstatus).to eq(1)
  end

  it 'should work with large number of sub files' do
    base = 'subfiles_test'
    FileUtils.mkdir_p(File.join(base, 'subfolders'))
    json = (10000..20000).map do |i|
        path = File.join(base, "subfolders/#{i}.txt")
        File.write(path, "Hello World #{i}")
        {
            "Path" => path,
            "Size" => File.size(path)
        }
    end
    File.write('subfiles_test/test.json', JSON.generate(json))
    stdout = `./generate-car -i subfiles_test/test.json  -o test -p subfiles_test`
    result = JSON.parse(stdout)
    expect(JSON.generate(result)).to eq(JSON.generate(JSON.parse(File.read('test/test-dynamic-folder.json'))))
  end

  it 'should handle complicated file structure' do
    base = 'generated_test'
    FileUtils.mkdir_p(base)
    json = []
    ["/1/1/1.txt",
     "/1/1/2.txt",
     "/1/2.txt",
     "/1/3.txt",
     "/2/1/1.txt",
     "/2/1/2.txt",
     "/2/1/3/1/1.txt",
     "/3.txt"].each do |path|
       p = File.join(base, path)
       FileUtils.mkdir_p(File.dirname(p))
       FileUtils.cp('test/test.txt', p)
       json.push(
          {
            "Path" => p,
            "Size" => 4038,
            "Start" => 0,
            "End" => 4038
          })
     end
    File.write('generated_test/test.json', JSON.generate(json))
    expectIpld = %{
{
  "Name": "",
  "Hash": "bafybeib3roh4zlejbijx3ub2pkvko6szvo3yncqpxh53jlcwabsscvntgy",
  "Size": 0,
  "Link": [
    {
      "Name": "1",
      "Hash": "bafybeihul4g4is36a2lvqwd4osksjzcyqr6q3kj6kmlycwgsvrqwvkpuzq",
      "Size": 16406,
      "Link": [
        {
          "Name": "1",
          "Hash": "bafybeidyv33hivd5ll27m6y7caaskhurr6twoobkl57xrugwpwmr47rcea",
          "Size": 8180,
          "Link": [
            {
              "Name": "1.txt",
              "Hash": "bafkreibpk2zxqxtsnbijltzvz5hnsjwgmr6i5dte5fiuri2fgcpf52gtpq",
              "Size": 4038,
              "Link": null
            },
            {
              "Name": "2.txt",
              "Hash": "bafkreibpk2zxqxtsnbijltzvz5hnsjwgmr6i5dte5fiuri2fgcpf52gtpq",
              "Size": 4038,
              "Link": null
            }
          ]
        },
        {
          "Name": "2.txt",
          "Hash": "bafkreibpk2zxqxtsnbijltzvz5hnsjwgmr6i5dte5fiuri2fgcpf52gtpq",
          "Size": 4038,
          "Link": null
        },
        {
          "Name": "3.txt",
          "Hash": "bafkreibpk2zxqxtsnbijltzvz5hnsjwgmr6i5dte5fiuri2fgcpf52gtpq",
          "Size": 4038,
          "Link": null
        }
      ]
    },
    {
      "Name": "2",
      "Hash": "bafybeigjw26ddnnmqunl4ezbypr7gr55wo7uznlcfh6yp6dt3jmcvnagbi",
      "Size": 12418,
      "Link": [
        {
          "Name": "1",
          "Hash": "bafybeibue5osgywpuwy5waov7cjrdlxrxps3m2znjznm7l73x362attysq",
          "Size": 12368,
          "Link": [
            {
              "Name": "1.txt",
              "Hash": "bafkreibpk2zxqxtsnbijltzvz5hnsjwgmr6i5dte5fiuri2fgcpf52gtpq",
              "Size": 4038,
              "Link": null
            },
            {
              "Name": "2.txt",
              "Hash": "bafkreibpk2zxqxtsnbijltzvz5hnsjwgmr6i5dte5fiuri2fgcpf52gtpq",
              "Size": 4038,
              "Link": null
            },
            {
              "Name": "3",
              "Hash": "bafybeiavjj7lncrdsu2d5rndsvsqfl6lg4p7hzyisb32il4qoybdtmirwi",
              "Size": 4142,
              "Link": [
                {
                  "Name": "1",
                  "Hash": "bafybeib6gazg7coviekkoakcefjl7wachgqztr3utmw7uohg635ixthhmm",
                  "Size": 4092,
                  "Link": [
                    {
                      "Name": "1.txt",
                      "Hash": "bafkreibpk2zxqxtsnbijltzvz5hnsjwgmr6i5dte5fiuri2fgcpf52gtpq",
                      "Size": 4038,
                      "Link": null
                    }
                  ]
                }
              ]
            }
          ]
        }
      ]
    },
    {
      "Name": "3.txt",
      "Hash": "bafkreibpk2zxqxtsnbijltzvz5hnsjwgmr6i5dte5fiuri2fgcpf52gtpq",
      "Size": 4038,
      "Link": null
    }
  ]
}
        }
    expectedCidMap = {""=>{"IsDir"=>true, "Cid"=>"bafybeib3roh4zlejbijx3ub2pkvko6szvo3yncqpxh53jlcwabsscvntgy"}, "1"=>{"IsDir"=>true, "Cid"=>"bafybeihul4g4is36a2lvqwd4osksjzcyqr6q3kj6kmlycwgsvrqwvkpuzq"}, "1/1"=>{"IsDir"=>true, "Cid"=>"bafybeidyv33hivd5ll27m6y7caaskhurr6twoobkl57xrugwpwmr47rcea"}, "1/1/1.txt"=>{"IsDir"=>false, "Cid"=>"bafkreibpk2zxqxtsnbijltzvz5hnsjwgmr6i5dte5fiuri2fgcpf52gtpq"}, "1/1/2.txt"=>{"IsDir"=>false, "Cid"=>"bafkreibpk2zxqxtsnbijltzvz5hnsjwgmr6i5dte5fiuri2fgcpf52gtpq"}, "1/2.txt"=>{"IsDir"=>false, "Cid"=>"bafkreibpk2zxqxtsnbijltzvz5hnsjwgmr6i5dte5fiuri2fgcpf52gtpq"}, "1/3.txt"=>{"IsDir"=>false, "Cid"=>"bafkreibpk2zxqxtsnbijltzvz5hnsjwgmr6i5dte5fiuri2fgcpf52gtpq"}, "2"=>{"IsDir"=>true, "Cid"=>"bafybeigjw26ddnnmqunl4ezbypr7gr55wo7uznlcfh6yp6dt3jmcvnagbi"}, "2/1"=>{"IsDir"=>true, "Cid"=>"bafybeibue5osgywpuwy5waov7cjrdlxrxps3m2znjznm7l73x362attysq"}, "2/1/1.txt"=>{"IsDir"=>false, "Cid"=>"bafkreibpk2zxqxtsnbijltzvz5hnsjwgmr6i5dte5fiuri2fgcpf52gtpq"}, "2/1/2.txt"=>{"IsDir"=>false, "Cid"=>"bafkreibpk2zxqxtsnbijltzvz5hnsjwgmr6i5dte5fiuri2fgcpf52gtpq"}, "2/1/3"=>{"IsDir"=>true, "Cid"=>"bafybeiavjj7lncrdsu2d5rndsvsqfl6lg4p7hzyisb32il4qoybdtmirwi"}, "2/1/3/1"=>{"IsDir"=>true, "Cid"=>"bafybeib6gazg7coviekkoakcefjl7wachgqztr3utmw7uohg635ixthhmm"}, "2/1/3/1/1.txt"=>{"IsDir"=>false, "Cid"=>"bafkreibpk2zxqxtsnbijltzvz5hnsjwgmr6i5dte5fiuri2fgcpf52gtpq"}, "3.txt"=>{"IsDir"=>false, "Cid"=>"bafkreibpk2zxqxtsnbijltzvz5hnsjwgmr6i5dte5fiuri2fgcpf52gtpq"}}
    stdout = `./generate-car -i generated_test/test.json  -o test -p generated_test -t tmpdir`
    result = JSON.parse(stdout)
    expectDataCid = JSON.parse(expectIpld)['Hash']
    expect(result['DataCid']).to eq(expectDataCid)
    streamCommpResult = `cat test/#{result['PieceCid']}.car | ~/go/bin/stream-commp 2>&1`
    expectCommp = streamCommpResult.lines.find{|line|line.include?'CommPCid'}.strip.split(' ')[1]
    expectPieceSize = streamCommpResult.lines.find{|line|line.include?'Padded piece'}.strip.split(' ')[-2].to_i
    expect(result['PieceCid']).to eq(expectCommp)
    expect(result['PieceSize']).to eq(expectPieceSize)
    expect(result['Ipld']).to eq(JSON.parse(expectIpld))
    expect(result['CidMap']).to eq(expectedCidMap)
  end
end
