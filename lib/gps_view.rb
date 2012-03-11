require 'gadget'

module Mv
  class GpsView
    include Gadget
    def initialize args
      @frame = BufferedControl.new(args)
      @frame.evt_paint{
        on_paint @frame.memdc
        @frame.update
      }
      THE_APP.com(0).add_property_listener(:satellites){
        @frame.refresh false,nil
      }
      @white_pen = Wx::Pen.new(Wx::Colour.new(255,255,255),1)
      @black_pen = Wx::Pen.new(Wx::Colour.new(0,0,0),1)
      @br_back = Wx::Brush.new(Wx::Colour.new(0,0,0))
      @br_white = Wx::Brush.new(Wx::Colour.new(255,255,255))
      @br_gray = Wx::Brush.new(Wx::Colour.new(192,192,192))
      @br_red = Wx::Brush.new(Wx::Colour.new(255,192,192))
      @br_orange = Wx::Brush.new(Wx::Colour.new(255,224,192))
      @br_yellow = Wx::Brush.new(Wx::Colour.new(255,255,192))
      @br_green = Wx::Brush.new(Wx::Colour.new(192,255,192))
      @br_blue = Wx::Brush.new(Wx::Colour.new(192,192,255))
    end
    private
    def on_paint dc
      sts = THE_APP.com(0)[:satellites]
      margin = 4
      width = @frame.size.width
      height = @frame.size.height
      r_circle = [width,height].min/2 - margin
      x_circle = width/2
      y_circle = height/2
      dc.background = @br_back
      dc.brush = @br_back
      dc.pen = @white_pen
      dc.clear
      (1..6).to_a.reverse.each{|i|
        r_current = r_circle*i/6
        dc.draw_circle(x_circle,y_circle,r_current)#0 deg
      }
      dc.pen = @black_pen
      sts.each{|st|
        marker_size = 12
        r_current = r_circle*(90-st[:elevation])/90
        azim_rad = Math::PI*st[:azimuth]/180
        x_marker = x_circle + r_current*Math.sin(azim_rad)
        y_marker = y_circle + r_current*Math.cos(azim_rad)
        dc.brush = [@br_red,@br_red,@br_red,@br_orange,@br_yellow,@br_green,@br_green,@br_blue][st[:quality]] || @br_gray
        dc.draw_circle(x_marker.to_i,y_marker.to_i,marker_size)
        label = st[:id].to_s
        t_ext = dc.text_extent(label)
        dc.draw_text(label,x_marker.to_i-t_ext[0]/2,y_marker.to_i-t_ext[1]/2)
      }
    end
  end
end
