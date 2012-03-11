module MvExtUtil

	# DESCRIPTION
	#	ˆ—‚Ìi’»ó‹µ‚ğ•\¦‚·‚é
	# ARGS
	#	Integer pos_now: current position
	#	Integer pos_end: end position
	#	Integer diff: interval btw. update
	def print_progress pos_now, end_pos, diff = 10
		progress = 100 * pos_now / end_pos	# %
		print "#{progress}% done...\r" if progress % diff == 0
	end
end