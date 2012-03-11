# To change this template, choose Tools | Templates
# and open the template in the editor.

module Mv
  class DataLoggerView
    include Gadget
    def initialize args
      @frame = THE_APP.xrc.load_panel(args[:parent],'data_logger_panel')
      @openDialogButton = Wx::Window.find_window_by_id(Wx::xrcid('openDialogButton'), @frame)
      @directoryText = Wx::Window.find_window_by_id(Wx::xrcid('directoryText'), @frame)
      @filenameText = Wx::Window.find_window_by_id(Wx::xrcid('filenameText'), @frame)
      @statusLabel = Wx::Window.find_window_by_id(Wx::xrcid('statusLabel'), @frame)
      @startStopButton = Wx::Window.find_window_by_id(Wx::xrcid('startStopButton'), @frame)
      @saveTimeTableCheck = Wx::Window.find_window_by_id(Wx::xrcid('saveTimeTableCheck'), @frame)
      @logging_path = nil
      @save_time_table = false
      @frame.evt_button(@openDialogButton.get_id){
        dlg = Wx::DirDialog.new(@frame,"Choose a directory.","")
        if dlg.show_modal==Wx::ID_OK then
          @directoryText.value = dlg.get_path
        end
      }
      @frame.evt_button(@startStopButton.get_id){
        filename = @filenameText.value
        filename = filename.gsub(/%(.)/){
          com = THE_APP.com(0)
          case $1.upcase
          when 'G'
            ("0"*10 + (com[:itow]*1000).to_i.to_s)[-10,10]
          else
            '%'+$1
          end
        }
        filename = Time.now.strftime(filename)
        filename.gsub!('/','-')
        filename.gsub!(':','-')
        filename.gsub!(' ','_')
        filepath = File.join(@directoryText.value,filename)
        @save_time_table = @saveTimeTableCheck.checked?
        if @logging_path
          @logging_path = nil
          THE_APP.stop_logging
          THE_APP.alert.update :logging => false
        else
          @logging_path = filepath
          begin
	        	THE_APP.start_logging @logging_path, @save_time_table
          rescue => evar
						Wx::message_box evar.message, "Error"
						@logging_path = nil
						next
          end
					THE_APP.alert.update :logging => true
        end
        update_label
      }
    end
    private
    def update_label
      if @logging_path
        with_time_table = @save_time_table ? "(and timetable) ":""
        lpath = 20
        path_string = @logging_path.length > (lpath*2+3) ? (@logging_path[0..lpath] + "..." + @logging_path[-lpath..-1]) : @logging_path
        @statusLabel.label = "logging data " + with_time_table + "to \n\"#{path_string}\"."
      else
        @statusLabel.label = "logging stopped."
      end
    end
  end
end
