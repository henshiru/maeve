module Mv
  class Waypoint
    attr_reader :pos;
    def initialize pos, isLineTrack = false
      @pos = pos
      @isLineTrack = isLineTrack
    end
    def lineTrack?
      @isLineTrack
    end    
    def dim
    	pos.size
    end
    def set_pos pos  
      @pos = pos
    end
    def set_lineTrack isLineTrack
#    	args: true|false
      @isLineTrack = isLineTrack
    end
  end
  class FlightplanManager
    class FlightplanReader
      def initialize filename
        @commands = []
        eval(File.new(filename.tosjis).read, binding)#FIXME windows specific
      end
      attr_reader :commands
      def self.read filename
        reader = (self.new filename)
        reader.commands
      end
      def waypoint *args
#      	args
#      		-2D version: lat, lng, isLineTrack
#					-3D version: lat, lng, alt, isLineTrack
      	if args.size.between? 3, 4
					@commands.push Waypoint.new(args[0..-2], args[-1])
      	else
					raise RuntimeError,"invalid wp dimension"
      	end
      end
    end
    def initialize
      @commands = []
			@commands_prev = []
      @listeners = []
    end
    def num_waypoint
      @commands.length
    end
    def add_waypoint wp
      @commands.push wp
      check_dimension
      notify_listeners
    end
    def insert_waypoint_at wp, index
      @commands.insert(index, wp)
			check_dimension
      notify_listeners
    end
    def remove_waypoint wp
      @commands.delete wp
      notify_listeners
    end
    def remove_waypoint_at index
      @commands.delete_at index
			check_dimension
      notify_listeners
    end
		def move_waypoint wp, pos_new
	    wp.set_pos pos_new
			notify_listeners
	  end
	  def reverse_waypoint
	  	@commands.reverse!.unshift(@commands.pop)	#ring_unshift
			notify_listeners
	  end
	  def set_0th_waypoint wp
	  	index = waypoint_index wp
	  	index.times do |i| @commands.push(@commands.shift) end if index
			notify_listeners 		
	  end
		def set_0th_waypoint_at index
			index.times do |i| @commands.push(@commands.shift) end if index
			notify_listeners 		
	  end
		def convert_to_2dwaypoint_at index
	  	@commands[index].set_pos @commands[index].pos[0..1]
			notify_listeners
	  end
	  def convert_to_3dwaypoint_at index, altitude
	  	@commands[index].set_pos @commands[index].pos + [altitude]
			notify_listeners
	  end
    def waypoint_at index
      @commands[index]
    end
    def waypoint_index wp
      @commands.index wp
    end
    def log_waypoint
			@commands_prev = Marshal.load(Marshal.dump(@commands))	#deep copy
    end
    def undo_waypoint
    	@commands, @commands_prev = @commands_prev.dup, @commands.dup
			notify_listeners
    end
    def check_dimension
    	unless @commands.empty?
				dim_1st = @commands[0].dim
	    	@commands.each do |wp|
	    		unless dim_1st == wp.dim
	    			unless @warned_dim
							Wx::message_box("WP dimensions are not consistent!", "Warning")
							@warned_dim = true
	    			end
						return nil
	    		end
	    	end
	    	if @warned_dim
					Wx::message_box("WPs with inconsistent dimension were removed.", "Information")
					@warned_dim = false
	    	end
	    	return dim_1st
    	end
    end
    def receive_waypoint dat, format
    	dat.each do |str|
    		val = str.unpack(format)
        cLineTrack = (val[-1] == 0) ? false : true
				add_waypoint Waypoint.new(val[0..-2], cLineTrack)
    	end
			THE_APP.debug_message "flightplan was downlinked."
    	notify_listeners
    end   	
    def load_from_file filename
      unless @commands.empty? then
        unless Wx::message_box("Clear current flightplan and load from file?", "Confirmation", Wx::YES_NO)==Wx::YES then
          return
        end
      end
      begin
      	commands = FlightplanReader.read filename
			rescue => evar
        Wx::message_box evar.inspect, "Error"
      	return
      end
      @commands.clear
      commands.each{|command|
        @commands.push command
      }
      notify_listeners
    end
    def save_to_file filename
      filename = filename.tosjis#FIXME windows specific
      if File.exist?(filename) then
        unless Wx::message_box("File already exists, overwrite?", "Confirmation", Wx::YES_NO)==Wx::YES then
          return
        end
      end
      File.open(filename, "w"){|f|
        @commands.each{|command|
          line = case(command)
          when Waypoint
            pos = command.pos
            lineTrack = command.lineTrack?
#            "waypoint #{pos[0]}, #{pos[1]}, #{lineTrack}"	#2D specific
						"waypoint #{pos.join(', ')}, #{lineTrack}"
          else
            raise RuntimeError, "invalid type command"
          end
          f.puts line
        }
      }
    end
    def serialize
      dat=""
      @commands.each{|command|
        key, val = case command
        when Waypoint
          cLineTrack = (command.lineTrack?)?1:0
          key, format = case command.pos.size
          when 2 then ['waypoint', 'ddc']
					when 3 then ['waypoint3d', 'dddc']
          else raise RuntimeError,"invalid wp dimension"
          end
					[key, (command.pos + [cLineTrack]).pack(format)]
#        	["waypoint", [command.pos[0], command.pos[1], cLineTrack].pack('ddc')]	#2D specific
        else
          raise RuntimeError,"invalid type command"
        end
        dat += [key.length + 1].pack('C') + key + [0].pack('C')
        dat += [val.length].pack('C') + val
        
				THE_APP.debug_message "serializing 3D wp" if key == 'waypoint3d'
      }
      dat
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
  end
  class FlightplanDrawer
    WP_SIZE = 16
    LABEL_POS = WP_SIZE - 15
    def initialize plan, view
      @plan = plan
      @view =view
      @wp_brush = Wx::Brush.new(Wx::Colour.new(255, 255, 255))
      @wp_brush_highlight = Wx::Brush.new(Wx::Colour.new(0, 0, 255))
      @line_pen = Wx::Pen.new(Wx::Colour.new(255, 255, 128), 4)
      @wp_pen = Wx::Pen.new(Wx::Colour.new(128, 128, 255), 4)
      @wp_font = Wx::Font.new(14,Wx::FONTFAMILY_DEFAULT,Wx::FONTSTYLE_NORMAL,Wx::FONTWEIGHT_NORMAL)
      @wp_text_color = Wx::Colour.new(0, 0, 0)
			@wp_text_color_highlight = Wx::Colour.new(255, 255, 255)
      @label_font = Wx::Font.new(14,Wx::FONTFAMILY_DEFAULT,Wx::FONTSTYLE_NORMAL,Wx::FONTWEIGHT_BOLD)
			@label_text_color = Wx::Colour.new(255, 128, 128)
    end
    def draw dc
      #n_pts = @plan.numWaypoint
      pts = []
      ptsLabel = []
#			ptsShadow = []
      #n_pts.times{|i|
      #  wp = @plan.waypointAtIndex i
      each_waypoint{|wp|
        map = @view.map
        if pt = @view.map_to_view(map.gps_to_map(wp.pos))
          x = pt[0].to_i
          y = pt[1].to_i
          pts.push Wx::Point.new(x, y)
          ptsLabel.push Wx::Point.new(x + LABEL_POS, y + LABEL_POS) if wp.lineTrack?
#  				ptsShadow.push Wx::Point.new(x - WP_SIZE/2, y - WP_SIZE) if wp.dim > 2
        end
      }
      
=begin
    	# draw 3D-wp shadow
      unless ptsShadow.empty?
	      gc = Wx::GraphicsContext.create dc
	      gc.set_brush Wx::Brush.new(Wx::Colour.new(0,0,0,128))
				gc.set_pen Wx::Pen.new(Wx::NULL_PEN)
				ptsShadow.each{|pt|
	        mat = gc.create_matrix
	        gc.set_transform mat 
	        gc.translate pt.x, pt.y
	        gc.rotate -1
	        gc.draw_ellipse 0, 0, WP_SIZE*2.5, WP_SIZE*2
				}
    	end
=end

			# draw linkage
      dc.pen = @line_pen
      dc.draw_lines(pts + [pts.first]) unless pts.empty?
      # draw wp circle
      dc.font = @wp_font
      dc.pen = @wp_pen
      pts.each_with_index{|pt, i|
				dc.brush, dc.text_foreground = if @view.selected_wp_index.include? i
					[@wp_brush_highlight, @wp_text_color_highlight]
				else
					[@wp_brush, @wp_text_color]
				end
        dc.draw_circle pt, WP_SIZE
        label = i.to_s
        t_ext = dc.text_extent label
        dc.draw_text label, (pt.x - t_ext[0]/2).to_i, (pt.y - t_ext[1]/2).to_i
      }
      # draw lineTrack tag
      dc.font = @label_font
      dc.text_foreground = @label_text_color
      ptsLabel.each{|pt|
        dc.draw_text('L', pt.x, pt.y)
      }
    end
    
    def pos2waypoint pos
      map = @view.map
      each_waypoint{|wp|
        pos_wp = @view.map_to_view(map.gps_to_map(wp.pos))
        dx = pos[0] - pos_wp[0]
        dy = pos[1] - pos_wp[1]
        r2 = dx*dx + dy*dy
        if r2 < WP_SIZE*WP_SIZE then
          return wp
        end
      }
      return nil
    end
    def pos2waypoint_pair pos
    #return a neighboring WP pair if pos is on the linkage between them
      d2_max = 100
      map = @view.map
      each_waypoint_pair{|wp_pair|
        pos_wp0 = @view.map_to_view(map.gps_to_map(wp_pair[0].pos))
        pos_wp1 = @view.map_to_view(map.gps_to_map(wp_pair[1].pos))
        if (pos_wp0[0] <=> pos[0]) * (pos[0] <=> pos_wp1[0]) > 0 || \
        	(pos_wp0[1] <=> pos[1]) * (pos[1] <=> pos_wp1[1]) > 0
          dx = pos_wp1[0] - pos_wp0[0]
          dy = pos_wp1[1] - pos_wp0[1]
          d2 = ((pos[0] - pos_wp0[0])*dy - (pos[1] - pos_wp0[1])*dx)**2 / (dx*dx + dy*dy)
        		#(dist between pos and linkage)^2
          if d2 < d2_max then
            return wp_pair
          end
        end
      }
      return nil
    end
    private
    def each_waypoint
      @plan.num_waypoint.times{|i|
        yield @plan.waypoint_at(i)
      }
    end
    def each_waypoint_pair
      @plan.num_waypoint.times{|i|
        if i < @plan.num_waypoint - 1
          yield [@plan.waypoint_at(i), @plan.waypoint_at(i+1)]
        else
          yield [@plan.waypoint_at(i), @plan.waypoint_at(0)]
        end
      }
    end
  end
end