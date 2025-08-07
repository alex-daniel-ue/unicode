extends Node


func function_begin(this: NestedBlock) -> Utils.Result:
	# No argument checking required
	this.scope.clear()
	
	var result: Variant = await _iterate_children(this)
	if result is Utils.Error: return result
	
	return Utils.Result.success()

## text: WHILE [BOOL]
func function_while(this: NestedBlock) -> Utils.Result:
	if this.depth > Puzzle.MAX_DEPTH:
		return Utils.Result.error("Reached maximum depth of recursion!", this)
	
	var _loops := 0
	while true:
		var result := Utils.evaluate_and_check_arguments(1, this)
		if result is Utils.Error: return result
		var args := result.data as Array
		
		# Type checking
		result = Utils.validate_type(args, 0, [TYPE_BOOL], this)
		if result is Utils.Error: return result
		var condition := result.data as bool
		
		# Loop condition check
		if not condition: break
		
		result = await _iterate_children(this)
		if result is Utils.Error: return result
		
		_loops += 1
		if _loops > Puzzle.MAX_LOOPS:
			return Utils.Result.error("Reached maximum amount of loops!", this)
	
	return Utils.Result.success()

## text: IF [BOOL]
func function_if(this: NestedBlock) -> Utils.Result:
	var result := Utils.evaluate_and_check_arguments(1, this)
	if result is Utils.Error: return result
	var args := result.data as Array
	
	result = Utils.validate_type(args, 0, [TYPE_BOOL], this)
	if result is Utils.Error: return result
	var condition := result.data as bool
	
	if condition:
		result = await _iterate_children(this)
		if result is Utils.Error: return result
	
	return Utils.Result.success(condition)

## text: ELSE
func function_else(this: NestedBlock) -> Utils.Result:
	# NOTE: If-else logic handled inside _iterate_children
	var result := await _iterate_children(this)
	if result is Utils.Error: return result
	return Utils.Result.success()


func _iterate_children(this: NestedBlock) -> Utils.Result:
	var previous_block: Block = null
	var if_block_success: bool
	
	for block in this.get_blocks():
		if block is NestedBlock:
			if block.check_type(NestedBlockData.Type.ELSE):
				if (not previous_block is NestedBlock or
				not previous_block.check_type(NestedBlockData.Type.IF) or 
				if_block_success):
					continue
			
			block.scope = this.scope.duplicate()
		if_block_success = true
		
		block.parent_nested = this
		var result: Variant = await block.function.call()
		if result is Utils.Error: return result
		
		if block is NestedBlock and block.check_type(NestedBlockData.Type.IF):
			assert(result.data is bool)
			if_block_success = result.data
		
		if Game.delaying_interpret:
			await Game.sleep(Game.block_interpret_delay)
		
		previous_block = block
	
	return Utils.Result.success()
