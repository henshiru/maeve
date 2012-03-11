module Mv
  class FHIParameterReader
    Value = Struct.new(:gain)
    def initialize filename
      @value = eval(File.new(filename.tosjis).read, binding)#FIXME windows specific
    end
    attr_reader :value
    def self.read filename
      reader = (self.new filename)
      reader.value
    end
  end

  class FHIUploadDialog
    include Dialog
    def initialize
      @form = findDialog 'fhi_upload_dialog'
      @openDialogButton = findControl 'openDialogButton'
      @fileText = findControl 'fileText'
      @transferButton = findControl 'transferButton'
      @closeButton = findControl 'closeButton'

      @form.evt_button(@openDialogButton.get_id){
        dlg = Wx::FileDialog.new(@form,"Choose a file","","","(*.rb)|*.rb|all files(*.*)|*")
        if dlg.show_modal==Wx::ID_OK then
          @fileText.value = dlg.get_path
        end
      }
      @form.evt_button(@transferButton.get_id){
      	filename = @fileText.value
      	unless filename.empty?
        	transfer filename
				else
					Wx::message_box "Please specify a file.", "Error"
	  		end
      }
      @form.set_escape_id  @closeButton.get_id
      @form.evt_close{
        hide
      }
    end
    def serialize_element v
      [v.to_f].pack('f')
    end
    def transfer filename
      val = FHIParameterReader.read filename
      dat=""
      val.each{|v|
        dat += serialize_element(v)
      }
      THE_APP.send_data CID_FHI_UPLOAD, dat
    end
  end
end
