require 'json'
require 'fileutils'
describe "GenerateCar" do
  after :each do
    FileUtils.rm_f(Dir['test/*.car'])
    FileUtils.rm_rf('generated_test')
  end
  it 'should work for single file input' do
    expectIpld = %{
{
  "Name": "",
  "Hash": "bafybeiht76sut7jiu7t5s7tqpjqqbqxbdktquqvm6ae6i3ycpd3astdhu4",
  "Size": 0,
  "Link": [
    {
      "Name": "test.txt",
      "Hash": "bafybeiake3szbkzabnf6nqtoocwva4k3mmb6sp77ue5tehgne7jjj3nf24",
      "Size": 4049,
      "Link": null
    }
  ]
}
    }
    stdout = `./generate-car -i test/test.json  -o test -p test`
    result = JSON.parse(stdout)
    expectDataCid = JSON.parse(expectIpld)['Hash']
    expect(result['DataCid']).to eq(expectDataCid)
    streamCommpResult = `cat test/#{expectDataCid}.car | ~/go/bin/stream-commp 2>&1`
    expectCommp = streamCommpResult.lines.find{|line|line.include?'CommPCid'}.strip.split(' ')[1]
    expectPieceSize = streamCommpResult.lines.find{|line|line.include?'Padded piece'}.strip.split(' ')[-2].to_i
    expect(result['PieceCid']).to eq(expectCommp)
    expect(result['PieceSize']).to eq(expectPieceSize)
    puts JSON.pretty_generate(result['Ipld'])
    expect(result['Ipld']).to eq(JSON.parse(expectIpld))
  end

  it 'should work for files with parent path' do
    expectIpld = %{
{
  "Name": "",
  "Hash": "bafybeiejli24sgljjac23jddo7lr75365djwc3bw3pxuseshye3rwpl7ru",
  "Size": 0,
  "Link": [
    {
      "Name": "test",
      "Hash": "bafybeiht76sut7jiu7t5s7tqpjqqbqxbdktquqvm6ae6i3ycpd3astdhu4",
      "Size": 4106,
      "Link": [
        {
          "Name": "test.txt",
          "Hash": "bafybeiake3szbkzabnf6nqtoocwva4k3mmb6sp77ue5tehgne7jjj3nf24",
          "Size": 4049,
          "Link": null
        }
      ]
    }
  ]
}
    }
    stdout = `./generate-car -i test/test.json -o test -p .`
    result = JSON.parse(stdout)
    expectDataCid = JSON.parse(expectIpld)['Hash']
    expect(result['DataCid']).to eq(expectDataCid)
    streamCommpResult = `cat test/#{expectDataCid}.car | ~/go/bin/stream-commp 2>&1`
    expectCommp = streamCommpResult.lines.find{|line|line.include?'CommPCid'}.strip.split(' ')[1]
    expectPieceSize = streamCommpResult.lines.find{|line|line.include?'Padded piece'}.strip.split(' ')[-2].to_i
    expect(result['PieceCid']).to eq(expectCommp)
    expect(result['PieceSize']).to eq(expectPieceSize)
    puts JSON.pretty_generate(result['Ipld'])
    expect(result['Ipld']).to eq(JSON.parse(expectIpld))
  end

  it 'should work with partial file' do
    expectIpld = %{
{
  "Name": "",
  "Hash": "bafybeihydll5cng2hfdqblglqohn4dom4raw6nvqplhmml4ufmclydomme",
  "Size": 0,
  "Link": [
    {
      "Name": "test.txt",
      "Hash": "bafybeiaqhlr6oxtkemzq4hiqneyeyus4pb4baboejpue4pcr5t3zt6uvd4",
      "Size": 1011,
      "Link": null
    }
  ]
}
    }
    stdout = `./generate-car -i test/test-partial.json  -o test -p test`
    result = JSON.parse(stdout)
    expectDataCid = JSON.parse(expectIpld)['Hash']
    expect(result['DataCid']).to eq(expectDataCid)
    streamCommpResult = `cat test/#{expectDataCid}.car | ~/go/bin/stream-commp 2>&1`
    expectCommp = streamCommpResult.lines.find{|line|line.include?'CommPCid'}.strip.split(' ')[1]
    expectPieceSize = streamCommpResult.lines.find{|line|line.include?'Padded piece'}.strip.split(' ')[-2].to_i
    expect(result['PieceCid']).to eq(expectCommp)
    expect(result['PieceSize']).to eq(expectPieceSize)
    puts JSON.pretty_generate(result['Ipld'])
    expect(result['Ipld']).to eq(JSON.parse(expectIpld))
  end

  it 'should work with multiple files' do
    expectIpld = %{
{
  "Name": "",
  "Hash": "bafybeif47u62o6b6gsgidfd3rrf3ep5i27oux2db3k6cble3c522fgz73q",
  "Size": 0,
  "Link": [
    {
      "Name": "test.txt",
      "Hash": "bafybeiake3szbkzabnf6nqtoocwva4k3mmb6sp77ue5tehgne7jjj3nf24",
      "Size": 4049,
      "Link": null
    },
    {
      "Name": "test2.txt",
      "Hash": "bafybeicopdexbrwmpsh7f24htvfbouleocw5fwyaprhubppvtln33hvnl4",
      "Size": 3100,
      "Link": null
    }
  ]
}
    }
    stdout = `./generate-car -i test/test-multiple.json  -o test -p test`
    result = JSON.parse(stdout)
    expectDataCid = JSON.parse(expectIpld)['Hash']
    expect(result['DataCid']).to eq(expectDataCid)
    streamCommpResult = `cat test/#{expectDataCid}.car | ~/go/bin/stream-commp 2>&1`
    expectCommp = streamCommpResult.lines.find{|line|line.include?'CommPCid'}.strip.split(' ')[1]
    expectPieceSize = streamCommpResult.lines.find{|line|line.include?'Padded piece'}.strip.split(' ')[-2].to_i
    expect(result['PieceCid']).to eq(expectCommp)
    expect(result['PieceSize']).to eq(expectPieceSize)
    puts JSON.pretty_generate(result['Ipld'])
    expect(result['Ipld']).to eq(JSON.parse(expectIpld))
  end

  it 'should work with file with wrong but larger size' do
    expectIpld = %{
{
  "Name": "",
  "Hash": "bafybeiht76sut7jiu7t5s7tqpjqqbqxbdktquqvm6ae6i3ycpd3astdhu4",
  "Size": 0,
  "Link": [
    {
      "Name": "test.txt",
      "Hash": "bafybeiake3szbkzabnf6nqtoocwva4k3mmb6sp77ue5tehgne7jjj3nf24",
      "Size": 4049,
      "Link": null
    }
  ]
}
    }
    stdout = `./generate-car -i test/test-larger.json  -o test -p test`
    result = JSON.parse(stdout)
    expectDataCid = JSON.parse(expectIpld)['Hash']
    expect(result['DataCid']).to eq(expectDataCid)
    streamCommpResult = `cat test/#{expectDataCid}.car | ~/go/bin/stream-commp 2>&1`
    expectCommp = streamCommpResult.lines.find{|line|line.include?'CommPCid'}.strip.split(' ')[1]
    expectPieceSize = streamCommpResult.lines.find{|line|line.include?'Padded piece'}.strip.split(' ')[-2].to_i
    expect(result['PieceCid']).to eq(expectCommp)
    expect(result['PieceSize']).to eq(expectPieceSize)
    puts JSON.pretty_generate(result['Ipld'])
    expect(result['Ipld']).to eq(JSON.parse(expectIpld))
  end

  it 'should work with file with wrong but smaller size' do
    expectIpld = %{
{
  "Name": "",
  "Hash": "bafybeiht76sut7jiu7t5s7tqpjqqbqxbdktquqvm6ae6i3ycpd3astdhu4",
  "Size": 0,
  "Link": [
    {
      "Name": "test.txt",
      "Hash": "bafybeiake3szbkzabnf6nqtoocwva4k3mmb6sp77ue5tehgne7jjj3nf24",
      "Size": 4049,
      "Link": null
    }
  ]
}
    }
    stdout = `./generate-car -i test/test-smaller.json  -o test -p test`
    result = JSON.parse(stdout)
    expectDataCid = JSON.parse(expectIpld)['Hash']
    expect(result['DataCid']).to eq(expectDataCid)
    streamCommpResult = `cat test/#{expectDataCid}.car | ~/go/bin/stream-commp 2>&1`
    expectCommp = streamCommpResult.lines.find{|line|line.include?'CommPCid'}.strip.split(' ')[1]
    expectPieceSize = streamCommpResult.lines.find{|line|line.include?'Padded piece'}.strip.split(' ')[-2].to_i
    expect(result['PieceCid']).to eq(expectCommp)
    expect(result['PieceSize']).to eq(expectPieceSize)
    puts JSON.pretty_generate(result['Ipld'])
    expect(result['Ipld']).to eq(JSON.parse(expectIpld))
  end
  it 'should work with symbolic link' do
    expectIpld = %{
{
  "Name": "",
  "Hash": "bafybeid2uvf4xvcyejy4xkijbridue6fpj6cfj2pjwvup2kaqo6i6pqyra",
  "Size": 0,
  "Link": [
    {
      "Name": "test-link.txt",
      "Hash": "bafybeiake3szbkzabnf6nqtoocwva4k3mmb6sp77ue5tehgne7jjj3nf24",
      "Size": 4049,
      "Link": null
    }
  ]
}
    }
    stdout = `./generate-car -i test/test-link.json  -o test -p test`
    result = JSON.parse(stdout)
    expectDataCid = JSON.parse(expectIpld)['Hash']
    expect(result['DataCid']).to eq(expectDataCid)
    streamCommpResult = `cat test/#{expectDataCid}.car | ~/go/bin/stream-commp 2>&1`
    expectCommp = streamCommpResult.lines.find{|line|line.include?'CommPCid'}.strip.split(' ')[1]
    expectPieceSize = streamCommpResult.lines.find{|line|line.include?'Padded piece'}.strip.split(' ')[-2].to_i
    expect(result['PieceCid']).to eq(expectCommp)
    expect(result['PieceSize']).to eq(expectPieceSize)
    puts JSON.pretty_generate(result['Ipld'])
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
  "Hash": "bafybeidkg76hokygs43l3efymzmnehtvnlcf4soushvgcsv6nrctnwqnxq",
  "Size": 0,
  "Link": [
    {
      "Name": "1",
      "Hash": "bafybeicnjmrmgeigfsdnipna4pfrz5nzezhj6pea2zrdvifs4t5z2hvww4",
      "Size": 16450,
      "Link": [
        {
          "Name": "1",
          "Hash": "bafybeiddxbwlxz4dkwhepbmvm27mwmyxmjidvktc34szkxduncf3ptcrji",
          "Size": 8202,
          "Link": [
            {
              "Name": "1.txt",
              "Hash": "bafybeiake3szbkzabnf6nqtoocwva4k3mmb6sp77ue5tehgne7jjj3nf24",
              "Size": 4049,
              "Link": null
            },
            {
              "Name": "2.txt",
              "Hash": "bafybeiake3szbkzabnf6nqtoocwva4k3mmb6sp77ue5tehgne7jjj3nf24",
              "Size": 4049,
              "Link": null
            }
          ]
        },
        {
          "Name": "2.txt",
          "Hash": "bafybeiake3szbkzabnf6nqtoocwva4k3mmb6sp77ue5tehgne7jjj3nf24",
          "Size": 4049,
          "Link": null
        },
        {
          "Name": "3.txt",
          "Hash": "bafybeiake3szbkzabnf6nqtoocwva4k3mmb6sp77ue5tehgne7jjj3nf24",
          "Size": 4049,
          "Link": null
        }
      ]
    },
    {
      "Name": "2",
      "Hash": "bafybeictyxbycd2aaspyrt6qycarigp5tmbvdx3e2vjwsbqcptufgs6jky",
      "Size": 12451,
      "Link": [
        {
          "Name": "1",
          "Hash": "bafybeicgwqagn6w26db3qkeoriqqhhlrsuxcps765l473hm5h56f27563q",
          "Size": 12401,
          "Link": [
            {
              "Name": "1.txt",
              "Hash": "bafybeiake3szbkzabnf6nqtoocwva4k3mmb6sp77ue5tehgne7jjj3nf24",
              "Size": 4049,
              "Link": null
            },
            {
              "Name": "2.txt",
              "Hash": "bafybeiake3szbkzabnf6nqtoocwva4k3mmb6sp77ue5tehgne7jjj3nf24",
              "Size": 4049,
              "Link": null
            },
            {
              "Name": "3",
              "Hash": "bafybeig7civtxfyq4padiisy6ednq5ni4uh4cfkakanpyxtm6ksshfyp64",
              "Size": 4153,
              "Link": [
                {
                  "Name": "1",
                  "Hash": "bafybeidzjsumvtfrvtt3q5wzse5i5av45ouhwpmivlv4bbpymz3tsxaehi",
                  "Size": 4103,
                  "Link": [
                    {
                      "Name": "1.txt",
                      "Hash": "bafybeiake3szbkzabnf6nqtoocwva4k3mmb6sp77ue5tehgne7jjj3nf24",
                      "Size": 4049,
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
      "Hash": "bafybeiake3szbkzabnf6nqtoocwva4k3mmb6sp77ue5tehgne7jjj3nf24",
      "Size": 4049,
      "Link": null
    }
  ]
}
        }
    stdout = `./generate-car -i generated_test/test.json  -o test -p generated_test`
    result = JSON.parse(stdout)
    expectDataCid = JSON.parse(expectIpld)['Hash']
    expect(result['DataCid']).to eq(expectDataCid)
    streamCommpResult = `cat test/#{expectDataCid}.car | ~/go/bin/stream-commp 2>&1`
    expectCommp = streamCommpResult.lines.find{|line|line.include?'CommPCid'}.strip.split(' ')[1]
    expectPieceSize = streamCommpResult.lines.find{|line|line.include?'Padded piece'}.strip.split(' ')[-2].to_i
    expect(result['PieceCid']).to eq(expectCommp)
    expect(result['PieceSize']).to eq(expectPieceSize)
    puts JSON.pretty_generate(result['Ipld'])
    expect(result['Ipld']).to eq(JSON.parse(expectIpld))
  end
end
