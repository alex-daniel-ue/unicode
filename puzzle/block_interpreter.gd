extends Object


#func interpret_program(begin_block: CapBlock) -> Error:
	#for block in begin_block.get_blocks():
		#if block is NestedBlock:
			## this means block is control flow, must be handled by this
			#pass
		#elif block is StatementBlock:
			## could be entity block, therefore emit signal, but could be general
			## program block like print, declare/set var, 
			#pass
		#pass
	#
	#return FAILED


func interpret_children(nested_block: NestedBlock) -> Error:
	while nested_block.evaluate():
		for block in nested_block.get_blocks():
			
			pass
		nested_block.loops += 1
	return FAILED
