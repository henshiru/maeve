base_dir = File.dirname(__FILE__)
$: << "#{base_dir}" << "#{base_dir}/../lib"
require 'com_stream'

depk = Mv::ComStreamDepacketizer.new

File.open(ARGV[0], "rb"){|fi|
  File.open(ARGV[1], "wb"){|fo|
    until fi.eof? do
      datpack = fi.read 32
      datraw = depk.depacketize(datpack)
      fo.write datraw
    end
  }
}