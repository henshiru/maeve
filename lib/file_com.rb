# To change this template, choose Tools | Templates
# and open the template in the editor.

module Mv
  class FileCom
    DT_MAX = 100.0
    DT_THRESHOLD = 0.1
    DEFAULT_BLOCK_SIZE = 1024
    LIMIT_BLOCK_SIZE = 3072
    def initialize filename
      filename = filename.tosjis#FIXME windows specific
			@dialog = THE_APP.xrc.load_dialog(THE_APP.frame,'log_file_play_dialog')
      @play_time_slider = Wx::Window.find_window_by_id(Wx::xrcid('play_time_slider'), @dialog)
      @play_time_text = Wx::Window.find_window_by_id(Wx::xrcid('play_time_text'), @dialog)
      @end_time_text = Wx::Window.find_window_by_id(Wx::xrcid('end_time_text'), @dialog)
			@play_time_slider.value = 0
			@start_stop_button = Wx::Window.find_window_by_id(Wx::xrcid('start_stop_button'), @dialog)
			@rewind_button = Wx::Window.find_window_by_id(Wx::xrcid('rewind_button'), @dialog)
			@replay_button = Wx::Window.find_window_by_id(Wx::xrcid('replay_button'), @dialog)
      if File.extname(filename) == ".ttb" then
        f_timetable = File.new(filename,"r")
        #extract dat filename
        dat_filename = f_timetable.gets.split("\n")[0]
        dat_filename = File.join(File.dirname(filename),dat_filename)
        filename = dat_filename
        #read time table
        @timetable = []
        t_data_offset = nil
        while line = f_timetable.gets do
          t_data_prev = (@timetable.last || [0])[0]
          row = line.split(',')
          t_data = row[0].to_f
          t_data -= (t_data_offset||=t_data)
          dt = t_data - t_data_prev
          if dt.abs > DT_MAX then
            t_data_offset += t_data - t_data_prev
            t_data = t_data_prev
            dt = 0
          end
          size = row[1].to_i
          if dt > DT_THRESHOLD || @timetable.empty? then
            @timetable.push [t_data, size]
          else
            @timetable.last[1] += size
          end
        end
				ttl_bytes = 0
				@timetable[0][2] = 0
        1.upto @timetable.length-1 do |i|
        	ttl_bytes += @timetable[i-1][1]
        	@timetable[i][2] = ttl_bytes
        end
        raise "timetable is empty." if @timetable.empty?
				lpath = 60
				path_string = dat_filename.length > (lpath+3) ? "..." + dat_filename[-lpath..-1] : dat_filename
        @dialog.title = path_string
        @play_time_slider.set_range(0, @timetable.last[0].to_i)
        @end_time_text.label = "/" + @timetable.last[0].to_i.to_s + "s"
        @dialog.evt_slider(@play_time_slider){
          self.t_data=@play_time_slider.value
          @play_time_text.value = @play_time_slider.value.to_s
          set_playconfig
        }
				@playspeedRadioBox = Wx::Window.find_window_by_id(Wx::xrcid('playspeedRadioBox'), @dialog)
        @dialog.evt_button(@start_stop_button.get_id){
					if @playspeed != 0
						set_playconfig 0
          else
          	t_textbox = @play_time_text.value.to_i
						self.t_data=t_textbox
						@play_time_slider.value = t_textbox
						set_playconfig @playspeedRadioBox.string_selection[1..-1].to_i
          end
        }
      	@dialog.evt_button(@rewind_button.get_id){
					t_data_new = @t_data > 10 ? @t_data - 10 : 0
      		self.t_data= t_data_new
					set_playconfig
      	}
				@dialog.evt_button(@replay_button.get_id){
      		self.t_data= 0
					set_playconfig
				}
        @dialog.evt_radiobox(@playspeedRadioBox.get_id){
					set_playconfig @playspeedRadioBox.string_selection[1..-1].to_i unless @playspeed == 0
        }       
				#write timetable to file for debugging
        if $DEBUG
					tmp_filename = filename.split('.')[0] + '.txt'
					File.open(tmp_filename, "w"){|f_tmp|
						@timetable.each do |line|
							f_tmp.write(line[0])
							f_tmp.write(",")
							f_tmp.write(line[1])
							f_tmp.write(",")
							f_tmp.write(line[2])
							f_tmp.write("\n")
						end
					}
        end
      else
				@file = File.new(filename,"rb")
				f_size_kb = @file.stat.size / 1024
				@play_time_slider.set_range(0, f_size_kb)
        @end_time_text.label = "/" + f_size_kb.to_s + "KB"
				@dialog.title = filename
				@dialog.evt_button(@start_stop_button.get_id){
					if @playspeed != 0
						@playspeed = 0
					else
						@file.pos = @play_time_text.value.to_i * 1024
						@playspeed = 1
					end
        }
				@dialog.evt_slider(@play_time_slider){
          @file.pos = @play_time_slider.value * 1024
					@play_time_text.value = @play_time_slider.value.to_s
        }
      end
      @file ||= File.new(filename,"rb")
      @t_data = 0
			@playspeed = 1
			@dialog.show(true)
    end
    attr_reader :t_data
    def t_data= t
      raise "this operation is not valid." unless @timetable
      @t_data = t
      n = timetable_index @t_data
#      bytes = 0
#      n.times{|i|
#        bytes += @timetable[i][1]
#      }
#      @file.pos = bytes
      @file.pos = @timetable[n][2]
    end
    def receive
      dat = nil
      unless @file.eof? || @playspeed == 0 then
        if @timetable then
          t_now = Time.now.to_f
          @t_offset ||= t_now
          block_size = 0
          t_elapsed = (t_now - @t_offset) * @playspeed
          i_timetable = timetable_index(@t_data)
          t_data_new = @t_data
          update = false
          i_timetable_new = i_timetable_prev = i_timetable
          while t_elapsed > t_data_new && i_timetable != @timetable.length
            row = @timetable[i_timetable]
            t_data_new = row[0]
#            size = row[1]
#            block_size += size
            i_timetable_new = i_timetable
            i_timetable += 1
          end
          t_data_prev = @t_data
					@t_data = t_data_new
          dt = t_data_new - t_data_prev
#          if dt > 10
#          	@t_offset += dt 
#          	p dt
#          end         
          block_size = @timetable[i_timetable_new][2] - @timetable[i_timetable_prev][2]
          block_size = [block_size, LIMIT_BLOCK_SIZE].min unless @playspeed == 1
              # limit block_size when playing at high-speed
          @file.pos = @timetable[i_timetable_new][2] - block_size
          @play_time_slider.value = @t_data.to_i
          @play_time_text.label = @t_data.to_i.to_s
        else
          block_size = DEFAULT_BLOCK_SIZE
					@play_time_slider.value = @file.pos / 1024
          @play_time_text.label = (@file.pos / 1024).to_s
        end
        dat = (block_size > 0)?(@file.read(block_size)):nil
        if @file.eof? then
          $stderr << (@file.path + ":reached end of file")
        end
      end
      dat
    end
    def send data
      THE_APP.debug_message "File com cannot send data."
    end
    def close
    	@dialog.hide
    end
    private
    def timetable_index t_in
      t_data = 0
      i_timetable = 0
      i_begin = 0
      i_end = @timetable.length
      while i_end - i_begin > 1 do
        i_mid = (i_begin + i_end)/2
        row = @timetable[i_mid]
        t = row[0]
        if t > t_in then
          i_end = i_mid
        else
          i_begin = i_mid
        end
      end
      i_begin
    end
		def set_playconfig new_playspeed = @playspeed
    	@playspeed = new_playspeed
			@t_playconfig = Time.now.to_f
      @t_data_playconfig = @t_data
      @t_offset = @t_playconfig - @t_data_playconfig / @playspeed unless @playspeed == 0
			@play_time_text.value = @t_data.to_i.to_s
			@play_time_slider.value = @t_data.to_i
    end
  end
end