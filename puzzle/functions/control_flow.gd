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

const MAX_LOOP_ERROR := "Reached maximum amount of loops."


func _begin(this: NestedBlock) -> void:
	await Interpreter.step(this)
	if Interpreter.interrupted: return
	
	Interpreter.clear_scopes()
	
	await __run_body(this)

#region Iterative
## text: while {boolean}
func _while(this: NestedBlock) -> void:
	var loop_count := 0
	while true:
		await Interpreter.step(this)
		if Interpreter.interrupted: return
		
		var args := await this.function.eval_args([this.function.Argument.BOOL])
		if Interpreter.interrupted: return
		
		if not (args[0] as bool):
			break
		
		var outcome := await __run_body(this)
		if Interpreter.interrupted: return
		
		match outcome:
			ControlSignal.BREAK:
				return
			ControlSignal.CONTINUE:
				pass
		
		loop_count += 1
		if loop_count > Interpreter.MAX_LOOPS:
			this.function.error(MAX_LOOP_ERROR)
			return

## text: for var {variable}, from {int}\nto {int}, at step {int}
func _for(this: NestedBlock) -> void:
	var args := await this.function.eval_args([
		this.function.Argument.STRING_NAME,
		this.function.Argument.VARIANT,
		this.function.Argument.VARIANT,
		this.function.Argument.VARIANT
	])
	if Interpreter.interrupted: return
	
	var var_name := args[0] as StringName
	
	var from_value: Variant = __resolve_bound(this, args[1], "from")
	if from_value == null: return
	var to_value: Variant = __resolve_bound(this, args[2], "to")
	if to_value == null: return
	var step_value: Variant = __resolve_bound(this, args[3], "step")
	if step_value == null: return
	
	var to := int(to_value)
	var step := int(step_value)
	
	Interpreter.push_scope("for " + String(var_name), this.get_instance_id())
	if not Interpreter.declare_var(var_name, from_value as int):
		Interpreter.pop_scope()
		this.function.error("Variable '%s' already exists." % var_name)
		return
	
	var loop_count := 0
	
	while (step >= 0 and Interpreter.read_var(var_name) <= to) or \
		  (step < 0 and Interpreter.read_var(var_name) >= to):
		
		await Interpreter.step(this)
		if Interpreter.interrupted: break
		
		var outcome := await __run_body(this)
		if Interpreter.interrupted: break
		if outcome == ControlSignal.BREAK: break
		
		loop_count += 1
		if loop_count > Interpreter.MAX_LOOPS:
			this.function.error(MAX_LOOP_ERROR)
			break
		
		var err_message := Core.validate_type(
			Interpreter.read_var(var_name), this.function.Argument.INT
		)
		if not err_message.is_empty():
			this.function.error("Loop variable was changed to non-integer.")
			break
		
		Interpreter.assign_var(var_name, Interpreter.read_var(var_name) + step)
	
	Interpreter.pop_scope()
#endregion

#region Conditional
## text: if {boolean}, elif {boolean} -> [bool, ControlSignal]
func _if(this: NestedBlock) -> Variant:
	await Interpreter.step(this)
	if Interpreter.interrupted: return true
	
	var args := await this.function.eval_args([this.function.Argument.BOOL])
	if Interpreter.interrupted: return true  # Halt chain on error
	
	if args[0] as bool:
		var outcome := await __run_body(this)
		if outcome != ControlSignal.NONE:
			return outcome
		
		return true  # Halt chain for both on success and on error
	
	return false

## text: else
func _else(this: NestedBlock) -> ControlSignal:
	await Interpreter.step(this)
	if Interpreter.interrupted: return ControlSignal.NONE
	
	# NOTE: The actual if-else branch evaluation is handled inside
	# __iterate_children(), because it depends on the execution outcome of
	# previous blocks in the chain.
	return await __run_body(this)
#endregion

#region Modifiers
## text: break
func _break(this: StatementBlock) -> ControlSignal:
	await Interpreter.step(this)
	if Interpreter.interrupted: return ControlSignal.NONE
	
	var is_iterative := func(block: Block) -> bool:
		return block is NestedBlock and block.data.nested.type in ITERATIVE_BLOCKS
	
	if this.get_parent_matching(is_iterative, false) == null:
		this.function.error("Can't break from outside a loop.")
		return ControlSignal.NONE
	
	return ControlSignal.BREAK

## text: continue
func _continue(this: StatementBlock) -> ControlSignal:
	await Interpreter.step(this)
	if Interpreter.interrupted: return ControlSignal.NONE
	
	var is_iterative := func(block: Block) -> bool:
		return block is NestedBlock and block.data.nested.type in ITERATIVE_BLOCKS
	
	if this.get_parent_matching(is_iterative, false) == null:
		this.function.error("Cannot use 'continue' outside of a loop.")
		return ControlSignal.NONE
	
	return ControlSignal.CONTINUE
#endregion


#region Generic control flow methods
func __iterate_children(this: NestedBlock) -> ControlSignal:
	var misplaced := __find_misplaced_branch(this)
	if misplaced != null:
		misplaced.function.error("Invalid 'else' or 'elif' block placement.")
		return ControlSignal.NONE
	
	var if_chain_succeeded := false
	
	for block in this.get_blocks():
		if block is NestedBlock:
			if block.is_type(NestedData.Type.ELSE):
				if if_chain_succeeded:
					continue
			elif block.is_type(NestedData.Type.IF):
				if_chain_succeeded = false
			
			if Interpreter.scopes.size() > Interpreter.MAX_DEPTH:
				this.function.error("Reached maximum depth of recursion.")
				return ControlSignal.NONE
		
		var outcome: Variant = await block.function.run()
		if Interpreter.interrupted:
			return ControlSignal.NONE
		
		if outcome is ControlSignal and outcome != ControlSignal.NONE:
			return outcome as ControlSignal
		
		if block is NestedBlock and block.is_type(NestedData.Type.IF):
			if not if_chain_succeeded:
				assert(outcome is bool)
				if_chain_succeeded = outcome as bool
	
	return ControlSignal.NONE

func __find_misplaced_branch(this: NestedBlock) -> Block:
	var previous_block: Block = null
	for block in this.get_blocks():
		if not __validate_else_placement(block, previous_block):
			return block
		previous_block = block
	return null

func __run_body(this: NestedBlock) -> ControlSignal:
	Interpreter.push_scope(this.text.get_raw(), this.get_instance_id())
	var outcome := await __iterate_children(this)
	Interpreter.pop_scope()
	return outcome

func __validate_else_placement(block: Block, prev_block: Block) -> bool:
	if block is NestedBlock and block.is_type(NestedData.Type.ELSE):
		return (prev_block is NestedBlock and
				prev_block.is_type(NestedData.Type.IF))
	
	return true

func __resolve_bound(this: NestedBlock, raw: Variant, label: String) -> Variant:
	var value: Variant = this.function.unwrap(raw)
	if Interpreter.interrupted:
		return null
	
	if typeof(value) == TYPE_FLOAT:
		this.function.error("The '%s' value has to be a whole number, but it's %s. Use // to divide without a decimal." % [label, value])
		return null
	
	if typeof(value) != TYPE_INT:
		this.function.error(
			"The '%s' value has to be a whole number, but it's %s."
			% [label, Core.get_type_string(value)]
		)
		return null
	
	return value
#endregion
