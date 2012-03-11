# To change this template, choose Tools | Templates
# and open the template in the editor.

# To add an alert, register a sound file in @wavenames
# and a criterion in @judgments.

module Mv
	class Alert
		MAX_CNT_ALERT = 5
		VELOC_THRESH = 20
		def initialize
			THE_APP.properties.add_listener(:config){update nil}
			@com = THE_APP.com(0)
			default_conf = {:global=>true, :flight_log=>true, :antenna=>true}
    	ConfigReader.fill THE_APP.config[:alert]||={}, default_conf
			@conf = THE_APP.config[:alert]
			@alerts = []
			@status = {}
			@cnt = Hash.new(0)
			@wavnames = {	#keys must be the same as those written in alert sectoin of config file
				:flight_log => "../wav/flightLogAlert.wav",
				:antenna => "../wav/antennaAlert.wav",
			}
			@judgments = { #criteria for calling alerts
				:flight_log => Proc.new{
					!@status[:logging] && @com[:velocity].r > VELOC_THRESH \
						&& ServoView.percent('thr') > 50
				},
				:antenna => Proc.new{
					ServoView.isOn('ant') && @com[:velocity].r > VELOC_THRESH \
						&& ServoView.percent('thr') < 20
				},
			}
			@timer = Wx::Timer.new(THE_APP)
			THE_APP.evt_timer(@timer.get_id){on_timer}
			@timer.start(3000)
		end
		def update args
			@conf = THE_APP.config[:alert]
			args.each do |key, val| @status[key] = val end if args
		end
		private
		def check
			@judgments.each{|alert, judge|
				if @conf[alert]
					if judge.call
						@alerts.push(alert) if @cnt[alert] < MAX_CNT_ALERT
					else
						@cnt[alert] = 0
					end
				end
			}
		end
		def alert
			if (alert = @alerts.shift)
				@cnt[alert] += 1
				begin
					Wx::Sound.play(@wavnames[alert])
				rescue => evar
					Wx::message_box "#{alert} alert! with an error.\n#{evar.inspect}", "Error"
				end
			end
		end
		def on_timer
			if @conf[:global] && @status[:data_source] == 'Com'
				check
				alert
			end
		end
	end
end