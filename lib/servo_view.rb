# To change this template, choose Tools | Templates
# and open the template in the editor.

module Mv
  class ServoView
    include Gadget
    CLASSIC_T = 0
    AERO_T = 1
    def initialize args
			@frame = BufferedControl.new(args)
			default_conf = {:type=>1}
			ConfigReader.fill THE_APP.config[:servo_view]||={}, default_conf
			@conf = THE_APP.config[:servo_view]
      @type = THE_APP.config[:servo_view][:type]
      create @type
			THE_APP.properties.add_listener(:config){update nil}
      @frame.evt_paint{
        @view.on_paint @frame.memdc
        @frame.update
      }
    end
    def update args
      type_new = @conf[:type]
      unless @type == type_new
        @type = type_new
        create @type
      end
      @frame.refresh false, nil
    end
    def create type
      @view.on_close if @view
      @view = case type
        when CLASSIC_T then ServoViewClassic.new(:parent => @frame)
        when AERO_T then ServoViewAero.new(:parent => @frame)
      end
    end
    def self.getServo
			acname = THE_APP.config[:selected_aircraft_name]
			conf = THE_APP.config[:aircraft][acname]
			ch = conf[:ch_cic]
			neu = conf[:neu_cic] || conf[:neu_common]
			sgn = conf[:sgn_cic]
			sv = THE_APP.com(0)[:servo_in][ch]
			if (sgn*(sv - neu) > 0 && sv > 0)
				return THE_APP.com(0)[:servo_out]
			else
				return THE_APP.com(0)[:servo_in]
			end
    end
    def self.getVirtualServo sv
      acname = THE_APP.config[:selected_aircraft_name]
			conf = THE_APP.config[:aircraft][acname]
			dev_t = conf[:dev_type]
      ail = sv[conf[:ch_ail]]
      elv = sv[conf[:ch_elv]]
      thr = sv[conf[:ch_thr]]
      rud = sv[conf[:ch_rud]]
      virtual_sv = case dev_t
      when 'normal' || ''
        {:ail=>ail, :elv=>elv, :thr=>thr, :rud=>rud}
      when 'elevon-rudder'
        elevon_r = sv[conf[:ch_eln_r]]
        elevon_l = sv[conf[:ch_eln_l]]
        virtual_ail = (elevon_l + elevon_r) / 2
        virtual_elv = (elevon_l - elevon_r) / 2
        {:ail=>virtual_ail, :elv=>virtual_elv, :thr=>thr, :rud=>rud}
      else
        raise "There's no such configuration as \"#{dev_t}\"!"
      end
      return virtual_sv
    end
		def self.isOn device, control = self.getServo
			devname = self.devname device
			acname = THE_APP.config[:selected_aircraft_name]
			conf = THE_APP.config[:aircraft][acname]
			if ch = conf[('ch_' + devname).to_sym]
				neu = conf[('neu_' + devname).to_sym] || conf[:neu_common]
				sgn = conf[('sgn_' + devname).to_sym] || 1
	      sv = control[ch]
				if neu && sv
					(sgn*(sv - neu) > 0 && sv > 0) ? true : false
				else
					false
				end
			else
				nil
			end
		end
		def self.percent device, control = self.getServo
			devname = self.devname device
			acname = THE_APP.config[:selected_aircraft_name]
			conf = THE_APP.config[:aircraft][acname]
			if ch = conf[('ch_' + devname).to_sym]
				max = conf[('max_' + devname).to_sym]
				min = conf[('min_' + devname).to_sym]
				sgn = conf[('sgn_' + devname).to_sym] || 1
				sv = control[ch]
				if max && min && sv
					return 100 * (max*(1-sgn)/2 - min*(1+sgn)/2 + sv*sgn) / (max - min)
				else
					return 0
				end
			else
				nil
			end
		end
		def self.rad device, control = self.getServo
			devname = self.devname device
			acname = THE_APP.config[:selected_aircraft_name]
			conf = THE_APP.config[:aircraft][acname]
			ch = conf[('ch_' + devname).to_sym]
			neu = conf[('neu_' + devname).to_sym] || conf[:neu_common]
			r2v = conf[('r2v_' + devname).to_sym]		
			sv = control[ch]
			if ch && neu && r2v && sv
				return (sv - neu) / r2v.to_f
			else
				return 0
			end
		end
		def self.devname device
		# ret: short device name such as 'ail' for aileron
		# args: device name(String or Symbol) or device channel
			devname = case device
			when String
				device
			when Symbol
				device.to_s
			when Fixnum
				key_found = 'invalid_device'
				THE_APP.config[:aircraft].each do |key,val|
					if val.to_i == device && key.to_s[0..2] == 'ch_'
						key_found = key.to_s[3..-1]
						break
					end
				end
				key_found
			else
				'invalid_device'
			end
		end
  end
  class ServoViewBase
		CLASSIC_T = 0
    AERO_T = 1
  	POP_CLASSIC = 10
  	POP_AERO = 11
  	attr_reader :properties
  	def initialize args
      @frame = args[:parent]
      @br_back = Wx::Brush.new(Wx::Colour.new(0, 0, 0))
      @center_line_pen = Wx::Pen.new(Wx::Colour.new(255, 255, 255))
      @mid_line_pen = Wx::Pen.new(Wx::Colour.new(128, 128, 128))
      @mark_colors = [
        [255, 128, 128],
        [128, 255, 128],
        [128, 128, 255],
        [255, 255,  64],
        [255,  64, 255],
        [ 64, 255, 255],
        [255, 128,  64],
        [ 64, 128, 255],
      ].map{|c|
        Wx::Colour.new(*c)
      }
      @mark_pens = @mark_colors.map{|c|Wx::Pen.new(c, 3)}
      THE_APP.com(0).add_property_listener(:servo_in, :servo_out){
        @frame.refresh false, nil
      }
			@sv_in = THE_APP.com(0)[:servo_in]
			@sv_out = THE_APP.com(0)[:servo_out]
			@pop_menu = Wx::Menu.new
			@pop_menu.append_radio_item(POP_CLASSIC, "Classic(&C)")
			@pop_menu.append_radio_item(POP_AERO, "Aero(&A)")
			@pop_menu.append_separator
			@frame.evt_right_down{@frame.popup_menu(@pop_menu)}
  		@frame.evt_menu(POP_CLASSIC){on_property_changed :type, CLASSIC_T}
			@frame.evt_menu(POP_AERO){on_property_changed :type, AERO_T}
  	end
    def on_close
      # virtual
    end
  	private
  	def on_property_changed key, val
			THE_APP.config[:servo_view][key] = val
      THE_APP.properties.set_changed :config
      THE_APP.properties.notify_listeners
  	end
  end
  class ServoViewClassic < ServoViewBase
    SERVO_SCALE = 1024*3
		def initialize args
  		super args
			@font_size = 10
      @font = Wx::Font.new(@font_size, Wx::FONTFAMILY_DEFAULT,
        Wx::FONTSTYLE_NORMAL, Wx::FONTWEIGHT_BOLD)
			@pop_menu.check(POP_CLASSIC, true)
  	end
    def on_paint dc
      dc.background = @br_back
      dc.brush = @br_back
      dc.clear
      dc.font = @font
      width = @frame.size.width
      height = @frame.size.height

      dc.pen = @center_line_pen
      dc.draw_line(0, height*2/4, width, height*2/4)

      com = THE_APP.com(0)
      y_range = height/2*80/100

      dc.pen = @mid_line_pen
      dc.draw_line(0, height*1/4-y_range/2, width, height*1/4-y_range/2)
      dc.draw_line(0, height*1/4, width, height*1/4)
      dc.draw_line(0, height*1/4+y_range/2, width, height*1/4+y_range/2)

      dc.text_foreground = Wx::WHITE
      dc.draw_text("SERVO OUT", 0, 0)

      y_out = height/4 + y_range/2
      
      @sv_out.each_with_index{|v, i|
        dc.pen = @mark_pens[i]
        x1 = i*width/@sv_out.length
        x2 = (i+1)*width/@sv_out.length
        y = y_out - y_range*v/SERVO_SCALE
        dc.draw_line(x1, y, x2, y)
        dc.text_foreground = @mark_colors[i]
        dc.draw_text((i+1).to_s, x1, height/2-@font_size*2)
      }

      dc.pen = @mid_line_pen
      dc.draw_line(0, height*3/4-y_range/2, width, height*3/4-y_range/2)
      dc.draw_line(0, height*3/4, width, height*3/4)
      dc.draw_line(0, height*3/4+y_range/2, width, height*3/4+y_range/2)

      dc.text_foreground = Wx::WHITE
      dc.draw_text("SERVO IN", 0, height/2)
      
      y_in = height*3/4 + y_range/2
      @sv_in.each_with_index{|v, i|
        dc.pen = @mark_pens[i]
        x1 = i*width/@sv_in.length
        x2 = (i+1)*width/@sv_in.length
        y = y_in - y_range*v/SERVO_SCALE
        dc.draw_line(x1, y, x2, y)

        dc.text_foreground = @mark_colors[i]
        dc.draw_text((i+1).to_s, x1, height-@font_size*2)
      }
    end
  end
  class ServoViewAero < ServoViewBase
  	def initialize args
  		super args
      aircraft_init
			@font_size = 14
      @font = Wx::Font.new(@font_size, Wx::FONTFAMILY_DEFAULT,
        Wx::FONTSTYLE_NORMAL, Wx::FONTWEIGHT_BOLD)
      @flg_MTD = false	#max thrust detection
			pic_color = Wx::Colour.new(255, 0, 0)
      cic_color = Wx::Colour.new(0, 255, 0)
      @pic_brush = Wx::Brush.new(pic_color)
      @cic_brush = Wx::Brush.new(cic_color)
      @pic_pen = Wx::Pen.new(pic_color, 3)
      @cic_pen = Wx::Pen.new(cic_color, 3)
      @inivisible_pen = Wx::NULL_PEN
			@pop_menu.check(POP_AERO, true)
			@pop_menu.append(pop_stick_init = 20, "Stick Init(&I)")
			@pop_menu.append_check_item(pop_mtd = 21, "Max Thrust Detect(&T)")
			@frame.evt_menu(pop_stick_init){stick_init}
			@frame.evt_menu(pop_mtd){
				if @pop_menu.is_checked(pop_mtd)
					@flg_MTD = true
					@ac[:max_thr] = 1500
				else
					@flg_MTD = false
				end
			}
      @registered_procs = []
      @registered_procs.push THE_APP.properties.add_listener(:config){aircraft_init}
  	end
    def on_paint dc
      indicators = []
      dc.background = @br_back
      dc.brush = @br_back
      dc.clear
      dc.font = @font
      width = @frame.size.width
      height = @frame.size.height    
      dc.pen = @mid_line_pen
      dc.cross_hair(width/2, height/2)
  
      x_range = width
      y_range = height
      isCIC = ServoView.isOn 'cic'
      dc.brush = isCIC ? @cic_brush : @pic_brush
      sv = ServoView.getVirtualServo(ServoView.getServo)
    	@ac[:max_thr] = [@ac[:max_thr], sv[:thr]].max if @flg_MTD

      #draw indicators
      indicators.push ['A', @ac[:ch_ant]] if ServoView.isOn 'ant'
    	indicators.push ['F', @ac[:ch_flp]] if ServoView.isOn 'flp'
			indicators.push ['T', @ac[:ch_tip]] if ServoView.isOn 'tip', @sv_in
      indicators.each_with_index do |ind,i|
        dc.text_foreground = @mark_colors[ind[1]]
        dc.draw_text(ind[0], 10+15*i, 0)
      end
      #draw throttle
      bar_width = 8
      thr_range = (@ac[:max_thr] - @ac[:min_thr])
      y_thr = height - (sv[:thr] - @ac[:min_thr])*y_range/thr_range
      dc.pen = @inivisible_pen
      dc.draw_rectangle(0, y_thr, bar_width, height-y_thr)
      #draw rudder
      x_rud = width/2 + @ac[:sgn_rud]*(sv[:rud] - @ac[:neu_rud])*x_range/@ac[:range_rud]
      dc.pen = isCIC ? @cic_pen : @pic_pen
      dc.draw_line(x_rud, height-20, x_rud, height)
      #draw control column       
      column = []
      column[0] = width/2 + @ac[:sgn_ail]*(sv[:ail] - @ac[:neu_ail])*x_range/@ac[:range_ail]
      column[1] = height/2 - @ac[:sgn_elv]*(sv[:elv] - @ac[:neu_elv])*y_range/@ac[:range_elv]
      dc.pen = @inivisible_pen
      dc.draw_circle(column, 5)
    end
    def on_close
      @registered_procs.each do |proc| THE_APP.properties.remove_listener proc end
    end
		private
    def stick_init
    	sv = ServoView.getVirtualServo(ServoView.getServo)
			@ac[:neu_ail] = sv[:ail]
			@ac[:neu_elv] = sv[:elv]
			@ac[:neu_rud] = sv[:rud]
			@ac[:min_thr] = sv[:thr]
    end
    def aircraft_init
      # load new aircraft
      acname = THE_APP.config[:selected_aircraft_name]
			@ac = THE_APP.config[:aircraft][acname]
      # check validity of settings
      neededConfig = [
    		:ch_ail, :ch_elv, :ch_thr, :ch_rud, :ch_cic,
    		:neu_ail, :neu_elv, :neu_rud, :neu_common, :max_thr, :min_thr,
    	]
    	ConfigReader.check @ac, neededConfig
      # add some useful values to aircraft settings
      ['ail', 'elv', 'rud'].each do |dev|
				# logical signs of each device
				@ac[('sgn_'+dev).to_sym] = @ac[('r2v_'+dev).to_sym] / @ac[('r2v_'+dev).to_sym].abs
			end
			['ail', 'elv', 'rud'].each do |dev|
				# ranges of each device to be displayed
				@ac[('range_'+dev).to_sym] = @ac[('max_'+dev).to_sym] - @ac[('min_'+dev).to_sym]
			end
      
      THE_APP.debug_message "aircraft #{acname} was loaded"
    end
  end
end