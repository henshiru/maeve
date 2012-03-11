# To change this template, choose Tools | Templates
# and open the template in the editor.

module Mv
  class CommandView
    include Gadget
    def initialize args
      @frame = THE_APP.xrc.load_panel(args[:parent],'command_panel')
      @cidText = Wx::Window.find_window_by_id(Wx::xrcid('cidText'), @frame)
      @dataText = Wx::Window.find_window_by_id(Wx::xrcid('dataText'), @frame)
      @sendButton = Wx::Window.find_window_by_id(Wx::xrcid('sendButton'), @frame)
      @frame.evt_button(@sendButton.get_id){
        THE_APP.send_data @cidText.value.to_i, @dataText.value
      }
    end
  end
end
