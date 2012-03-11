require 'com_stream'
require 'SylphideProcessor'
require 'acceleration_calibrator'
require 'property_holder'

module Mv
  class SylphideCommunicator
    N_SERVO_OUT_CH = 8
    N_SERVO_IN_CH = 8
    attr_reader :history
    def initialize
      @properties = PropertyHolder.new
      @dpk = Mv::ComStreamDepacketizer.new
      @packetizer = Mv::ComStreamPacketizer.new
      @proc = SylphideProcessor::SylphideLog::new(1024)

      @seqnum = 1

      @properties[:accel] = Vector[0,0,0]
      @properties[:omega] = Vector[0,0,0]
      @properties[:latitude] = 0
      @properties[:longitude] = 0
      @properties[:altitude] = 0
      @properties[:num_sv] = 0
      @properties[:satellites] = []
      @properties[:roll] = 0
      @properties[:pitch] = 0
      @properties[:heading] = 0
      @properties[:velocity] = Vector[0,0,0]
      @properties[:packet_count] = {:f=>0,:p=>0,:g=>0,:a=>0,:n=>0}
      @properties[:received_bytes] = 0
      @properties[:depacketized_bytes] = 0
      @properties[:itow] = 0
      @properties[:system_time] = 0
      @properties[:servo_out] = Array.new(N_SERVO_OUT_CH, 0)
      @properties[:servo_in] = Array.new(N_SERVO_IN_CH, 0)

      @history = []
      @properties.add_listener(:all){|changed|
        h = {}
        changed.each{|key|
          h[key] = @properties[key]
        }
        #@history.push h # FIXME: for flight test
      }
    end

    def add_property_listener *keys,&proc
      @properties.add_listener(*keys,&proc)
    end

    def remove_property_listener proc
      @properties.remove_listener(proc)
    end

    def [] key
      @properties[key]
    end

    def update data
      @properties[:received_bytes] += data.length
      @properties[:system_time] = (Time.now.to_f*1000).to_i
      process_telemetry(@dpk.depacketize(data))
      @properties.notify_listeners
    end

    def packetize data, ack_req, ack_res
      @packetizer.packetize data, @seqnum+=1, ack_req, ack_res
    end

    def properties
      result={}
      @properties.each{|key,value|
        result[key]=value
      }
      result
    end

    private
    def increment_packet_count key
      @properties[:packet_count][key] += 1
      @properties.set_changed :packet_count
    end
    def ubx_id16 observer
      (observer.ubx_class<<8) | observer.ubx_id
    end
    def check_content(observer)
      case observer
      when SylphideProcessor::APacketObserver
        increment_packet_count :a
        v = observer.values
        acc = Mv::AccelerationCalibrator.new Mv::AccelerationCalibrator::BoardE1
        res = acc.calibrate(v.values,v.temperature)
        @properties[:accel] = res[:accel]
        @properties[:omega] = res[:omega]
      when SylphideProcessor::GPacketObserver
        increment_packet_count :g
        @properties[:itow] = observer.fetch_ITOW
        case ubx_id16(observer)
        when 0x0130#space vehicle information
          satellites = []
          n_ch = observer.channels
          n_ch.times{|i|
            svi = observer.svinfo(i)
            if svi.flags&0x04 != 0 then
              satellites.push({
                  :id => svi.svid,
                  :elevation => svi.elevation,
                  :azimuth => svi.azimuth,
                  :quality => svi.quality_indicator,
                  :flags => svi.flags,
                })
            end
          }
          @properties[:satellites] = satellites
        when 0x0210
          @properties[:num_sv] = observer.num_of_sv
        end
      when SylphideProcessor::FPacketObserver
        increment_packet_count :f
        N_SERVO_OUT_CH.times{|i|
          @properties[:servo_out][i] = observer.values.servo_out[i]
        }
        @properties.set_changed :servo_out
        N_SERVO_IN_CH.times{|i|
          @properties[:servo_in][i] = observer.values.servo_in[i]
        }
        @properties.set_changed :servo_in
      when SylphideProcessor::PPacketObserver
        increment_packet_count :p
      when SylphideProcessor::NPacketObserver
        increment_packet_count :n
        navdata = observer.navdata
        @properties[:itow] = navdata.itow
        @properties[:longitude] = navdata.longitude
        @properties[:latitude] = navdata.latitude
        @properties[:altitude] = navdata.altitude
        @properties[:velocity] = Vector[navdata.v_north,navdata.v_east,navdata.v_down]
        @properties[:roll] = navdata.roll
        @properties[:pitch] = navdata.pitch
        @properties[:heading] = navdata.heading
      end
    end
    def check_content_m(payload)
    	contents = {}
    	head = 0
      pl_length = payload.length
			while head < pl_length do
        catch(:invalid_packet){
          keyLen_pp = payload[head] # => key.length++
          keyBegin = head + 1
          keyEnd = keyBegin + keyLen_pp - 1
          throw :invalid_packet unless keyBegin.between?(0,keyEnd) && keyEnd.between?(0,pl_length-2)
          key = payload[keyBegin..keyEnd].unpack('A*')[0]
          valLen = payload[keyEnd+1]
          valBegin = keyEnd + 2
          valEnd = valBegin + valLen - 1
          throw :invalid_packet unless valBegin.between?(0,valEnd) && valEnd.between?(0,pl_length-1)
          val = payload[valBegin..valEnd]
          (contents[key] ||= []).push val
          head = valEnd + 1
        }
      end
      contents.each do |key,vals|
      	case key
      	when 'waypoint' then THE_APP.flightplan_manager.receive_waypoint vals, 'ddc'
				when 'waypoint3d' then THE_APP.flightplan_manager.receive_waypoint vals, 'dddc'
      	else	THE_APP.debug_message 'dlnk: invalid command.'
      	end
      end
    end
    def process_telemetry dat
      dat.each{|r|
        payload = r[:payload]
        @properties[:depacketized_bytes] += payload.length
        case payload[0].chr
        when 'D'
          THE_APP.debug_message payload[1..-1]
        when 'm'
        	check_content_m payload[1..-1]
        else
          next if payload[0].chr == 'N' && payload[2] != 0 # dirty trick(to ignore log data written on SD-card)
          @proc.process(payload){|obs|
            check_content(obs)
          }
        end
      }
    end
  end
end