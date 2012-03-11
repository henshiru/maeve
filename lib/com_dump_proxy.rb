# To change this template, choose Tools | Templates
# and open the template in the editor.

module Mv
  class ComDumpProxy
    def initialize com,filename
      @com = com
      @f = File.new(filename,"wb")
    end
    def receive
      @f << (ret = @com.receive)
      ret
    end
  end
end
