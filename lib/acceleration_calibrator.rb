require 'matrix_util'

module Mv
  class AccelerationCalibrator
    class BoardE1
      def initialize
      end
      def acc_indices
        [0,1,2]
      end
      def gyro_indices
        [3,4,5]
      end
      def acc_bias t
        Vector[
          8447835.13014 + (t-390.1)*2036.371157,
          8378997.5352 + (t-390.1)*1092.026892,
          8547076.2035 + (t-390.1)*7677.174791,
        ]
      end
      def gyro_bias t
        Vector[
          -362.827133*t + 8482795.827132,
          90.034111*t + 8392196.460149,
          -234.56717*t + 8580756.390961
        ]
      end
      def acc_scalefactor t
        Vector[
          118441.0042,#355323.0125,
          119903.8831,#359711.6493,
          -120371.2326,#-361113.7008
        ]
      end
      def gyro_scalefactor t
        Vector[
          41644.7604*180/Math::PI,
          41465.4576*180/Math::PI,
          41352.30616*180/Math::PI
        ]
      end
      def acc_misalighnment
        Matrix[
          [0.999896328,-0.0140202137,0.003281297177],
          [0.01400988323,0.9998968938,0.003150380419],
          [-0.003325127862,-0.003104083223,0.999989654]
        ]
      end
      def gyro_misalighnment
        Matrix[
          [0.999863297,-0.003371996897,-0.01004608045],
          [-0.006810545144,1.00135929,-0.04028177391],
          [0.02145649341,-0.01262872112,1.00059739]
        ]
      end
    end
    def initialize board_class
      @board = board_class.new
    end
    def calibrate values,temperature
      a_idx = @board.acc_indices
      a_bias = @board.acc_bias(temperature)
      a_sf = @board.acc_scalefactor(temperature)
      g_idx = @board.gyro_indices
      g_bias = @board.gyro_bias(temperature)
      g_sf = @board.gyro_scalefactor(temperature)

      a = Vector[values[a_idx[0]],values[a_idx[1]],values[a_idx[2]]]
      g = Vector[values[g_idx[0]],values[g_idx[1]],values[g_idx[2]]]
      3.times{|i|
        a[i] = (a[i] - a_bias[i])/a_sf[i]
        g[i] = (g[i] - g_bias[i])/g_sf[i]
      }
      return {
        :accel => @board.acc_misalighnment*a,
        :omega => @board.gyro_misalighnment*g
      }
    end
  end
end
