extends Object


enum Flag {
	BREAK, CONTINUE
}


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
		
		if result.data == Flag.BREAK: break
		
		_loops += 1
		if _loops > Puzzle.MAX_LOOPS:
			return Utils.Result.error("Reached maximum amount of loops!", this)
	
	return Utils.Result.success()

## text: IF [BOOL]
## text: ELIF [BOOL]
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
	# NOTE: If-else logic handled inside _iterate_children, since that's
	# dependent on factors outside this block.
	var result := await _iterate_children(this)
	if result is Utils.Error: return result
	return Utils.Result.success()

## text: BREAK
static func function_break(
	this: StatementBlock,
	msg := "Cannot break without a non-iterative Block!",
	flag := Flag.BREAK
	) -> Utils.Result:
		
		# NOTE: Actual break is inside function_while, and etc. See inside
		# _iterate_children for more info.
		if _has_iterative_parent(this):
			return Utils.Result.success(flag)
		return Utils.Result.error(msg, this)

static func function_continue(this: StatementBlock) -> Utils.Result:
	return function_break(
		this,
		"Cannot continue without a non-iterative Block!",
		Flag.CONTINUE
	)


static func _iterate_children(this: NestedBlock) -> Utils.Result:
	var previous_block: Block = null
	var if_block_success: bool
	
	for block in this.get_blocks():
		if block is NestedBlock:
			
			if block.check_type(NestedBlockData.Type.ELSE):
				
				if not (previous_block is NestedBlock and
					previous_block.check_type(NestedBlockData.Type.IF)):
						return Utils.Result.error("Invalid block placement!", block)
				
				if if_block_success:
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
		
		elif block is StatementBlock:
			if block.function.get_method() in [
				&"function_break",
				&"function_continue"]:
					# NOTE: Condition checking occurs outside of _iterate_children
					# so can't realistically cause a break/continue from here. These
					# results have result.data of type Flag
					return result
		
		if Puzzle.delaying_interpret:
			await Game.sleep(Puzzle.block_interpret_delay)
		
		previous_block = block
		block.reset()
	
	return Utils.Result.success()


static func _has_iterative_parent(this: Block) -> bool:
	while this.parent_nested != null:
		this = this.parent_nested
		if not this is NestedBlock: continue
		if this.data.nested_type in [
			NestedBlockData.Type.WHILE,
			NestedBlockData.Type.FOR,
			NestedBlockData.Type.REPEAT]:
				return true
	
	return false
