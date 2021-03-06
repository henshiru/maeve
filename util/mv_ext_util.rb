module MvExtUtil

	# DESCRIPTION
	#	処理の進捗状況を表示する
	# ARGS
	#	Integer pos_now: current position
	#	Integer pos_end: end position
	#	Integer diff: interval btw. update
	def print_progress pos_now, end_pos, diff = 10
		progress = 100 * pos_now / end_pos	# %
		print "#{progress}% done...\r" if progress % diff == 0
	end
end