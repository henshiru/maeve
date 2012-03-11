module Mv
  class FlightplanTransferDialog
    include Dialog
    def initialize
      @form = findDialog 'flightplan_transfer_dialog'
      @openDialogButton = findControl 'openDialogButton'
      @fileText = findControl 'fileText'
      @transferButton = findControl 'transferButton'
      @saveButton = findControl 'saveButton'
      @loadButton = findControl 'loadButton'
      @closeButton = findControl 'closeButton'

      @form.evt_button(@openDialogButton.get_id){
        dlg = Wx::FileDialog.new(@form,"Choose a file","","","(*.rb)|*.rb|all files(*.*)|*", Wx::FD_SAVE)
        if dlg.show_modal==Wx::ID_OK then
          @fileText.value = dlg.get_path
        end
      }
      @form.evt_button(@transferButton.get_id){
        transfer @fileText.value
      }
      @form.evt_button(@saveButton.get_id){
        filename = @fileText.value
        unless filename.empty? then
          THE_APP.flightplan_manager.save_to_file filename
        end
      }
      @form.evt_button(@loadButton.get_id){
        filename = @fileText.value
        unless filename.empty? then
          THE_APP.flightplan_manager.load_from_file filename
        end
      }
      @form.set_escape_id @closeButton.get_id
      @form.evt_close{
        hide
      }
    end
    def transfer filename
      dat = THE_APP.flightplan_manager.serialize
      THE_APP.send_data CID_FLIGHTPLAN_TRANSFER, dat
    end
  end
end
