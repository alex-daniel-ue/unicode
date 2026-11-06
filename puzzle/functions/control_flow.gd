extends Node
## What the control blocks do: Begin, the loops, If/Elif/Else, Break and
## Continue, and functions (Define, a call, Return).
##
## Each method is a block's function, named by its BlockData (Function/method)
## and called with the block. They start with _ because `while`, `if` and `for`
## are keywords; helpers start with __, which keeps them out of the inspector's
## list of methods a block can use.
##
## A nested block runs its body through __run_body(), and a body hands back a
## ControlSignal, so a break, a continue or a return inside it reaches the loop
## or the call it is for.

enum ControlSignal {
	NONE,
	CONTINUE,
	BREAK,
	## A `return` ran: every block between it and the call stops, loops too.
	RETURN,
}

const ITERATIVE_BLOCKS := {
	NestedData.Type.WHILE: true,
	NestedData.Type.FOR: true,
	NestedData.Type.REPEAT: true,
	NestedData.Type.FOR_EACH: true,
}
const MAX_LOOP_ERROR := "Reached maximum amount of loops."


## begin
func _begin(this: NestedBlock) -> void:
	await Interpreter.step(this)
	if Interpreter.interrupted: return

	Interpreter.clear_scopes()
	await __run_body(this)
	# A beat before the room is checked, so the last block's work is seen
	# before the win (or the fail) takes over.
	if not Interpreter.interrupted:
		await Interpreter.settle()


#region Loops
## while {boolean}
##
## Untyped, as are the other loops: a `return` inside the body ends the loop
## and goes on up to the function call, as a ControlSignal.
func _while(this: NestedBlock):
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
			ControlSignal.RETURN:
				return outcome

		loop_count += 1
		if loop_count > Interpreter.MAX_LOOPS:
			this.function.error(MAX_LOOP_ERROR)
			return


## for var {variable}, from {int}\nuntil {int}, at step {int}
##
## Counts like Python's range(): from the start, up to but not including the
## end. `from 0 until 3` runs 0, 1, 2, which is range(0, 3), so walking a list by
## position is `from 0 until length of xs`, as in range(len(xs)). Counting down
## stops before the end too: `from 3 until -1 at step -1` runs 3, 2, 1, 0.
func _for(this: NestedBlock):
	var args := await this.function.eval_args([
		this.function.Argument.STRING_NAME,
		this.function.Argument.VARIANT,
		this.function.Argument.VARIANT,
		this.function.Argument.VARIANT,
	])
	if Interpreter.interrupted: return

	var var_name := args[0] as StringName
	var from_value: Variant = __resolve_bound(this, args[1], "from")
	if from_value == null: return
	var to_value: Variant = __resolve_bound(this, args[2], "until")
	if to_value == null: return
	# Counting by is optional: left blank, it counts by 1, as Python's
	# range(start, end) does.
	var step_value: Variant = 1 if __is_blank(this, 3) else __resolve_bound(this, args[3], "counting by")
	if step_value == null: return

	var to := int(to_value)
	var step := int(step_value)

	Interpreter.push_scope("for " + String(var_name), this.get_instance_id())
	if not Interpreter.declare_var(var_name, from_value as int):
		Interpreter.pop_scope()
		this.function.error("Variable '%s' already exists." % var_name)
		return

	var loop_count := 0
	while (step >= 0 and Interpreter.read_var(var_name) < to) \
			or (step < 0 and Interpreter.read_var(var_name) > to):
		await Interpreter.step(this)
		if Interpreter.interrupted: break

		var outcome := await __run_body(this)
		if Interpreter.interrupted: break
		if outcome == ControlSignal.BREAK: break
		if outcome == ControlSignal.RETURN:
			Interpreter.pop_scope()
			return outcome

		loop_count += 1
		if loop_count > Interpreter.MAX_LOOPS:
			this.function.error(MAX_LOOP_ERROR)
			break

		var err_message := Core.validate_type(Interpreter.read_var(var_name), this.function.Argument.INT)
		if not err_message.is_empty():
			this.function.error("Loop variable was changed to non-integer.")
			break

		Interpreter.assign_var(var_name, Interpreter.read_var(var_name) + step)

	Interpreter.pop_scope()


## for each {variable} in {list}
##
## The packaging of `for i from 0 to length of xs - 1 { ... item i of xs ... }`,
## as `for` is of the counted while. A list is walked by index with its length
## read again every pass, as Python's list iterator does, so appending to the
## list being walked keeps the loop going (until the list is too long). The
## variable gets a copy of each item, so changing it doesn't change the list, in
## Python or here. A dictionary gives its keys and a file its lines, in order,
## as Python's for does.
func _for_each(this: NestedBlock):
	var args := await this.function.eval_args([
		this.function.Argument.STRING_NAME,
		this.function.Argument.VARIANT,
	])
	if Interpreter.interrupted: return

	var var_name := args[0] as StringName
	var target: Variant = this.function.unwrap(args[1])
	if Interpreter.interrupted: return

	if target is DictEntity:
		var board := target as DictEntity
		var keys := board.key_list()
		var key_count := func() -> int: return keys.size()
		var key_at := func(i: int) -> Variant: return keys[i]
		var point_at_key := func(i: int) -> void: board.point_at(keys[i] if i >= 0 else null)
		return await __walk(this, var_name, key_count, key_at, point_at_key)

	if target is FileEntity:
		var file := target as FileEntity
		var lines := file.line_list()
		var line_count := func() -> int: return lines.size()
		var line_at := func(i: int) -> Variant: return lines[i]
		return await __walk(this, var_name, line_count, line_at, file.point_at)

	var list := this.function.resolve(args[1], ListEntity, "a list") as ListEntity
	if list == null: return
	var item_count := func() -> int: return list.values.size()
	return await __walk(this, var_name, item_count, __list_item.bind(list), list.point_at)


## For Each's loop over what it walks: `count` is how many items there are,
## asked before every pass, `item_at` gives one, and `point_at` shows where the
## loop is, or nowhere for -1. The pointer stays put after an error, so the
## student can see where the loop stopped.
func __walk(this: NestedBlock, var_name: StringName, count: Callable, item_at: Callable, point_at: Callable) -> Variant:
	Interpreter.push_scope("for each " + String(var_name), this.get_instance_id())
	if not Interpreter.declare_var(var_name, null):
		Interpreter.pop_scope()
		this.function.error("Variable '%s' already exists." % var_name)
		return null

	var index := 0
	while index < count.call():
		point_at.call(index)
		Interpreter.assign_var(var_name, item_at.call(index))

		await Interpreter.step(this)
		if Interpreter.interrupted: break

		var outcome := await __run_body(this)
		if Interpreter.interrupted: break
		if outcome == ControlSignal.BREAK: break
		if outcome == ControlSignal.RETURN:
			point_at.call(-1)
			Interpreter.pop_scope()
			return outcome

		index += 1
		if index > Interpreter.MAX_LOOPS:
			this.function.error(MAX_LOOP_ERROR)
			break

	if not Interpreter.interrupted:
		point_at.call(-1)
	Interpreter.pop_scope()
	return null


## Item `i` of `list`, for For Each's variable: a copy, so changing the
## variable doesn't change the list.
func __list_item(i: int, list: ListEntity) -> Variant:
	var item: Variant = list.values[i]
	return item.duplicate(true) if item is Array else item


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


#region Choices
## if {boolean}, and elif {boolean}: whether it ran its body (true also after an
## error, which ends the chain either way), or the ControlSignal its body gave.
func _if(this: NestedBlock) -> Variant:
	await Interpreter.step(this)
	if Interpreter.interrupted: return true

	var args := await this.function.eval_args([this.function.Argument.BOOL])
	if Interpreter.interrupted: return true

	if args[0] as bool:
		var outcome := await __run_body(this)
		if outcome != ControlSignal.NONE:
			return outcome
		return true
	return false


## else. Whether it runs at all is decided by __iterate_children(), from the
## outcome of the blocks before it in the chain.
func _else(this: NestedBlock) -> ControlSignal:
	await Interpreter.step(this)
	if Interpreter.interrupted: return ControlSignal.NONE
	return await __run_body(this)
#endregion


#region Functions
## define <name> ( <params> )
##
## A define block isn't run by Play: it sits on the canvas beside Begin, and
## its blocks run when a call to it does (_call).
func _define(this: NestedBlock) -> void:
	await Interpreter.step(this)


## <name> ( <args> ), as a statement or as a value
##
## Finds the define block of the same name on the canvas, gives each parameter
## its argument's value in a frame of its own, and runs the define's blocks.
## A `return` ends them early and gives the value back; without one the value
## is None, as in Python.
func _call(this: Block) -> Variant:
	var name := String(this.data.func_entity_name)
	var params := this.data.text_hints
	var types: Array[PackedInt32Array] = []
	for i in params.size():
		types.append(this.function.Argument.VARIANT)
	var args := await this.function.eval_args(types)
	if Interpreter.interrupted: return null
	var values: Array = []
	for i in params.size():
		var value: Variant = this.function.unwrap(args[i])
		if Interpreter.interrupted: return null
		if value == null:
			this.function.error("%s( ) needs a value for %s." % [name, params[i]])
			return null
		values.append(value)

	var define := __find_define(this, name)
	if define == null:
		this.function.error("There's no define %s block on the canvas." % name)
		return null

	await Interpreter.step(this)
	if Interpreter.interrupted: return null
	if Interpreter.scopes.size() > Interpreter.MAX_DEPTH:
		this.function.error("%s( ) called itself too many times." % name)
		return null

	Interpreter.push_scope("%s( )" % name, define.get_instance_id(), true)
	for i in params.size():
		Interpreter.declare_var(StringName(params[i]), values[i])
	Interpreter.return_value = null
	var outcome: Variant = await __iterate_children(define)
	Interpreter.pop_scope()
	if Interpreter.interrupted: return null
	if outcome == ControlSignal.BREAK or outcome == ControlSignal.CONTINUE:
		return null
	var result: Variant = Interpreter.return_value
	Interpreter.return_value = null
	# A call used as a statement throws its value away. Handing it on would let
	# a returned number pass for a ControlSignal in the blocks around it.
	return result if this is SocketBlock else null


## return {value}
func _return(this: StatementBlock) -> Variant:
	var args := await this.function.eval_args([this.function.Argument.VARIANT])
	if Interpreter.interrupted: return ControlSignal.NONE

	var in_define := func(block: Block) -> bool:
		return block is NestedBlock and block.data.nested != null and block.data.nested.type == NestedData.Type.FUNCTION
	if this.get_parent_matching(in_define, false) == null:
		this.function.error("Return only works inside a define block.")
		return ControlSignal.NONE

	var value: Variant = this.function.unwrap(args[0]) if args[0] != null else null
	if Interpreter.interrupted: return ControlSignal.NONE
	await Interpreter.step(this)
	Interpreter.return_value = value
	return ControlSignal.RETURN


## The define block on the same canvas as `from_this` with this name.
func __find_define(from_this: Block, name: String) -> NestedBlock:
	var canvas: Node = from_this
	while canvas != null and not (canvas is PuzzleCanvas):
		canvas = canvas.get_parent()
	if canvas == null:
		return null
	for child in canvas.get_children():
		if child is NestedBlock and (child as NestedBlock).is_type(NestedData.Type.FUNCTION) \
				and String((child as NestedBlock).data.func_entity_name) == name:
			return child as NestedBlock
	return null
#endregion


#region Break and continue
## break
func _break(this: StatementBlock) -> ControlSignal:
	await Interpreter.step(this)
	if Interpreter.interrupted: return ControlSignal.NONE
	if not __in_loop(this):
		this.function.error("Can't break from outside a loop.")
		return ControlSignal.NONE
	return ControlSignal.BREAK


## continue
func _continue(this: StatementBlock) -> ControlSignal:
	await Interpreter.step(this)
	if Interpreter.interrupted: return ControlSignal.NONE
	if not __in_loop(this):
		this.function.error("Cannot use 'continue' outside of a loop.")
		return ControlSignal.NONE
	return ControlSignal.CONTINUE


func __in_loop(block: Block) -> bool:
	var is_loop := func(parent: Block) -> bool:
		return parent is NestedBlock and parent.data.nested.type in ITERATIVE_BLOCKS
	return block.get_parent_matching(is_loop, false) != null
#endregion


#region Running a body
## Runs the blocks in `this` mouth in a frame of their own.
func __run_body(this: NestedBlock) -> ControlSignal:
	Interpreter.push_scope(this.text.get_raw(), this.get_instance_id())
	var outcome := await __iterate_children(this)
	Interpreter.pop_scope()
	return outcome


## Runs the blocks in `this` mouth in order, skipping an Else or Elif whose
## chain already ran a branch. Stops at the first ControlSignal a block gives.
func __iterate_children(this: NestedBlock) -> ControlSignal:
	var misplaced := __find_misplaced_branch(this)
	if misplaced != null:
		misplaced.function.error("Invalid 'else' or 'elif' block placement.")
		return ControlSignal.NONE

	var if_chain_succeeded := false
	var blocks := this.get_blocks()

	for i in blocks.size():
		var block := blocks[i]
		if block is NestedBlock:
			if block.is_type(NestedData.Type.ELSE):
				if if_chain_succeeded:
					# Skipped, but it may close the chain: the beat is still due.
					if not __continues_chain(blocks, i + 1):
						await Interpreter.settle()
						if Interpreter.interrupted:
							return ControlSignal.NONE
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

		# A beat after an if or a loop, before whatever comes after it, unless
		# that's the else or elif of the same chain. Without it, what the block
		# looked at (Ahead Is lights the tile it checks) is still showing while
		# the next block moves the robot.
		if block is NestedBlock and not __continues_chain(blocks, i + 1):
			await Interpreter.settle()
			if Interpreter.interrupted:
				return ControlSignal.NONE

	return ControlSignal.NONE


## True when the block at `index` is an else or elif, carrying on the if chain
## before it.
func __continues_chain(blocks: Array, index: int) -> bool:
	if index >= blocks.size() or not blocks[index] is NestedBlock:
		return false
	var next := blocks[index] as NestedBlock
	return next.is_type(NestedData.Type.ELSE) or next.is_type(NestedData.Type.ELIF)


## An Else or Elif that doesn't follow an If or Elif, or null.
func __find_misplaced_branch(this: NestedBlock) -> Block:
	var previous: Block = null
	for block in this.get_blocks():
		if block is NestedBlock and block.is_type(NestedData.Type.ELSE) \
				and not (previous is NestedBlock and previous.is_type(NestedData.Type.IF)):
			return block
		previous = block
	return null


## Whether the slot at `index` in `this` is a typed-in slot left empty.
func __is_blank(this: Block, index: int) -> bool:
	var slots := this.text.get_blocks()
	if index >= slots.size():
		return true
	var slot := slots[index] as ValueBlock
	return slot != null and slot.data.value.editable_shown and slot.line_edit.text.strip_edges().is_empty()
#endregion
