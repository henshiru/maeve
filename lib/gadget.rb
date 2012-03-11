module Mv
  class Control < Wx::Control
    def initialize args
      parent = args[:parent]
      id = args[:id] || -1
      pos = args[:pos] || [-1,-1]
      size = args[:size] || [-1,-1]
      style = args[:style] || 0
      validator = args[:validator] || Wx::Validator.new()
      super(parent,id,pos,size,style,validator)
    end
  end
  class BufferedControl < Control
    attr_reader :memdc
    def initialize args
      super args
      init_membitmap
      evt_size{}
      evt_erase_background(){|evt|}
    end
    def update
      paint{|dc|
        dc.blit(0,0,size.width,size.height,memdc,0,0)
      }
    end
    def evt_size
      super{|evt|
        update_membitmap
        yield evt
        refresh false, nil
      }
    end
    private
    def init_membitmap
      @memdc = Wx::MemoryDC.new
      @membitmap = Wx::Bitmap.new
      update_membitmap
    end
    def update_membitmap
      @membitmap.create(size.width,size.height)
      @memdc.select_object(@membitmap)
    end
  end
  module Gadget
    attr_reader :frame
    def findControl name
      Wx::Window.find_window_by_id(Wx::xrcid(name), self.frame)
    end
  end
  module Dialog
    attr_reader :form
    def show_modal
      form.show_modal
    end
    def show
      form.show
    end
    def hide
      if form.is_modal then
        form.end_modal
      else
        form.show false
      end
    end
    def findDialog name
      dialog = THE_APP.xrc.load_dialog(THE_APP.frame, name)
    end
    def findControl name
      Wx::Window.find_window_by_id(Wx::xrcid(name), self.form)
    end
  end
  class HistoryHolder
#  	description:
#  		Class which holds data history
#  	necessary keys:
#  		:t (or :tkey)
#  	note:
#  		-Data structure must be an array of hashes, with each hash representing a data point.
#  		-Omit :min_interval to make interval = 0.
#  		-Omit :span to retain all the data from the start.
  	attr_reader :history
    def initialize args
      @history = []
      @tkey = args[:tkey] || :t
      @min_interval = args[:min_interval]
      @span = args[:span] # [s]
    end
    def push data
    	if data[@tkey]
	      # push
	      if @min_interval
	        eps = 1
	        interval = @history.empty? ? @min_interval + eps : data[@tkey] - @history[-1][@tkey]
	        if interval < 0	# on reset or rewind of time
	        	unless data[@tkey] < 1	# ignore invalid data
	        		until @history.empty? || @history[-1][@tkey] < data[@tkey] do @history.pop end
	       		end
	        end
	        @history.push data if interval >= @min_interval
	      else
	        @history.push data
	      end
	      # remove expired data
	      if @span && !@history.empty?
	        until @history.empty? || @history[-1][@tkey] - @history[0][@tkey] < @span do @history.shift end
	      end
      else
				raise RuntimeError, "HistoryHoder: data point has no time info."
      end
    end
    def clear
    	@history.clear
    end
  end
  class GraphDrawer2D
#  	description:
#  		Class which draws a graph from an array of 2D data points
#  	note:
#  		Data structure must be an array of hashes, with each hash representing a data point.
#  	notations:
#  		(u,v): values to show on horizontal/vertical axis respectively
#  		(x,y): frame coordinates; x in [0,width], y in [0,height]
  	def initialize args
  		@data = args[:data]
  		@ukey, @ulabel, @uunit = args[:uvalue]
			@vkey, @vlabel, @vunit = args[:vvalue] 
      @umin, @udiv, @umax = args[:urange]
      @vmin, @vdiv, @vmax = args[:vrange]
			@tics_on = args[:tics_on] || true
      @label_on = args[:label_on] || true
      @xinv = args[:xinv] || false
			@yinv = args[:yinv] || false
      @line_pen = args[:line_pen] || Wx::WHITE_PEN
      @tic_pen = args[:tic_pen] || Wx::Pen.new(Wx::Colour.new(128,128,128))
      @font = args[:font] || Wx::Font.new(9, Wx::FONTFAMILY_DEFAULT,
        Wx::FONTSTYLE_NORMAL, Wx::FONTWEIGHT_NORMAL)
      @text_fg = args[:text_fg] || Wx::WHITE
  	end
  	def draw dc, width, height
			draw_tics dc, width, height if @tics_on
      draw_data dc, width, height if @data.size > 1
      draw_label dc, width, height if @label_on
  	end
  	def set_data data
  		@data = data
  	end
  	
  	private
		def draw_data dc, width, height
      prev_pos = nil
      @data.each do |datum|
        x = val2view_x datum[@ukey], width
        y = val2view_y datum[@vkey], height
        pos = [x,y]
        dc.pen = @line_pen
       	dc.draw_line(prev_pos[0], prev_pos[1], pos[0], pos[1]) if prev_pos
				prev_pos = pos
      end
    end
  	def draw_tics dc, width, height
  		unless width == @width && height == @height
  			calc_tics_x width
				calc_tics_y height
				@width, @height = width, height
  		end
  		dc.pen = @tic_pen
			@xtics.each do |tic| dc.draw_line(tic, 0, tic, height) end
			@ytics.each do |tic| dc.draw_line(0, tic, width, tic) end
  	end
  	def draw_label dc, width, height
      dc.font = @font
      dc.text_foreground = @text_fg
      dc.draw_text @ulabel+' '+[@umin,@udiv,@umax].join(':')+@uunit+(@xinv?':inv':''), 
        20, height-20
			dc.draw_rotated_text @vlabel+' '+[@vmin,@vdiv,@vmax].join(':')+@vunit+(@yinv?':inv':''), 
        0, height-20, 90
  	end
  	def calc_tics_x width
			xdivnum = (@umax - @umin) / @udiv + 1
      @xtics = Array.new xdivnum
			dxtic = (val2view_x(@udiv, width) - val2view_x(0, width)).abs
			xdivnum.times do |i| 
				@xtics[i] = @xinv ? width - i * dxtic : i * dxtic
			end
  	end
		def calc_tics_y height
      ydivnum = (@vmax - @vmin) / @vdiv + 1
      @ytics = Array.new ydivnum
      dytic = (val2view_y(@vdiv, height) - val2view_y(0, height)).abs
			ydivnum.times do |i| 
				@ytics[i] = @yinv? i * dytic : height - i * dytic 
			end
		end
    def val2view_x u, width
#    	get client coordinate x from value u
      x = @xinv ? 
				width * (@umax - u) / (@umax - @umin):
      	width * u / (@umax - @umin)
      x.to_i
    end
    def val2view_y v, height
    	y = @yinv? 
				height * v / (@vmax - @vmin):
      	height * (@vmax - v) / (@vmax - @vmin)
      y.to_i
    end
  end
  class HistoryDrawer < GraphDrawer2D
#  	description:
#  		GraphDrawer2D for history graph drawing
#  	note:
#  		Time can be either absolute(like UTC) or relative(like so many secs ago)
    private
    def val2view_x t, width
      t_end = @data[-1][@ukey]
      t_begin = t_end - (@umax - @umin)
      x = width + width * (t - t_end) / (@umax - @umin)
      x.to_i
    end
  end
end