require 'gadget'

module Mv
  class Landscape
    attr_reader :image, :top, :bottom, :right, :left, :deg2pix, :alt2pix
    attr_accessor :bearing
    def initialize args
      @image = args[:image]
      @top = args[:top]
      @bottom = args[:bottom]
      @left = args[:left]
      @right = args[:right]
			@map_view = args[:map_view]
      @bearing = 0.0
      @deg2pix = @image.width / (@right - @left).to_f # pix per deg
      @alt2pix = @image.height / (@top - @bottom).to_f # pix per alt[m]
    end
    def set_view args
      @map_view = args[:map_view]
    end
    def gps_to_landscape pos
      direction_to_landscape gps_to_direction(pos)
    end
    def landscape_to_gps pos
      @map_view.map_to_gps pos
    end
    alias gps_to_map gps_to_landscape
    alias map_to_gps landscape_to_gps
    
    def gps_to_direction pos
			fudge_alt = -1000	# dirty trick to fake up an altitude for a 2D wp
      parent_width = @map_view.frame.size.width
      parent_height = @map_view.frame.size.height - @map_view.children_frames[:landscape_view].size.height
      cos_psi = Math.cos(@bearing / 57.3)
      sin_psi = Math.sin(@bearing / 57.3)
      surf_map_pos = @map_view.map_to_view(@map_view.map.gps_to_map(pos))
      surf_map_xrel = (surf_map_pos[0] - parent_width/2)  # x relative to frame center of surf_map
      surf_map_yrel = (surf_map_pos[1] - parent_height/2)
      x_ls = cos_psi*surf_map_xrel + sin_psi*surf_map_yrel + parent_width/2  # x(right) of landscape
      z_ls = sin_psi*surf_map_xrel - cos_psi*surf_map_yrel + parent_height/2  # z(depth) of landscape
      theta = Math.atan((x_ls - parent_width/2) / z_ls) * 57.3
      psi = @bearing + theta
      alt = pos[2] || fudge_alt
      [psi, alt]
    end
    def direction_to_landscape pos
      psi, alt = pos
      return [@image.width * (psi - @left) / (@right - @left),
        @image.height * (@top - alt) / (@top - @bottom)
      ]
    end
    def landscape_to_direction pos
      return [@left + pos[0] / @deg2pix, @top - pos[1] / @alt2pix]
    end
  end
	class LandscapeView
    ZOOM_STEP = 1.05
    ZOOM_MOUSEMOVE_UNIT = 10
		include Gadget
		attr_reader :frame, :map, :selected_wp_index
		def initialize args
			@frame = BufferedControl.new(args)
			@map = LandscapeReader.read "#{BASE_DIR}/../maps/landscape.rb"
			map_view = args[:map_view]
			@map.set_view :map_view=>map_view
			@parent_frame = args[:parent]
      @fpm = THE_APP.flightplan_manager
			@history_holder = HistoryHolder.new :tkey=>:itow,
			      	:min_interval=>2, :span=>60
    	@listeners = []
      @offset = [0,0]
      @zoom = [1.0,1.0]
      @font = Wx::Font.new(15, Wx::FONTFAMILY_DEFAULT,
        Wx::FONTSTYLE_NORMAL, Wx::FONTWEIGHT_BOLD)
      @back_brush = Wx::Brush.new(Wx::Colour.new(64,64,64))
      @bearing_pen = Wx::Pen.new(Wx::Colour.new(255,255,255),2)
			@marker_pen = Wx::Pen.new(Wx::Colour.new(255,0,0),6)
      @marker_pen_cic = Wx::Pen.new(Wx::Colour.new(0,255,0),6)
      @trajec_pen = Wx::Pen.new(Wx::Colour.new(192,160,96),2)
			@tic_pen = Wx::Pen.new(Wx::Colour.new(96,96,96),1,Wx::DOT)
			@mtic_pen = Wx::Pen.new(Wx::Colour.new(96,96,96),1,Wx::USER_DASH)
			@mtic_pen.set_dashes([1,10])
			@tic_font = Wx::Font.new(9, Wx::FONTFAMILY_DEFAULT,
        Wx::FONTSTYLE_NORMAL, Wx::FONTWEIGHT_NORMAL)
      @tic_text_fg = Wx::Colour.new(96,160,64)
      @selected_wp_index = map_view.selected_wp_index
			@frame.evt_paint{
        on_paint @frame.memdc
        @frame.update
      }
	    @frame.evt_left_down{|evt| on_left_down evt}
			@frame.evt_left_dclick{|evt|
				@frame.hide
				map_view.destroy_children
			}
			@frame.evt_left_up{|evt| on_left_up evt}
			@frame.evt_right_up{|evt| on_right_up evt}
      @frame.evt_motion{|evt| on_motion evt}
			@parent_frame.evt_size{|evt|
        evt_size = evt.get_size
        @frame.size = [evt_size.width, @frame.size.height]
        @frame.move [0, evt_size.height - @frame.size.height]
      }
      load_map nil
		end
    def landscape_to_view pos
      return [
        ((pos[0] - @image.width/2 + @offset[0])*@zoom[0]).to_i + @frame.size.width/2,
        ((pos[1] - @image.height/2 + @offset[1])*@zoom[1]).to_i + @frame.size.height/2
      ]
    end
    def view_to_landscape pos
      return [
        (pos[0] - @frame.size.width/2)/@zoom[0] - @offset[0] + @image.width/2,
        (pos[1] - @frame.size.height/2)/@zoom[1] - @offset[1] + @image.height/2
      ]
    end
    alias map_to_view landscape_to_view
    alias view_to_map view_to_landscape
    def draw_ext dc
      draw_bearing dc
    end
    def add_listener &proc
      @listeners.push proc
      proc
    end
    def remove_listener proc
      @listeners.delete proc
    end
    
    private
    def notify_listeners
      @listeners.each{|proc|
        proc.call
      }
    end
    def load_map filename
      @top_right = [@map.top, @map.right]
      @bottom_left = [@map.bottom, @map.left]
      @image = @map.image
      @zoom = [@frame.size.height.to_f/@image.height, @frame.size.height.to_f/@image.height]
    end
		def on_paint dc
=begin
		  # test gc
      gc = Wx::GraphicsContext.create dc
      gc.set_brush Wx::Brush.new(Wx::Colour.new(255,255,255,192))
			gc.set_pen Wx::Pen.new(Wx::NULL_PEN)
      mat = gc.create_matrix
      gc.set_transform mat 
      gc.translate 100,50
      gc.rotate -1
      gc.draw_ellipse 0,0,100,30
=end
      draw_landscape dc
      draw_vertical_tics dc
			draw_horizontal_tics dc
      FlightplanDrawer.new(THE_APP.flightplan_manager, self).draw dc
      draw_position_marker dc
#      @parent_frame.refresh false, nil
		end
    def draw_landscape dc
      dc.background = @back_brush
      dc.clear
			image_topleft = view_to_landscape [0,0]
      image_bottomright = view_to_landscape [@frame.size.width,@frame.size.height]
      image_topleft[0] = 0 if image_topleft[0]<0
      image_topleft[1] = 0 if image_topleft[1]<0
      image_bottomright[0] = @image.width if image_bottomright[0]>@image.width
      image_bottomright[1] = @image.height if image_bottomright[1]>@image.height
      memdc = Wx::MemoryDC.new
      image_width = image_bottomright[0] - image_topleft[0]
      image_height = image_bottomright[1] - image_topleft[1]
      image_dst_width = image_width*@zoom[0]
      image_dst_height = image_height*@zoom[1]
      subimage = @image.sub_image(Wx::Rect.new(image_topleft[0].to_i,image_topleft[1].to_i,image_width.to_i,image_height.to_i))
      subimage.rescale(image_dst_width.to_i,image_dst_height.to_i)
      memdc.select_object(Wx::Bitmap.new(subimage))
      image_pos = map_to_view(image_topleft)
      dc.blit(image_pos[0].to_i, image_pos[1].to_i, image_dst_width.to_i, image_dst_height.to_i, memdc, 0, 0);
    end
    def draw_position_marker dc
			dc.pen = ServoView.isOn('cic') ? @marker_pen_cic : @marker_pen
    	com = THE_APP.com(0)
    	pos_gps = [com[:latitude], com[:longitude], com[:altitude]]
    	unless pos_gps == [0,0,0]
	    	pos_landscape = @map.gps_to_landscape(pos_gps)
	    	pos = landscape_to_view(pos_landscape)
	    	pos.map!{|coord| coord.to_i}
	    	dc.draw_line pos[0], pos[1], pos[0], pos[1]
	    	
				#keep history
				itow_now = com[:itow]
				@history_holder.push :itow=>itow_now, :pos_gps=>pos_gps, :altitude=>com[:altitude]
				#draw history
				history = @history_holder.history
	      unless history.empty? then
	        prev_pos = nil
	        pts = []
	        history.each{|state|
	          pos_gps = state[:pos_gps]
	          altitude = state[:altitude]
	          itow = state[:itow]
	          pos = map_to_view(@map.gps_to_map(pos_gps))
	          pos = [pos[0].to_i,pos[1].to_i]
	          pts.push pos
#	          if prev_pos then
#	            dx = pos[0] - prev_pos[0]
#	            dy = pos[1] - prev_pos[1]
#	            if dx*dx + dy*dy > 4 then
#	            	dc.pen = @trajec_pen
#	              dc.draw_line(prev_pos[0], prev_pos[1], pos[0], pos[1])
#	              prev_pos = pos
#	            end
#	          else
#	            prev_pos = pos
#	          end
	        }
					dc.pen = @trajec_pen
          dc.draw_lines pts
	      end
    	end
    end
    def draw_vertical_tics dc
    	div = 50	# gap btw. tics
    	mdiv = 10	# gap btw. mtics
    	mtics_thresh = 4*div	# draw mtics when displayed range is narrower than this value
    	alt_max = @map.landscape_to_direction(view_to_landscape([0,0]))[1].to_i
			alt_min = @map.landscape_to_direction(view_to_landscape([0,@frame.size.height]))[1].to_i
			tic = (alt_min / div) * div
			while tic < alt_max
				if alt_max - alt_min < mtics_thresh
					# draw mtics
					mtic = tic + mdiv
					while mtic < tic + div
						mtic_view = landscape_to_view(@map.direction_to_landscape([0,mtic]))[1]
						dc.pen = @mtic_pen
						dc.draw_line 0, mtic_view, @frame.size.width, mtic_view
						mtic += mdiv
					end
				end
				tic_view = landscape_to_view(@map.direction_to_landscape([0,tic]))[1]
				dc.pen = @tic_pen
				dc.font = @tic_font
	      dc.text_foreground = @tic_text_fg
				dc.draw_line 0, tic_view, @frame.size.width, tic_view
				dc.draw_text tic.to_s, 0, tic_view
				tic += div
			end
    end
    def draw_horizontal_tics dc
    	div = 90	# gap btw. tics
    	mdiv = 30	# gap btw. mtics
    	mtics_thresh = 2*div	# draw mtics when displayed range is narrower than this value
    	bearing_max = @map.landscape_to_direction(view_to_landscape([@frame.size.width,0]))[0].to_i
			bearing_min = @map.landscape_to_direction(view_to_landscape([0,0]))[0].to_i
			tic = (bearing_min / div) * div
			while tic < bearing_max
				if bearing_max - bearing_min < mtics_thresh
					# draw mtics
					mtic = tic + mdiv
					while mtic < tic + div
						mtic_view = landscape_to_view(@map.direction_to_landscape([mtic,0]))[0]
						dc.pen = @mtic_pen
						dc.draw_line mtic_view, 0, mtic_view, @frame.size.height
						mtic += mdiv
					end
				end
				tic_view = landscape_to_view(@map.direction_to_landscape([tic,0]))[0]
				dc.pen = @tic_pen
				dc.font = @tic_font
	      dc.text_foreground = @tic_text_fg
				dc.draw_line tic_view, 0, tic_view, @frame.size.height
				dc.draw_text tic.to_s, tic_view, 0
				tic += div
			end
    end
    def draw_bearing dc
      margin = 10
      bearing_size = 20
      bearing_angle = 60
      parent_width = parent_size.width
      parent_height = parent_size.height
      pts = []
      x = -(parent_height/2 - margin)*Math.sin(@map.bearing/57.3) + parent_width/2
      y = (parent_height/2 - margin)*Math.cos(@map.bearing/57.3) + parent_height/2
      pts.push Wx::Point.new(x.to_i, y.to_i)
      x1 = x - bearing_size * Math.sin((@map.bearing + bearing_angle)/57.3)
      y1 = y + bearing_size * Math.cos((@map.bearing + bearing_angle)/57.3)
      pts.push Wx::Point.new(x1.to_i, y1.to_i)
      x2 = x - bearing_size * Math.sin((@map.bearing - bearing_angle)/57.3)
      y2 = y + bearing_size * Math.cos((@map.bearing - bearing_angle)/57.3)
      pts.push Wx::Point.new(x2.to_i, y2.to_i)
      pts.push pts[0]
      dc.pen = @bearing_pen
      dc.draw_lines pts
    end
    def on_left_down evt
      @prev_pos = evt.position
      #select waypoints
      if wp = FlightplanDrawer.new(@fpm, self).pos2waypoint([@prev_pos.x, @prev_pos.y]) then
        wp_index = @fpm.waypoint_index(wp)
        multi_select(evt, @selected_wp_index, wp_index)
      else
        @selected_wp_index.clear
        @wp_index_prev = nil
      end
      notify_listeners
    end
    def on_left_up evt
    	@dragging = false
			notify_listeners	# notify when bearing is reset
    end
		def on_right_up evt
    	@dragging = false
    end
    def on_motion evt
      pos = evt.position
      @prev_pos ||= Wx::Point.new(0,0)
      dx = pos.x - @prev_pos.x
      dy = pos.y - @prev_pos.y
      case
      when evt.left_is_down
        if wp = FlightplanDrawer.new(@fpm, self).pos2waypoint([@prev_pos.x, @prev_pos.y]) then
          #move waypoint
          @fpm.log_waypoint unless @dragging
          @dragging = true
          alt_new = @map.landscape_to_direction(view_to_landscape([pos.x, pos.y]))[1]
          alt_prev = @map.landscape_to_direction(view_to_landscape([@prev_pos.x, @prev_pos.y]))[1]
          alt_diff = alt_new - alt_prev
          @selected_wp_index.each{|i|
            wp = @fpm.waypoint_at(i)
            alt = wp.pos[2]
            pos_new = wp.pos[0..1] + [alt + alt_diff]
            @fpm.move_waypoint wp, pos_new
          }
        else
          @map.bearing -= dx
          @offset[0] += dx * @map.deg2pix.to_i
          @offset[1] += dy/@zoom[1]
          @frame.refresh false, nil
        end
      when evt.right_is_down
        @dragging = true
				@zoom[0] *= ZOOM_STEP**(dx.to_f/ZOOM_MOUSEMOVE_UNIT)
        @zoom[1] *= ZOOM_STEP**(dy.to_f/ZOOM_MOUSEMOVE_UNIT)
				@frame.refresh false, nil
      end
      @prev_pos = pos
    end
    def parent_size
      Wx::Size.new(@parent_frame.size.width,
        @parent_frame.size.height - @frame.size.height
      )
    end
    def multi_select evt, list, index
      if evt.shift_down
        list.clear unless evt.control_down
        if @prev_index > index
          @prev_index.downto(index){|i| list << i}
        else
          @prev_index.upto(index){|i| list << i}
        end if @prev_index
      elsif evt.control_down
        (list.include? index) ? (list.delete index) : (list << index)
      else
        unless list.include? index
          list.clear
          list << index
        end
      end
      list.uniq!
      list.sort!
      @prev_index = index
    end
	end
end