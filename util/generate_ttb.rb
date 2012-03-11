#Maeve形式datファイルからttbを作成する

base_dir = File.dirname(__FILE__)
$: << "#{base_dir}" << "#{base_dir}/../lib"
require 'kconv'
require 'sylphide_communicator'
require 'mv_ext_util'
include MvExtUtil


# usage instruction
if ARGV.size < 1 then puts <<"EOS"
DESCTIPTION
	Maeve形式datファイルからttbを作成する
ARGS
	src-file(*.dat)
EOS
	exit -1
end

BLOCK_SIZE = 1024
ifname = ARGV[0]
ofname = File.basename(ifname, '.dat') + '.ttb'
dat_file = File.open(ifname, 'rb')
dat_file_size = dat_file.stat.size
time_table_output = File.open(ofname, 'w')
communicator = Mv::SylphideCommunicator.new

time_table_output << ifname << "\n"
until dat_file.eof? do
	if data = dat_file.read(BLOCK_SIZE)
		data_all = data
		(data_all.length/BLOCK_SIZE + ((data_all.length%BLOCK_SIZE != 0)?1:0)).times{|i|
			data = data_all[i*BLOCK_SIZE...[(i+1)*BLOCK_SIZE,data_all.length].min]
			communicator.update data
			time_table_output << communicator[:itow] << "," << data.length << "\n"
		}
		MvExtUtil.print_progress(dat_file.pos, dat_file_size)
	end
end

dat_file.close
time_table_output.close
