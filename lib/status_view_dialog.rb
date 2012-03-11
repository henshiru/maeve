# To change this template, choose Tools | Templates
# and open the template in the editor.

module Mv
  class StatusViewDialog
    include Dialog
    def initialize
      @form = findDialog 'status_view_dialog'
      @statusText = findControl 'statusText'
      @closeButton = findControl 'closeButton'
      update_proc = THE_APP.com(0).add_property_listener(:itow, :num_sv, :latitude, :longitude, :altitude, :velocity, :servo_in, :servo_out){
        update_text
      }
      @form.set_escape_id  @closeButton.get_id
      form.evt_close{
        form.hide
      }
			neededConfig = [
    		:neu_ail, :neu_elv, :neu_rud, :neu_common, 
    		:r2v_ail, :r2v_elv, :r2v_rud, :max_thr, :min_thr,
    	]
    	ac_name = THE_APP.config[:selected_aircraft_name]
    	ConfigReader.check THE_APP.config[:aircraft][ac_name], neededConfig
      update_text
    end
    def update_text
      com = THE_APP.com(0)
      @statusText.label =
        "itow = #{com[:itow]}\n" + 
        "num_sv = #{com[:num_sv]}\n" + 
        "lat = #{com[:latitude]}, lng = #{com[:longitude]}, alt = #{com[:altitude]}\n" +
        "velocity = #{com[:velocity].r}\n" + 
        "roll = #{com[:roll]}, pitch = #{com[:pitch]}, head = #{com[:heading]}\n" +
	      "servo_in   = " + com[:servo_in].map{|x| x.to_s}.join(', ') + "\n" +
	      "servo_out = " + com[:servo_out].map{|x| x.to_s}.join(', ') + "\n" + 
#				"alrn, elvt, rudr, thrtl = " + ['ail','elv','rud','thr'].map{|dev| ServoView.percent(dev).to_s}.inject(){|r, x|r + ", " + x}
				"alrn, elvt, rudr, thrtl = " + ['ail','elv','rud'].map{|dev| (ServoView.rad(dev)*100).to_i.to_s}.join(', ') + ", " + ServoView.percent('thr').to_s
    end
  end
end
