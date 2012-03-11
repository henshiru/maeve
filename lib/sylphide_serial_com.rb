# To change this template, choose Tools | Templates
# and open the template in the editor.
require 'wincom'

module Mv
  class SylphideSerialCom
    def initialize icom
      @com = Serial.new
      @com.open(icom,(1<<0),9600,8,0,0,10240,10240)
      @count = 0
      @buf = ""
    end
    def receive
      @com.receive
    end
    def send data
      @com.send data
    end
    def close
      @com.close
    end
  end
end
