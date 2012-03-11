# To change this template, choose Tools | Templates
# and open the template in the editor.

module Mv
  class DataSourceView
    include Gadget
    def initialize args
      parent = args[:parent]
      @frame = THE_APP.xrc.load_panel(parent,'data_source_panel')
      @comText = Wx::Window.find_window_by_id(Wx::xrcid('comText'), @frame)
      @fileText = Wx::Window.find_window_by_id(Wx::xrcid('fileText'), @frame)
      @dataSourceRadioBox = Wx::Window.find_window_by_id(Wx::xrcid('dataSourceRadioBox'), @frame)
      @openDialogButton = Wx::Window.find_window_by_id(Wx::xrcid('openDialogButton'), @frame)
      @statusLabel = Wx::Window.find_window_by_id(Wx::xrcid('statusLabel'), @frame)
      @updateButton = Wx::Window.find_window_by_id(Wx::xrcid('updateButton'), @frame)
			@closeButton = Wx::Window.find_window_by_id(Wx::xrcid('closeButton'), @frame)
      @timeText = Wx::Window.find_window_by_id(Wx::xrcid('timeText'), @frame)
      @frame.evt_text_enter(@timeText.get_id){
        t = @timeText.value.to_f
        THE_APP.data_source.t_data = t
      }
      @frame.evt_button(@updateButton.get_id){
        THE_APP.data_source.close if THE_APP.data_source
        begin
          case @dataSourceRadioBox.string_selection
          when "Com"
            THE_APP.data_source = SylphideSerialCom.new(@comText.value.to_i)
            @statusLabel.label = "Reading Com#{@comText.value.to_i}"
            THE_APP.alert.update :data_source => "Com"
          when "File"
            THE_APP.data_source = FileCom.new(@fileText.value)
            lpath = 16
            filename = @fileText.value
            path_string = filename.length > (lpath*2+3) ? (filename[0..lpath] + "..." + filename[-lpath..-1]) : filename
            @statusLabel.label = "Reading #{path_string}"
						THE_APP.alert.update :data_source => "File"
          end
          THE_APP.properties.set_changed :data_source_updated
					THE_APP.properties.notify_listeners
        rescue => evar
          Wx::message_box evar.inspect, "Error"
        end
      }
			@frame.evt_button(@closeButton.get_id){
				if THE_APP.data_source
					THE_APP.data_source.close
					THE_APP.data_source = nil
				end
			}

      @frame.evt_button(@openDialogButton.get_id){
        @dataSourceRadioBox.string_selection = "File"
        dlg = Wx::FileDialog.new(@frame,"Choose a file","","","time table(*.ttb)|*.ttb|all files(*.*)|*")
        if dlg.show_modal==Wx::ID_OK then
          @fileText.value = dlg.get_path
        end
      }
    end
  end
end
