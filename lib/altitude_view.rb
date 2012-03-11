# To change this template, choose Tools | Templates
# and open the template in the editor.

require 'gadget'

module Mv
  class AltitudeView
  	PopMenu_ShowHistory = 0
    include Gadget
		class GraphicHistoryHolder < HistoryHolder
	    def initialize args
	      super args
	      cf = args[:conf]
	      @drawer = HistoryDrawer.new :data=>@history, 
	      	:uvalue=>[:t,'','s'], :vvalue=>[:alt,'','m'],
					:urange=>[-@span,10,0], :vrange=>cf[:hist_vertical_range], 
	      	:line_pen=>Wx::Pen.new(Wx::Colour.new(192,160,96),2), 
	      	:text_fg=>Wx::Colour.new(230,255,240)
				THE_APP.properties.add_listener(:data_source_updated){clear}
				def clear
		    	@history.clear
		    	@drawer.set_data @history
		    end
		    def draw dc, width, height
		    	@drawer.draw dc, width, height
		    end
	    end
	  end
    def initialize args
      @frame = BufferedControl.new(args)
      @frame.evt_paint{
        on_paint @frame.memdc
        @frame.update
      }
      THE_APP.com(0).add_property_listener(:altitude){
        @frame.refresh false,nil
      }
			default_cf = {:hist_on=>false, :hist_span=>60, :hist_vertical_range=>[0,50,200]}
			ConfigReader.fill THE_APP.config[:altitude_view]||={}, default_cf
			cf = THE_APP.config[:altitude_view]
      @drawer = SingleNeedleIndicatorDrawer.new :n_marker=>10, :step_marker=>20, :unit_text=>"m"
			@history_holder = GraphicHistoryHolder.new :min_interval=>1, :span=>cf[:hist_span], :conf=>cf
			@history_on = cf[:hist_on]
      @back_brush = Wx::Brush.new(Wx::Colour.new(0,0,0))
			@pop_menu = Wx::Menu.new
  		@pop_menu.append_check_item(PopMenu_ShowHistory, "Show History(&H)")
  		@pop_menu.check(PopMenu_ShowHistory, @history_on)
			@frame.evt_menu(PopMenu_ShowHistory){
				@history_on = if @pop_menu.is_checked(PopMenu_ShowHistory)
					true
        else
					@history_holder.clear
					 false
        end
				@frame.refresh false, nil
      }
			@frame.evt_right_down{|evt| @frame.popup_menu(@pop_menu)}
    end
    def on_paint dc
      dc.background = @back_brush
      dc.brush = @back_brush
      dc.clear
      com = THE_APP.com(0)
      width = @frame.size.width
      height = @frame.size.height
      if @history_on
				@history_holder.push :t=>com[:itow], :alt=>com[:altitude]
	      @history_holder.draw dc, width, height
      end
      @drawer.draw dc, width, height, com[:altitude]
    end
  end
end