require 'gadget'
require 'landscape_view'

module Mv
  class Map
  	SEMI_MAJOR_AXIS = 6378137	# [m]; WGS-84
  	MAJOR_CIRCUM = SEMI_MAJOR_AXIS * 2 * Math::PI	# [m]
    def initialize args
      @image = args[:image]
      @north = args[:north]
      @south = args[:south]
      @east = args[:east]
      @west = args[:west]
    end
    attr_reader :image, :north, :south, :east, :west
    def gps_to_map pos
      return [
        (1.0 - (pos[1] - @east)/(@west - @east))*@image.width,
        (pos[0] - @north)/(@south - @north)*@image.height
      ]
    end
    def map_to_gps pos
      return [
        pos[1]/@image.height*(@south - @north) + @north,
        (1.0 - pos[0]/@image.width)*(@west - @east) + @east
      ]
    end
    def lat_to_dist lat
    	# distance from the equator
			return MAJOR_CIRCUM / 360.0 * lat
    end
  end
  class MapView
		include Gadget
    ZOOM_STEP = 1.05
    ZOOM_MOUSEMOVE_UNIT = 10
    CHILD_FRAME_HEIGHT = 150
		DEFAULT_WP_ALT = 100	# make 3d-wp with this alt unless otherwise specified
    #event ID
    PopMenu_SelectAllWP = 0
		PopMenu_ReverseWP = 1
		PopMenu_Set0thWP = 2
    PopMenu_DeleteWP = 3
		PopMenu_UndoWP = 4
    PopMenu_CopyPos = 100
		PopMenu_ShowTrajec = 101
		PopMenu_3D = 102
    PopMenu_SetLineTrack = 200
    PopMenu_SetGoTo = 201
    attr_reader :map, :selected_wp_index, :children_frames
    def initialize args
      @frame = BufferedControl.new(args)
      @fpm = THE_APP.flightplan_manager
      cf = THE_APP.config[:map_view] || {}
    	default_cf = {:is_3d=>false, :trajec_on=>false, :trajec_span=>60, :trajec_colored_span=>20}
    	ConfigReader.fill cf, default_cf
			@trajec_on = cf[:trajec_on]
    	trajec_span = cf[:trajec_span]
			@trajec_colored_span = cf[:trajec_colored_span]
			@is_3d = cf[:is_3d]
      @offset = [0,0]
      @marker_pen = Wx::Pen.new(Wx::Colour.new(255,0,0),4)
      @marker_pen_cic = Wx::Pen.new(Wx::Colour.new(0,255,0),4)
      @scalebar_pen = Wx::WHITE_PEN
      @scalebar_font = Wx::Font.new(10, Wx::FONTFAMILY_DEFAULT,
    		Wx::FONTSTYLE_NORMAL, Wx::FONTWEIGHT_NORMAL)
  		@scalebar_text_fg = Wx::WHITE
      @back_brush = Wx::Brush.new(Wx::Colour.new(64,64,64))
      @prev_pos = Wx::Point.new(0,0)
			@history_holder = HistoryHolder.new :tkey=>:itow,
      	:min_interval=>1, :span=>trajec_span
      @selected_wp_index = []
			@scalebar_pts = [[10+5,10], [10,10], [10,10+100], [10+5,10+100]]
      load_map nil
      @frame.evt_paint{
        on_paint @frame.memdc
        @frame.update
      }
      @frame.evt_left_down{|evt|on_left_down evt}
			@frame.evt_left_up{|evt| on_left_up evt}
      @frame.evt_left_dclick{|evt|on_left_double_click evt}
      @frame.evt_right_down{|evt|on_right_down evt}
			@frame.evt_right_up{|evt| on_right_up evt}
      @frame.evt_motion{|evt|on_motion evt}
      @frame.evt_mousewheel{|evt|on_mousewheel evt}
    	@frame.evt_menu(PopMenu_SelectAllWP){
				num_wp = @fpm.num_waypoint
				if @selected_wp_index.length < num_wp
					num_wp.times{|i| @selected_wp_index << i}
				else
					@selected_wp_index.clear
				end
				@frame.refresh false,nil
    	}
			@frame.evt_menu(PopMenu_ReverseWP){
				@fpm.log_waypoint
				@fpm.reverse_waypoint
			}
			@frame.evt_menu(PopMenu_Set0thWP){
				@fpm.log_waypoint
				@fpm.set_0th_waypoint_at @selected_wp_index[0]
				@selected_wp_index.clear
			}
			@frame.evt_menu(PopMenu_DeleteWP){
				unless @selected_wp_index.empty?
					@fpm.log_waypoint
					@selected_wp_index.reverse.each{|i|
						@fpm.remove_waypoint_at i
					}
					@selected_wp_index.clear
				end
			}
			@frame.evt_menu(PopMenu_UndoWP){
				@fpm.undo_waypoint
			}
      @frame.evt_menu(PopMenu_CopyPos){
        posIn2clipboard @prev_pos
      }
			@frame.evt_menu(PopMenu_ShowTrajec){
				@trajec_on = if @pop_menu.is_checked(PopMenu_ShowTrajec)
        	true
        else
        	false
        end
      }
			@frame.evt_menu(PopMenu_3D){
				if @pop_menu.is_checked(PopMenu_3D)
					@fpm.log_waypoint
					@fpm.num_waypoint.times do |idx|
						@fpm.convert_to_3dwaypoint_at idx, DEFAULT_WP_ALT
					end
					@is_3d = true
        else
					if Wx::message_box("Remove all the altitude data from current flightplan?",
						"Confirmation", Wx::YES_NO)==Wx::YES then
						@fpm.log_waypoint
						@fpm.num_waypoint.times do |idx|
							@fpm.convert_to_2dwaypoint_at idx
						end
						@is_3d = false
					else
						@pop_menu.check(PopMenu_3D, @is_3d)
					end
        end
      }
      @frame.evt_menu(PopMenu_SetLineTrack){
        modifySelectedWP true
      }
      @frame.evt_menu(PopMenu_SetGoTo){
        modifySelectedWP false
      }
#		  THE_APP.properties.add_listener(:config){|args| update args}	#refresh if map is changed
      THE_APP.com(0).add_property_listener(:latitude,:longitude,:altitude){
        @frame.refresh false, nil
      }
      THE_APP.flightplan_manager.add_listener{
        @frame.refresh false, nil
      }
      @humble_pen = Wx::Pen.new(Wx::Colour.new(128,128,128,64),2)
      @hsv_pen = []
      360.times{|i|
        r = g = b = 0
        case i/60
        when 0
          r = 255
          g = i*255/60
        when 1
          r = 255 - (i - 60)*255/60
          g = 255
        when 2
          g = 255
          b = (i - 120)*255/60
        when 3
          g = 255 - (i  - 180)*255/60
          b = 255
        when 4
          b = 255
          r = (i - 240)*255/60
        when 5
          r = 255
          b = (i - 300)*255/60
        end
        @hsv_pen.push Wx::Pen.new(Wx::Colour.new(r,g,b),2)
      }
#     short-cut key table, which doesn't work once map_view goes out of focus
#			@frame.accelerator_table = Wx::AcceleratorTable[
#  			[ Wx::MOD_CONTROL, ?a,           PopMenu_SelectAllWP ],
#  			[ Wx::MOD_NONE,    Wx::K_DELETE, PopMenu_DeleteWP ],
#		    [ Wx::MOD_CONTROL, ?z,           PopMenu_UndoWP ],
#        [ Wx::MOD_CONTROL, ?r,           PopMenu_ReverseWP ],
#				[ Wx::MOD_CONTROL, ?s,           PopMenu_Set0thWP ],
#     ]
			@pop_menu = Wx::Menu.new
  		@pop_menu.append(PopMenu_SelectAllWP, "Select All(&A)")
			@pop_menu.append(PopMenu_ReverseWP, "Reverse(&R)")
			@pop_menu.append(PopMenu_Set0thWP, "Set as 0th(&0)")
			@pop_menu.append(PopMenu_DeleteWP, "Delete(&D)")
			@pop_menu.append(PopMenu_UndoWP, "Undo(&U)")
      @pop_menu.append(PopMenu_SetLineTrack, "Set LineTrack(&L)")
      @pop_menu.append(PopMenu_SetGoTo, "Set GoTo(&G)")
			@pop_menu.append_separator
			@pop_menu.append(PopMenu_CopyPos, "Copy Pos(&P)")
			@pop_menu.append_separator
			@pop_menu.append_check_item(PopMenu_ShowTrajec, "Show Trajectory(&T)")
			@pop_menu.append_check_item(PopMenu_3D, "Create/Set WP as 3D(&3)")
			@pop_menu.check(PopMenu_ShowTrajec, @trajec_on)
			@pop_menu.check(PopMenu_3D, @is_3d)
    end
    def map_to_view pos
      return [
        (pos[0] - @image.width/2 + @offset[0])*@zoom + @frame.size.width/2,
        (pos[1] - @image.height/2 + @offset[1])*@zoom + @frame.size.height/2
      ]
    end
    def view_to_map pos
      return [
        (pos[0] - @frame.size.width/2)/@zoom - @offset[0] + @image.width/2,
        (pos[1] - @frame.size.height/2)/@zoom - @offset[1] + @image.height/2
      ]
    end
    def update args
      load_map nil
      @frame.refresh false, nil
    end
    def show_children args = nil
      # make landscape_view
      parent_size = @frame.size
      child_size = Wx::Size.new(parent_size.width, CHILD_FRAME_HEIGHT)
			child_pos = Wx::Point.new(0, parent_size.height - child_size.height)
      @landscape_view = LandscapeView.new :parent=>@frame, :map_view=>self, 
      	:pos=>child_pos, :size=>child_size, :style=>Wx::NO_BORDER
    	@landscape_view.add_listener{@frame.refresh false, nil}
    	(@children_frames||={})[:landscape_view] = @landscape_view.frame
    end
    def destroy_children args = nil
			@landscape_view = nil
			@children_frames.clear
    end

    private
    def load_map filename
      @map = THE_APP.config[:map]
      @north_east = [@map.north, @map.east]
      @south_west = [@map.south, @map.west]
      @image = @map.image

      @zoom = [@frame.size.width.to_f/@image.width,@frame.size.height.to_f/@image.height].min
    end
    def on_mousewheel evt
      r = evt.wheel_rotation
      case
      when r>0
        @zoom *= ZOOM_STEP
      when r<0
        @zoom /= ZOOM_STEP
      end
      on_scale_changed
      @frame.refresh false,nil
    end
    def on_left_double_click evt
      pos = [evt.position.x, evt.position.y]
      if wp = FlightplanDrawer.new(@fpm, self).pos2waypoint(pos) then
				@fpm.log_waypoint
    		@selected_wp_index.reverse.each{|i|
    			@fpm.remove_waypoint_at i
    		}
				@selected_wp_index.clear
      elsif wp_pair = FlightplanDrawer.new(@fpm, self).pos2waypoint_pair(pos) then
				@fpm.log_waypoint
        gps_pos = @map.map_to_gps(view_to_map(pos))
    		if @is_3d then gps_pos += [DEFAULT_WP_ALT] end
        insert_index = @fpm.waypoint_index(wp_pair[0]) + 1
        @fpm.insert_waypoint_at(Waypoint.new(gps_pos, false), insert_index)
        THE_APP.debug_message "insert_wp: " + gps_pos.join(', ')
      else
				@fpm.log_waypoint
        gps_pos = @map.map_to_gps(view_to_map(pos))
				if @is_3d then gps_pos += [DEFAULT_WP_ALT] end
        @fpm.add_waypoint Waypoint.new(gps_pos, false)
        THE_APP.debug_message "add_wp: " + gps_pos.join(', ')
      end
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
      @frame.refresh false,nil
    end
    def on_left_up evt
    	@dragging = false
    end
    def on_right_down evt
      @prev_pos = evt.position
    end
		def on_right_up evt
      @prev_pos = evt.position
			unless @dragging
				pos = [evt.position.x, evt.position.y]
				if wp = FlightplanDrawer.new(@fpm, self).pos2waypoint(pos) then
					wp_index = @fpm.waypoint_index wp
					multi_select(evt, @selected_wp_index, wp_index)
					@frame.refresh false,nil
				end
				is_selected = @selected_wp_index.empty? ? false : true
				does_exist = @fpm.num_waypoint > 0 ? true : false
				is_selected_one = @selected_wp_index.length == 1 ? true : false
				@pop_menu.enable(PopMenu_DeleteWP, is_selected)
				@pop_menu.enable(PopMenu_ReverseWP, does_exist)
				@pop_menu.enable(PopMenu_Set0thWP, is_selected_one)
        @pop_menu.enable(PopMenu_SetLineTrack, is_selected)
        @pop_menu.enable(PopMenu_SetGoTo, is_selected)
	  		@frame.popup_menu(@pop_menu)
			end
			@dragging = false
		end
    def on_motion evt
      pos = evt.position
      dx = pos.x - @prev_pos.x
      dy = pos.y - @prev_pos.y
      case
      when evt.left_is_down
        if wp = FlightplanDrawer.new(@fpm, self).pos2waypoint([@prev_pos.x, @prev_pos.y]) then
        	#move waypoint
        	@fpm.log_waypoint unless @dragging
					@dragging = true
      		gps_pos = @map.map_to_gps(view_to_map([pos.x, pos.y]))
					gps_pos_prev = @map.map_to_gps(view_to_map([@prev_pos.x, @prev_pos.y]))
					gps_pos_diff = [gps_pos[0] - gps_pos_prev[0], gps_pos[1] - gps_pos_prev[1]]
					@selected_wp_index.each{|i|
      			wp = @fpm.waypoint_at(i)
      			gps_pos = [wp.pos[0] + gps_pos_diff[0], wp.pos[1] + gps_pos_diff[1]]
      			gps_pos += [wp.pos[2]] if wp.pos[2]
						@fpm.move_waypoint wp, gps_pos
			    }
        else
          @offset[0] += dx/@zoom
          @offset[1] += dy/@zoom
          @frame.refresh false,nil
        end
      when evt.right_is_down
    		@dragging = true
        @zoom *= ZOOM_STEP**(dy.to_f/ZOOM_MOUSEMOVE_UNIT)
				on_scale_changed
        @frame.refresh false,nil
      end
      @prev_pos = pos
    end
    def on_scale_changed
    	# calculate geographical length of scale bar
      lat1 = @map.map_to_gps(view_to_map(@scalebar_pts[1]))[0]
			lat2 = @map.map_to_gps(view_to_map(@scalebar_pts[2]))[0]
			@scalebar_dist = (@map.lat_to_dist(lat1) - @map.lat_to_dist(lat2)).to_i
    end
    def on_paint dc
      dc.background = @back_brush
      dc.clear
      image_topleft = view_to_map [0,0]
      image_bottomright = view_to_map [@frame.size.width,@frame.size.height]
      image_topleft[0] = 0 if image_topleft[0]<0
      image_topleft[1] = 0 if image_topleft[1]<0
      image_bottomright[0] = @image.width if image_bottomright[0]>@image.width
      image_bottomright[1] = @image.height if image_bottomright[1]>@image.height
      memdc = Wx::MemoryDC.new
      image_width = image_bottomright[0] - image_topleft[0]
      image_height = image_bottomright[1] - image_topleft[1]
      image_dst_width = image_width*@zoom
      image_dst_height = image_height*@zoom
      subimage = @image.sub_image(Wx::Rect.new(image_topleft[0].to_i,image_topleft[1].to_i,image_width.to_i,image_height.to_i))
      subimage.rescale(image_dst_width.to_i,image_dst_height.to_i)
      memdc.select_object(Wx::Bitmap.new(subimage))
      image_pos = map_to_view(image_topleft)
			dc.blit(image_pos[0].to_i, image_pos[1].to_i, image_dst_width.to_i, image_dst_height.to_i, memdc, 0, 0);
      
      #draw waypoints
      FlightplanDrawer.new(@fpm, self).draw dc
      
      #draw scale bar
			dc.pen = @scalebar_pen
			dc.font = @scalebar_font
			dc.text_foreground = @scalebar_text_fg
      dc.draw_lines @scalebar_pts
      on_scale_changed unless @scalebar_dist
      dc.draw_text @scalebar_dist.to_s + 'm', *@scalebar_pts[0]
      
      com = THE_APP.com(0)
      pos_cur_map = @map.gps_to_map([com[:latitude], com[:longitude]])
      pos_cur = map_to_view(pos_cur_map)
      
      if @trajec_on
				#keep history
				history = com.history
				itow_now = com[:itow]
				@history_holder.push :itow=>itow_now, :pos_map=>pos_cur_map, :altitude=>com[:altitude]
				#draw history
				history = @history_holder.history
	      unless history.empty? then
	        prev_pos = nil
	        history.each{|state|
	          pos_map = state[:pos_map]
	          altitude = state[:altitude]
	          itow = state[:itow]
	          pos = map_to_view(pos_map)
	          pos = [pos[0].to_i,pos[1].to_i]
	          if prev_pos then
	            dx = pos[0] - prev_pos[0]
	            dy = pos[1] - prev_pos[1]
	            if dx*dx + dy*dy > 4 then
	              if itow > itow_now - @trajec_colored_span then
	                i_pen = [[altitude/300*359,359].min,0].max
	                dc.pen = @hsv_pen[i_pen]
	              else
	                dc.pen = @humble_pen
	              end
	              dc.draw_line(prev_pos[0], prev_pos[1], pos[0], pos[1])
	              prev_pos = pos
	            end
	          else
	            prev_pos = pos
	          end
	        }
	      end
      end
      
      #draw position marker
      marker_size = 16
      posx = pos_cur[0].to_i
      posy = pos_cur[1].to_i

      dir = com[:heading]/180.0*Math::PI
      dc.pen = ServoView.isOn('cic') ? @marker_pen_cic : @marker_pen
      poss = [
        [posx + marker_size*Math.sin(dir), posy - marker_size*Math.cos(dir)],
        [posx + marker_size*Math.sin(dir + Math::PI*2/3), posy - marker_size*Math.cos(dir + Math::PI*2/3)],
        [posx + marker_size*Math.sin(dir - Math::PI*2/3), posy - marker_size*Math.cos(dir - Math::PI*2/3)]
      ]
      dc.draw_line(poss[0][0].to_i,poss[0][1].to_i,poss[1][0].to_i,poss[1][1].to_i);
      dc.draw_line(poss[0][0].to_i,poss[0][1].to_i,poss[2][0].to_i,poss[2][1].to_i);
      dc.draw_line(posx, posy, posx, posy)	# dot at exact pos
      
      #draw from landscape_view
      @landscape_view.draw_ext dc if @landscape_view
    end
    
    private
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
    def posIn2clipboard pt
      pos = [pt.x, pt.y]
      gps_pos = @map.map_to_gps(view_to_map(pos))
      gps_pos_str = "#{gps_pos[0]},#{gps_pos[1]}"
      Wx::Clipboard.open{|clip|
        clip.data = Wx::TextDataObject.new(gps_pos_str)
      }
    end
    def modifySelectedWP lineTrack
      @selected_wp_index.each do |idx|
        (@fpm.waypoint_at idx).set_lineTrack lineTrack
      end
      @frame.refresh false, nil
    end
  end
end