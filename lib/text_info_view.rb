# To change this template, choose Tools | Templates
# and open the template in the editor.

module Mv
  class TextInfoView
    include Gadget
    def initialize args
      @frame = THE_APP.xrc.load_panel(args[:parent],'text_info_panel')
      @textInfo = Wx::Window.find_window_by_id(Wx::xrcid('textInfo'), @frame)
    end
    def push_info service, info
      @textInfo.append_text service
      @textInfo.append_text ">"
      @textInfo.append_text info
      @textInfo.append_text "\n"
    end
  end
end
