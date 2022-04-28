require 'json'
describe "GenerateCar" do
  after :each do
    system("rm test/*.car")
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
  "Hash": "bafybeiaozxv27zogqg37o7fjksap2sdpujyb5l52zwkvqbyqgpuemzsfti",
  "Size": 0,
  "Link": [
    {
      "Name": "test.txt",
      "Hash": "bafybeie74dms5nt6v3ggf5trbdmn7g7zkzrrn6rt6zndp5domxc3mf5oyi",
      "Size": 4047,
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
end
