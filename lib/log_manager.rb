# To change this template, choose Tools | Templates
# and open the template in the editor.
require 'tempfile'
require 'stringio'

module Mv
#	FORMAT
#		byte:type: content
#		0-1:unsigned short: size of log (= n)
#		2-5:unsigned int:	timestamp in sec since 1970
#		6:unsigned char:	flag, LSB of which shows whether the data is dumped
#		7-(n-1):String: data (dumped if not String)
	class LogManager
		ID_TIME = 0x01
		ID_DATA = 0x02
		ID_POS = 0x04

#		ARGS
#			Numeric kept_span: span[sec] of time during which logs are retained
		def initialize filename, kept_span = nil
			@log_filename = filename.tosjis
			remove_old_logs kept_span if kept_span
		end

		def log data
			s_timestamp = [Time.now.to_i].pack('I')	# s_ means String
			s_data = case data
			when String then 0.chr + data
			else 1.chr + Marshal.dump(data)
			end
			s_size = [2 + s_timestamp.size + s_data.size].pack('S')
			begin
				File.open(@log_filename, 'ab'){|fo|
					fo.write s_size + s_timestamp + s_data
				}
			rescue
				on_logging_failed
			end
		end

		def remove_old_logs kept_span
			if File.file? @log_filename
				time_now = Time.now				
				begin
					# seek for oldest valid log
					pos = time_to_pos(time_now - kept_span, true)
				rescue => evar
					message = "\"#{@log_filename}\" seems corrupt. Try deleting it\n."
					Wx::message_box message + evar.inspect, "Error"
					return
				end
				if pos	# if any valid log was found
					unless pos == 0	# unless all logs are valid
						# use Tempfile if logfile to copy is large
						lmt_chunk = 1024**2
						tmp_storage = if File.size(@log_filename) - pos > lmt_chunk
							Tempfile.new('temp').binmode
						else
							StringIO.new('', 'w+b')
						end
						File.open(@log_filename, 'rb'){|fi|
							fi.pos = pos
							tmp_storage << fi.read(lmt_chunk) until fi.eof?
						}
						tmp_storage.rewind
						File.open(@log_filename, 'wb'){|fo|
							fo << tmp_storage.read(lmt_chunk) until tmp_storage.eof?
						}
						tmp_storage.close
						tmp_storage.close(true) if tmp_storage.kind_of?(Tempfile)
					end
				else
					File.delete(@log_filename)
				end
			end
		end

#		USAGE
#			a. each{|timestamp,data| ... }
#			b. each(ID_TIME){|timestamp,dummy| ... }	# with nil stored in dummy (a bit faster)
		def each begin_time = nil, end_time = nil, ret_type = ID_TIME|ID_DATA
			File.open(@log_filename, 'rb'){|fi|
				fi.pos = time_to_pos(begin_time, true) || 0
				end_pos = time_to_pos(end_time, true) || fi.stat.size-1
				while (pos = fi.pos) < end_pos
					log = read_a_log(fi, ret_type)
					yield((ret_type & ID_POS) ? log + [pos] : log) if log
				end
			}
		end

#		USAGE
#			a. each_with_pos{|timestamp,data,pos| ... }
#			b. each_with_pos(ID_TIME){|timestamp,dummy,pos| ... }
		def each_with_pos begin_time = nil, end_time = nil, ret_type = ID_TIME|ID_DATA, &proc
			each(begin_time, end_time, ret_type|ID_POS, &proc)
		end

		private
		
#		DESCRIPTION
#			return a log, which consists of a set of timestamp and data
#		ARGS
#			File ifstream: log file. ifstream.pos must be set beforehand at the exact pos where a log starts
#			Integer ret_type: specify the value(s) you want using ID_TIME and ID_DATA
		def read_a_log ifstream, ret_type
			timestamp = nil
			data = nil
			unless ifstream.eof?
				s_size = ifstream.read(2)
				size = s_size.unpack('S')[0]
				size_time = 4
				if ret_type & ID_TIME
					s_timestamp = ifstream.read(4)
					timestamp = Time.at(s_timestamp.unpack('I')[0])
				else
					ifstream.pos += size_time
				end
				size_data = size - 6
				if ret_type & ID_DATA
					s_data = ifstream.read(size_data)
					is_dumped = (s_data[0] & 0x01) == 0 ? false : true
					data = is_dumped ? Marshal.load(s_data[1..-1]) : s_data[1..-1]
				else
					ifstream.pos += size_data
				end
			end
			[timestamp, data]
		rescue
			warn "reading log failed"
		end
		
#		DESCRIPTION
#			seek for a log from time and return its filepos
#		ARGS
#			Time time: approximate time at which the log was made
#			Bool exceed: if false, return pos of the last log prior to the specified time
#		RETS
#			filepos of log found
#			- nil if no log was found or no time was specified
		def time_to_pos time, exceed = false
			pos_found = nil
			if time
				prev_pos = 0
				each_with_pos(nil, nil, ID_TIME){|timestamp,data,pos|
					if timestamp > time
						pos_found = (exceed ? pos : prev_pos)
						break
					end
					prev_pos = pos
				}
			end
			pos_found
		end

		def on_logging_failed
			warn "logging failed"
		end
		
	end
end