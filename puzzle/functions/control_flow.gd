extends Object


## text: BEGIN CODE
static func function_begin(this: NestedBlock) -> Utils.Result:
	# No argument checking required
	this.reset()
	
	var result: Variant = await _iterate_children(this)
	if result is Utils.Error: return result
	
	return Utils.Result.success()
	
	@warning_ignore("unreachable_code")
	return Utils.Result.error("sabi ni sai", this)

## text: WHILE [BOOL]
static func function_while(this: NestedBlock) -> Utils.Result:
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
static func function_if(this: NestedBlock) -> Utils.Result:
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
static func function_else(this: NestedBlock) -> Utils.Result:
	# NOTE: If-else logic handled inside _iterate_children
	var result := await _iterate_children(this)
	if result is Utils.Error: return result
	return Utils.Result.success()


static func _iterate_children(this: NestedBlock) -> Utils.Result:
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
			block.depth = this.depth + 1
			if block.depth > Puzzle.MAX_DEPTH:
				return Utils.Result.error("Reached maximum depth of recursion!", this)
		
		# Default value is true; okay since every IF block resets it to their result
		if_block_success = true
		
		block.parent_nested = this
		var result: Variant = await block.function.call()
		if result is Utils.Error: return result
		
		if block is NestedBlock:
			for variable in this.scope:
				this.scope[variable] = block.scope[variable]
			
			if block.check_type(NestedBlockData.Type.IF):
				assert(result.data is bool)
				if_block_success = result.data
		
		if Game.delaying_interpret:
			await Game.sleep(Game.block_interpret_delay)
		
		previous_block = block
		block.reset()
	
	return Utils.Result.success()
