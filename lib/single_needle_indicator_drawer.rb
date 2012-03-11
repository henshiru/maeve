# To change this template, choose Tools | Templates
# and open the template in the editor.

module Mv
  class SingleNeedleIndicatorDrawer
    def initialize args
      @white_color = Wx::Colour.new(230,255,240)
      @white_pen = Wx::Pen.new(@white_color,2)
      @white_brush = Wx::Brush.new(@white_color)
      @transparent_brush = Wx::Brush.new(Wx::BLACK, Wx::TRANSPARENT)
      @font = Wx::Font.new(14,Wx::FONTFAMILY_DEFAULT,Wx::FONTSTYLE_NORMAL,Wx::FONTWEIGHT_NORMAL)
      @unit_text = args[:unit_text]
      @margin = args[:margin] || 10
      @n_marker = args[:n_marker]
      @step_marker = args[:step_marker]
    end
    def draw dc, width, height, value_to_show
      r_circle = [width,height].min/2 - @margin
      r_center_circle = r_circle/5
      x_circle = width/2
      y_circle = height/2
      dc.brush = @transparent_brush
      dc.pen = @white_pen
      dc.font = @font
      dc.draw_circle(x_circle,y_circle,r_circle)
      dc.draw_circle(x_circle,y_circle,r_center_circle)

      dc.brush = @white_brush
      dc.text_foreground = @white_color

      t_ext = dc.text_extent(@unit_text)
      dc.draw_text(@unit_text,
        (x_circle - t_ext[0]/2).to_i,
        (y_circle + r_center_circle).to_i
      )
      n_small_marker = @n_marker*5
      marker_size = r_circle/8
      small_marker_size = marker_size/2
      text_margin = r_circle/10
      n_small_marker.times{|i|
        theta = Math::PI*2/n_small_marker*i
        dc.draw_line(
          (x_circle + r_circle*Math.sin(theta)).to_i,
          (y_circle - r_circle*Math.cos(theta)).to_i,
          (x_circle + (r_circle-small_marker_size)*Math.sin(theta)).to_i,
          (y_circle - (r_circle-small_marker_size)*Math.cos(theta)).to_i
        )
      }
      @n_marker.times{|i|
        value = @step_marker*i
        label = value.to_s
        t_ext = dc.text_extent(label)
        theta = Math::PI*2/@n_marker*i
        dc.draw_line(
          (x_circle + r_circle*Math.sin(theta)).to_i,
          (y_circle - r_circle*Math.cos(theta)).to_i,
          (x_circle + (r_circle-marker_size)*Math.sin(theta)).to_i,
          (y_circle - (r_circle-marker_size)*Math.cos(theta)).to_i
        )
        dc.draw_text(label,
          (x_circle + (r_circle-marker_size-text_margin)*Math.sin(theta)).to_i - t_ext[0]/2,
          (y_circle - (r_circle-marker_size-text_margin)*Math.cos(theta)).to_i - t_ext[1]/2
        )
      }
      theta = Math::PI*2/(@step_marker*@n_marker)*value_to_show
      r_indicator = r_circle
      w_indicator = r_circle/30
      dc.draw_polygon([[
            (x_circle + r_indicator*Math.sin(theta)).to_i,
            (y_circle - r_indicator*Math.cos(theta)).to_i
          ],
          [
            (x_circle + w_indicator*Math.sin(theta+Math::PI/2)).to_i,
            (y_circle - w_indicator*Math.cos(theta+Math::PI/2)).to_i
          ],
          [
            (x_circle + w_indicator*Math.sin(theta-Math::PI/2)).to_i,
            (y_circle - w_indicator*Math.cos(theta-Math::PI/2)).to_i
          ]
        ])
    end
  end
end