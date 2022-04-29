require 'json'
require 'fileutils'
describe "GenerateCar" do
  after :each do
    FileUtils.rm_f(Dir['test/*.car'])
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
end
