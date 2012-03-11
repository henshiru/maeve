# To change this template, choose Tools | Templates
# and open the template in the editor.

require 'single_needle_indicator_drawer'

module Mv
  class VelocityView
    include Gadget
    def initialize args
      @frame = BufferedControl.new(args)
      @frame.evt_paint{
        on_paint @frame.memdc
        @frame.update
      }
      THE_APP.com(0).add_property_listener(:velocity){
        @frame.refresh false,nil
      }
      @drawer = SingleNeedleIndicatorDrawer.new :n_marker=>10, :step_marker=>10, :unit_text=>"m/s"
      @back_brush = Wx::Brush.new(Wx::Colour.new(0,0,0))
    end
    def on_paint dc
      dc.background = @back_brush
      dc.brush = @back_brush
      dc.clear
      com = THE_APP.com(0)
      width = @frame.size.width
      height = @frame.size.height
      velocity = com[:velocity].r
      @drawer.draw dc, width, height, velocity
    end
  end
end
