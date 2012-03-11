# To change this template, choose Tools | Templates
# and open the template in the editor.

module Mv
  class PacketCountView
    include Gadget
    def initialize args
      @frame = THE_APP.xrc.load_panel(args[:parent],'packet_count_panel')
      @count_texts = {
        :f => Wx::Window.find_window_by_id(Wx::xrcid('fCountText'), @frame),
        :p => Wx::Window.find_window_by_id(Wx::xrcid('pCountText'), @frame),
        :g => Wx::Window.find_window_by_id(Wx::xrcid('gCountText'), @frame),
        :a => Wx::Window.find_window_by_id(Wx::xrcid('aCountText'), @frame),
        :n => Wx::Window.find_window_by_id(Wx::xrcid('nCountText'), @frame),
      }
      @depacketized_bytes_text = Wx::Window.find_window_by_id(Wx::xrcid('depacketizedBytesText'), @frame)

      THE_APP.com(0).add_property_listener(:packet_count,:received_bytes,:depacketized_bytes){
        update
      }
    end
    private
    def update
      com = THE_APP.com(0)
      counts = com[:packet_count]
      @count_texts.each {|key,text|
        text.label = counts[key].to_s
      }
      @depacketized_bytes_text.label = "received #{com[:received_bytes]/1024} KB, depacketized #{com[:depacketized_bytes]/1024} KB."
    end
  end
end
