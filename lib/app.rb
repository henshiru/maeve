require 'singleton'
require 'map_view'
require 'attitude_view'
require 'altitude_view'
require 'velocity_view'
require 'gps_view'
require 'data_source_view'
require 'data_logger_view'
require 'command_view'
require 'text_info_view'
require 'packet_count_view'
require 'servo_view'
require 'config_reader'
require 'sylphide_serial_com'
require 'file_com'
require 'com_dump_proxy'
require 'sylphide_communicator'
require 'gain_transfer_dialog'
require 'status_view_dialog'
require 'flightplan_transfer_dialog'
require 'fhi_upload_dialog'
require 'flightplan_manager'
require 'property_holder'
require 'alert'
require 'log_manager'

module Mv
  BASE_DIR = File.expand_path(File.dirname(__FILE__)).tosjis	#FIXME windows specific
  
  #command ID
  CID_GAIN_TRANSFER = 100
  CID_FLIGHTPLAN_TRANSFER = 200
  CID_FHI_UPLOAD = 300

  class App < Wx::App
    include Singleton
    attr_reader :xrc, :config, :frame, :flightplan_manager, :properties, :alert
    attr_accessor :data_source
    def com index
      case index
      when 0
        @communicator
      else
        nil#FIXME
      end
    end
    def on_init
			Dir.chdir(BASE_DIR)
    	begin
	      @xrc = Wx::XmlResource.new("../xrc/maeve.xrc")
				@config_filename = "config.rb"
	      @config = ConfigReader.read @config_filename
    	rescue => evar
				Wx::message_box evar.inspect, "Error"
    	end
      @data_source = nil
      @communicator = SylphideCommunicator.new
      @flightplan_manager = FlightplanManager.new
      @properties = PropertyHolder.new
      @alert = Alert.new
			@command_logger = LogManager.new("../command_log", 3600*24*30)
				#keep command logs for 30 days
      init_frame

      @frame.evt_menu(Wx::xrcid('chooseAircraftMenu')){|evt|
      	choices = @config[:aircraft].keys.sort
				dlg = Wx::SingleChoiceDialog.new(@frame, "Choose an aircraft.", 
	        "Aircraft selection", choices)
        dlg.set_selection choices.index(@config[:selected_aircraft_name])
        if dlg.show_modal == Wx::ID_OK
        	@config[:selected_aircraft_name] = dlg.get_string_selection
        end
        on_config_changed
			}
      @frame.evt_menu(Wx::xrcid('applyConfigMenu')){|evt|
				Wx::message_box "This function is temporarily disabled.", "Sorry"
#      	on_config_changed
      }
      @frame.evt_menu(Wx::xrcid('exitMenu')){|evt|
        @frame.close
      }
      gain_transfer_dialog = GainTransferDialog.new
      @frame.evt_menu(Wx::xrcid('gainMenu')){|evt|
        gain_transfer_dialog.show
      }
      flightplan_transfer_dialog = FlightplanTransferDialog.new
      @frame.evt_menu(Wx::xrcid('flightplanMenu')){|evt|
        flightplan_transfer_dialog.show
      }
      fhi_upload_dialog = FHIUploadDialog.new
      @frame.evt_menu(Wx::xrcid('fhiUploadMenu')){|evt|
        fhi_upload_dialog.show
      }
      status_view_dialog = StatusViewDialog.new
      @frame.evt_menu(Wx::xrcid('statusMenu')){|evt|
        status_view_dialog.show
      }
      @frame.evt_menu(Wx::xrcid('landscapeMenu')){|evt|
        @map_view.show_children
      }
      

      menu_bar = @frame.menu_bar
      main_sizer = @frame.get_sizer
      upper_sizer = main_sizer.get_item(0).sizer
      left_bar = upper_sizer.get_item(0).sizer
      bottom_bar = main_sizer.get_item(1).sizer
      @status_bar = @frame.status_bar

      @map_view = MapView.new(:parent => @frame, :pos => [0,0], :size => [800,600])
      @attitude_view = AttitudeView.new(:parent => @frame)
      @gps_view = GpsView.new(:parent => @frame)
      @altitude_view = AltitudeView.new(:parent => @frame)
      @velocity_view = VelocityView.new(:parent => @frame)
      @data_source_view = DataSourceView.new(:parent=>@frame)
      @data_logger_view = DataLoggerView.new(:parent=>@frame)
      @packet_count_view = PacketCountView.new(:parent=>@frame)
      @text_info_view = TextInfoView.new(:parent=>@frame)
      @command_view = CommandView.new(:parent=>@frame)
      @servo_view = ServoView.new(:parent => @frame)
      
      upper_sizer.add(@map_view.frame, 300, Wx::EXPAND)
      left_bar.add(@data_source_view.frame, 100, Wx::EXPAND)
      left_bar.add(@packet_count_view.frame, 100, Wx::EXPAND)
      left_bar.add(@data_logger_view.frame, 100, Wx::EXPAND)
      left_bar.add(@text_info_view.frame, 100, Wx::EXPAND)
      left_bar.add(@command_view.frame, 100, Wx::EXPAND)
      bottom_bar.add(@attitude_view.frame, 100, Wx::EXPAND)
      bottom_bar.add(@servo_view.frame, 50, Wx::EXPAND)
      bottom_bar.add(@gps_view.frame, 100, Wx::EXPAND)
      bottom_bar.add(@altitude_view.frame, 100, Wx::EXPAND)
      bottom_bar.add(@velocity_view.frame, 100, Wx::EXPAND)
      
      @timer = Wx::Timer.new(self)
      evt_timer(@timer.get_id()){on_timer}
      @timer.start(20)
      @frame.show
    end
    def start_logging filepath, with_time_table
      filepath = filepath.tosjis#FIXME windows-specific?
      @logging_output = File.new(filepath,"wb")
      dirname = File.dirname(filepath)
      basename = File.basename(filepath,".*")
      @time_table_output = File.new(dirname + "/" + basename + ".ttb","w")
      @time_table_output << File.basename(filepath) << "\n"
    end
    def stop_logging
      if @logging_output
        @logging_output.close
        @logging_output = nil
      end
    end
    def debug_message message
      @text_info_view.push_info "debug", message
    end
    def status_message message
      @status_bar.push_status_text message
    end
    def send_data cid, data, ack_req=false, ack_res=false
			if @data_source
				str = @communicator.packetize([cid].pack('s') + data, ack_req, ack_res)
				@data_source.send(str)
				@command_logger.log(str)
			end
    end
    def on_close
      @timer.stop
    end
    def on_config_changed
#		  @config = ConfigReader.read @config_filename
		  @properties.set_changed :config
		  @properties.notify_listeners
    end
    private
    def pack_gps_coord x
      sgn = (x<0)?1:0
      x = x.abs
      i = x.floor
      m = ((x-i)*60).floor
      s = (((x-i)*60-m)*60).floor
      d = ((x-i)*60-m)*60 - s
      [sgn, i.to_i, m.to_i, s.to_i, (d*10000).to_i].pack("v*")
    end
    def on_timer
      data = @data_source.receive if @data_source
      if data
        data_all = data
        block_size = 1024
        (data_all.length/block_size + ((data_all.length%block_size != 0)?1:0)).times{|i|
          data = data_all[i*block_size...[(i+1)*block_size,data_all.length].min]
          @communicator.update data
          @logging_output << data if @logging_output
          @time_table_output << THE_APP.com(0)[:itow] << "," << data.length << "\n" if @time_table_output
        }
      end
    end
    def init_frame
      xml = self.xrc
      @frame = xml.load_frame(nil,'main_frame')
      @frame.set_size(1000,750)
      @frame.evt_close{
        THE_APP.on_close
        @frame.destroy
      }
    end
  end

end