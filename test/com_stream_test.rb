$:.unshift File.join(File.dirname(__FILE__),'..','lib')

require 'test/unit'
require 'com_stream'
require 'wincom'
require 'SylphideProcessor'
require 'acceleration_calibrator'

class ComStreamTest < Test::Unit::TestCase
  def check_content(observer)
    puts "GPSTime: #{observer.fetch_ITOW}"
    case observer
    when SylphideProcessor::APacketObserver
      v = observer.values
      puts "A #{[v.values.to_a, v.temperature].inspect}"
      acc = Mv::AccelerationCalibrator.new Mv::AccelerationCalibrator::BoardE1
      p acc.calibrate(v.values,v.temperature)
    when SylphideProcessor::FPacketObserver
      v = observer.values
      puts "F #{[v.servo_in.to_a, v.servo_out.to_a].inspect}"
    when SylphideProcessor::PPacketObserver
      v = observer.values
      puts "P #{[v.air_speed.to_a, v.air_alpha.to_a, v.air_beta.to_a].inspect}"
    when SylphideProcessor::MPacketObserver
      v = observer.values
      puts "M #{[v.x.to_a, v.y.to_a, v.z.to_a].inspect}"
    when SylphideProcessor::GPacketObserver
      puts "G #{format('0x%02X', observer.ubx_class)}, #{format('0x%02X', observer.ubx_id)}"
      case observer.ubx_class
      when 0x01
        case observer.ubx_id
        when 0x02
          p observer.position
          p observer.position_acc
        when 0x12
          p observer.velocity
          p observer.velocity_acc
        end
      when 0x02
        case observer.ubx_id
        when 0x10
          observer.num_of_sv.times{|i|
            p observer.raw(i)
          }
        when 0x31
          p observer.ephemeris
        end
      end
    end
  end
  def show_telemetry dat
    proc = SylphideProcessor::SylphideLog::new(1024)
    dat.each{|r|
      proc.process(r[:payload]){|obs|
        check_content(obs)
      }
    }
  end
  def test_empty_packet
    seqnum = 12345
    payload = []
    p payload
    payload = payload.pack('c*')

    pk = Mv::ComStreamPacketizer.new
    packet = pk.packetize payload, seqnum

    p packet

    dpk = Mv::ComStreamDepacketizer.new

    res = []
    res.concat dpk.depacketize(packet[0,1])
    res.concat dpk.depacketize(packet[1..-1])

    res = res[0]
    assert_equal(seqnum, res[:seqnum])
    assert_equal(payload.length, res[:payload].length)
    assert_equal(payload, res[:payload])
  end
  def test_fixed_packet
    seqnum = 100
    payload = []
    32.times{|i|#32 byte packet will be sent in a fixed-packet format
      payload[i] = i + 1
    }
    p payload
    payload = payload.pack('c*')

    pk = Mv::ComStreamPacketizer.new
    packet = pk.packetize payload, seqnum

    p packet.unpack('C*')

    dpk = Mv::ComStreamDepacketizer.new

    res = []
    res.concat dpk.depacketize(packet[0,7])
    res.concat dpk.depacketize(packet[7..-1])

    res = res[0]
    assert_equal(seqnum, res[:seqnum])
    assert_equal(payload.length, res[:payload].length)
    assert_equal(payload, res[:payload])
  end
  def test_variable_packet
    seqnum = 10000
    payload = []
    100.times{|i|
      payload[i] = (i*i*i)^(i+0xf0aaff00)
    }
    p payload
    payload = payload.pack('c*')

    pk = Mv::ComStreamPacketizer.new
    packet = pk.packetize payload, seqnum

    p packet

    dpk = Mv::ComStreamDepacketizer.new

    res = []
    res.concat dpk.depacketize(packet[0,4])
    res.concat dpk.depacketize(packet[4..-1])

    res = res[0]
    assert_equal(seqnum, res[:seqnum])
    assert_equal(payload.length, res[:payload].length)
    assert_equal(payload, res[:payload])
  end
end
