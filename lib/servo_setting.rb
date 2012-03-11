# Values for ORCA in this file were generated from 
# rev.3840(2010/12/02) of aics_sylphide.cpp.


#------------------
# components
# 	ch_*			Channel. ch(i) here corresponds to ch(i+1) of RF receiver
# 	neu_*			Neutral position.
# 	r2v_*			Rad2Value. Pulse width[us] per deflection angle[rad].
#------------------

Common = {
	:ch_ail => 0,
	:ch_elv => 1,
	:ch_thr => 2,
	:ch_rud => 3,
	:ch_cic => 7,
	:neu_cic => 1500,
	:sgn_cic => 1,	# logical 1/-1 means cic is on when servo value is high/low respectively
	:neu_common => 1500,	# can be substituted for neu of cic, ant, tip, etc in on/off judgment
  :dev_type => 'normal',
}

ORCA_common = {
#	:ch_ant => 4,
	:ch_flp => 5,
	:ch_tip => 6,
#	:neu_ant => 1500,
#	:sgn_ant => 1,
}

# ORCA fuselages
ORCA_F2 = {
	:min_elv => 1119,
	:max_elv => 1873,
	:r2v_elv => -796,
	:neu_elv => 1496,
	:min_thr => 1100,
	:max_thr => 1933,
	:min_rud => 1102,
	:max_rud => 1942,
	:r2v_rud => -791,
	:neu_rud => 1502,
}
ORCA_F3 = {
	:min_elv => 1279,
	:max_elv => 1704,
	:r2v_elv => 834,
	:neu_elv => 1489,
	:min_thr => 1100,
	:max_thr => 1933,
	:min_rud => 1092,
	:max_rud => 1932,
	:r2v_rud => 596,
	:neu_rud => 1512,
}

# ORCA wings
# using values of left aileron
ORCA_W1 = {
	:min_ail => 1029,
	:max_ail => 1868,
	:r2v_ail => -663,
	:neu_ail => 1496,
	:neu_flp => 1500,
	:sgn_flp => -1,
	:neu_tip => 1500,
	:sgn_tip => -1,
}
ORCA_W2 = {
	:min_ail => 1029,
	:max_ail => 1868,
	:r2v_ail => -722,
	:neu_ail => 1495,
	:neu_flp => 1500,
	:sgn_flp => -1,
	:neu_tip => 1500,
	:sgn_tip => -1,
}
ORCA_W3 = {
	:min_ail => 1093,
	:max_ail => 1932,
	:r2v_ail => -698,
	:neu_ail => 1650,
	:neu_flp => 1500,
	:sgn_flp => -1,
	:neu_tip => 1500,
	:sgn_tip => -1,
}

Mitsubishi = {
	:min_ail => 930,
	:max_ail => 1980,
	:r2v_ail => -1510,
	:neu_ail => 1469,
	:min_elv => 1170,
	:max_elv => 2100,
	:r2v_elv => -750,
	:neu_elv => 1592,
	:min_thr => 1000,
	:max_thr => 2000,
	:min_rud => 1080,
	:max_rud => 1860,
	:r2v_rud => -860,
	:neu_rud => 1437,
}

HYTEX = {
  :ch_eln_l => 0,
	:ch_eln_r => 1,
  :min_ail => 1088,
	:max_ail => 1866,
	:r2v_ail => -1147,
	:neu_ail => 1491,
	:min_elv => -369,
	:max_elv => 408,
	:r2v_elv => -1147,
	:neu_elv => 105,
	:min_thr => 916,
	:max_thr => 1219,
	:min_rud => 1208,
	:max_rud => 1736,
	:r2v_rud => 1806,
	:neu_rud => 1495,
  :dev_type => 'elevon-rudder',
}

Generic = {
	:min_ail => 1000,
	:max_ail => 2000,
	:r2v_ail => -3000,
	:neu_ail => 1500,
	:min_elv => 1000,
	:max_elv => 2000,
	:r2v_elv => -3000,
	:neu_elv => 1500,
	:min_thr => 1000,
	:max_thr => 2000,
	:min_rud => 1000,
	:max_rud => 2000,
	:r2v_rud => -3000,
	:neu_rud => 1500,
}



#------------------
# aircrafts
#		format: aircraft "name", component(s) ...
# 	caution: Precedeng components are overwitten by the following one in case of conflict.
#------------------
aircraft "ORCA_F2W1", Common, ORCA_common, ORCA_F2, ORCA_W1
aircraft "ORCA_F2W2", Common, ORCA_common, ORCA_F2, ORCA_W2
aircraft "ORCA_F2W3", Common, ORCA_common, ORCA_F2, ORCA_W3
aircraft "ORCA_F3W1", Common, ORCA_common, ORCA_F3, ORCA_W1
aircraft "ORCA_F3W2", Common, ORCA_common, ORCA_F3, ORCA_W2
aircraft "ORCA_F3W3", Common, ORCA_common, ORCA_F3, ORCA_W3
aircraft "Mitsubishi", Common, Mitsubishi
aircraft "HYTEX", Common, HYTEX
aircraft "Generic", Common, Generic