extends Node


enum ControlSignal {
	NONE,
	CONTINUE,
	BREAK,
}

# Manual const Set
const ITERATIVE_BLOCKS := {
	NestedData.Type.WHILE: true,
	NestedData.Type.FOR: true,
	NestedData.Type.REPEAT: true,
}


func _begin(this: NestedBlock) -> void:
	this.scope.clear()
	this.depth = 0
	
	await __iterate_children(this)

#region Iterative
## text: while {boolean}
func _while(this: NestedBlock) -> void:
	var loop_count := 0
	while true:
		this.visual.highlight()
		await Game.sleep(Puzzle.interpret_delay)
		
		var condition: Variant = await this.function.evaluate_arg(0)
		this.visual.reset()
		
		if Puzzle.has_errored:
			return
		
		var err_message := Core.validate_type(condition, [TYPE_BOOL])
		if not err_message.is_empty():
			this.function.error(err_message)
			return
		
		if not (condition as bool):
			break
		
		var outcome := await __iterate_children(this)
		if Puzzle.has_errored:
			return
		
		match outcome:
			ControlSignal.BREAK:
				return
			ControlSignal.CONTINUE:
				pass
		
		loop_count += 1
		if loop_count > Puzzle.MAX_LOOPS:
			this.function.error("Reached maximum amount of loops.")
			return

## text: for var {variable}, from {int}\nuntil {int}, at step {int}
func _for(this: NestedBlock) -> void:
	var args := await this.function.evaluate_args(3)
	if Puzzle.has_errored:
		return
	
	var err_message := Core.validate_type(args[0], [TYPE_STRING_NAME], 0)
	if not err_message.is_empty():
		this.function.error(err_message)
		return
	var var_name := args[0] as StringName
	
	err_message = Core.validate_type(args[1], [TYPE_INT], 1)
	if not err_message.is_empty():
		this.function.error(err_message)
		return
	
	err_message = Core.validate_type(args[2], [TYPE_INT], 2)
	if not err_message.is_empty():
		this.function.error(err_message)
		return
	var to := args[2] as int
	
	err_message = Core.validate_type(args[3], [TYPE_INT], 3)
	if not err_message.is_empty():
		this.function.error(err_message)
		return
	var step := args[3] as int
	
	if step == 0:
		this.function.error("Step cannot be zero. Use a while true loop instead.")
		return
	
	this.scope[var_name] = args[1] as int
	var loop_count := 0
	
	while (step > 0 and this.scope[var_name] <= to) or \
		  (step < 0 and this.scope[var_name] >= to):
		
		this.visual.highlight()
		await Game.sleep(Puzzle.interpret_delay)
		this.visual.reset()
		
		var outcome := await __iterate_children(this)
		if Puzzle.has_errored:
			return
		
		match outcome:
			ControlSignal.BREAK:
				return
			ControlSignal.CONTINUE:
				pass
		
		loop_count += 1
		if loop_count > Puzzle.MAX_LOOPS:
			this.function.error("Reached maximum amount of loops.")
			return
		
		err_message = Core.validate_type(this.scope[var_name], [TYPE_INT])
		if not err_message.is_empty():
			this.function.error("Loop variable was changed to non-integer.")
			return
		
		this.scope[var_name] += step
#endregion

#region Conditional
## text: if {boolean}, elif {boolean} -> [bool, ControlSignal]
func _if(this: NestedBlock) -> Variant:
	this.visual.highlight()
	await Game.sleep(Puzzle.interpret_delay)
	
	var condition: Variant = await this.function.evaluate_arg(0)
	this.visual.reset()
	
	if Puzzle.has_errored:
		return true  # Halt chain on error
	
	var err_message := Core.validate_type(condition, [TYPE_BOOL])
	if not err_message.is_empty():
		this.function.error(err_message)
		return true  # Halt chain on error
	
	if condition as bool:
		var outcome := await __iterate_children(this)
		if outcome != ControlSignal.NONE:
			return outcome
		
		return true  # Halt chain for both on success and on error
	
	return false

## text: else
func _else(this: NestedBlock) -> ControlSignal:
	# NOTE: If-else logic is handled inside _iterate_children, since that's
	# dependent on factors outside this block.
	return await __iterate_children(this)
#endregion

#region Modifiers
## text: break
func _break(this: StatementBlock) -> ControlSignal:
	var is_iterative := func(block: Block) -> bool:
		return block is NestedBlock and block.data.nested.type in ITERATIVE_BLOCKS
	
	if this.get_parent_matching(is_iterative, false) == null:
		this.function.error("Can't break from outside a loop.")
		return ControlSignal.NONE
	
	return ControlSignal.BREAK

## text: continue
func _continue(this: StatementBlock) -> ControlSignal:
	var is_iterative := func(block: Block) -> bool:
		return block is NestedBlock and block.data.nested.type in ITERATIVE_BLOCKS
	
	if this.get_parent_matching(is_iterative, false) == null:
		this.function.error("Cannot use 'continue' outside of a loop.")
		return ControlSignal.NONE
	
	return ControlSignal.CONTINUE
#endregion


#region Generic control flow methods
func __iterate_children(this: NestedBlock) -> ControlSignal:
	var previous_block: Block = null
	var if_chain_succeeded: bool
	
	for block in this.get_blocks():
		if not __validate_else_placement(block, previous_block):
			block.function.error("Invalid 'else' or 'elif' block placement.")
			return ControlSignal.NONE
		
		if block is NestedBlock:
			if block.is_type(NestedData.Type.ELSE) and if_chain_succeeded:
				continue
			
			block.scope = this.scope.duplicate(true)
			block.depth = this.depth + 1
			if block.depth > Puzzle.MAX_DEPTH:
				this.function.error("Reached maximum depth of recursion.")
				return ControlSignal.NONE
		
		var outcome: Variant = await block.function.run()
		if Puzzle.has_errored:
			return ControlSignal.NONE
		
		if outcome is ControlSignal and outcome != ControlSignal.NONE:
			return outcome as ControlSignal
		
		if block is NestedBlock:
			# Update original scope's existing variables with changed values
			# inside child scope
			for var_name in this.scope:
				this.scope[var_name] = block.scope[var_name]
			
			if block.is_type(NestedData.Type.IF):
				if not if_chain_succeeded:
					assert(outcome is bool)
					if_chain_succeeded = outcome as bool
			
			# Reset NestedBlock scope and depth
			block.scope.clear()
			block.depth = -1
		
		previous_block = block
	
	return ControlSignal.NONE

func __validate_else_placement(block: Block, prev_block: Block) -> bool:
	if block is NestedBlock and block.is_type(NestedData.Type.ELSE):
		return (prev_block is NestedBlock and
				prev_block.is_type(NestedData.Type.IF))
	
	return true
#endregion
