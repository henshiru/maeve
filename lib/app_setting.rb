#	Application Settings
{

:map_view => {
	:is_3d => false,
	:trajec_on => false,
	:trajec_span => 60,					# span[s] of trajectory to retain
	:trajec_colored_span => 20,	# span[s] of trajectory to show in color
},
:servo_view => {
	:type => 1,  # 0:classic / 1:aero
},
:altitude_view => {
	:hist_on => false,
	:hist_span => 60,										# span[s] of history to retain 
	:hist_vertical_range => [0,50,250],	# [min,scale-division,max]
},
:alert => {
	:global => true,	# global enable flag of alerts
  :antenna => true,
  :flight_log => true,
},
:selected_aircraft_name => "Generic",  # aircrafts are defined in "servo_settings.rb"

}