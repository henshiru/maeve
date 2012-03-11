# To change this template, choose Tools | Templates
# and open the template in the editor.

module Mv
  class ConfigReader
    def initialize filename
      @values = {}
      eval(File.new(filename).read, binding)
    end
    attr_reader :values
    def self.read filename
      (self.new filename).values
    end
	  def self.check config, neededEntries
	  	SettingReader.check config, neededEntries
	  end
		def self.fill user_config, default_config
	  	SettingReader.fill user_config, default_config
	  end
    def map filename
      @values[:map] = MapReader.read filename
    end
    def landscape filename
      @values[:landscape] = LandscapeReader.read filename
    end
    def settings filename
			SettingReader.read(filename).each do |key,val|
				@values[key] = val
			end
    end
    def aircraft filename
    	@values[:aircraft] = AircraftReader.read filename
    end
  end
  class MapReader
    def initialize filename
      current_directory = Dir.getwd
      Dir.chdir File.dirname(filename)
      @offset = [0, 0]
      eval(File.new(filename).read, binding)
      Dir.chdir current_directory
    end
    def map
      north = @north + @offset[0]
      south = @south + @offset[0]
      east = @east + @offset[1]
      west = @west + @offset[1]
      Map.new :north=>north, :south=>south, :east=>east, :west=>west, :image=>@image
    end
    def self.read filename
      (self.new filename).map
    end
    def image filename
      @image = Wx::Image.new(filename)
    end
    def north x
      @north = x
    end
    def east x
      @east = x
    end
    def south x
      @south = x
    end
    def west x
      @west = x
    end
    def offset lat, lng
      @offset = [lat, lng]
    end
  end
  class LandscapeReader < MapReader
    def landscape
      north = @north + @offset[0]
      south = @south + @offset[0]
      east = @east + @offset[1]
      west = @west + @offset[1]
      Landscape.new :top=>north, :bottom=>south, :right=>east, :left=>west, :image=>@image
    end
    alias top north
    alias right east
    alias bottom south
    alias left west
    alias map landscape
  end
  class SettingReader
    def initialize filename 
			@settings = eval(File.new(filename).read, binding)	# for setting.rb
#			@settings = YAML.load(str = File.read(filename)) # for setting.yaml
#			@@settings_ini = Marshal.load Marshal.dump(@settings)
#			regexp = /\s*#\s*<!--(.*?)#\s*-->/m
#			@@comment = (str =~ regexp) ? $& + "\n\n" : ""
#    	@settings = default_settings.merge @settings
    end
    def self.read filename
      (self.new filename).values
    end
    def values
      @settings
    end
	  def self.check config, neededEntries
	  	lostEntries = []
	  	neededEntries.each do |ent|
				lostEntries.push ent unless config.key? ent
	  	end
		  unless lostEntries.empty?
		  	message = "Config entries #{lostEntries.map{|ent| "\"" + ent.to_s + "\" "}}are missing!\n" + 
		  		"Try updating the config file."
				Wx::message_box message, "Error"
		  	raise "Error"
		  end
	  end
	  def self.fill user_setting, default_setting
	  	default_setting.each do |key,val|
	  		unless user_setting.key? key
	  			user_setting[key] = val
	  		end
	  	end
	  end
#	  def self.save filename
#	  	p current_settings = THE_APP.config[:settings]
#			unless current_settings == @@settings_ini	# try to save if 'values' has been changed
#				if Wx::message_box("Do you want to save configuration changes to\n#{filename}?", 
#					"Confirmation", Wx::YES_NO|Wx::YES_DEFAULT|Wx::ICON_QUESTION) == Wx::YES then
#		      File.open(filename, "w"){|f|
#		    		f.print @@comment
#		      	f.print current_settings.to_yaml
#		    	}
#				end
#	  	end
#	  end
  end
  class AircraftReader
  	def initialize filename
  		@aircraft = {}
			eval(File.new(filename).read, binding)
  	end
		def self.read filename
      (self.new filename).values
    end
    def values
    	@aircraft
    end
    def aircraft name, *configs
    	merged_config = {}
    	configs.size.times do |i|
				merged_config.merge! configs[i]
    	end
    	@aircraft[name] = merged_config
    end
  end
end