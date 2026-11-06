extends Node
## The state of the program being run: whether it runs, is paused or was
## stopped; how long each step lasts; its variables, in frames; its errors and
## what it printed.
##
## Blocks run themselves (BlockFunctionComponent, puzzle/functions/), each one
## awaiting step() before it acts, so a run can pause, stop and show every step.

signal running_changed
signal paused_changed
signal block_highlighted(block: Block)
signal scope_changed
## A parameter block was just evaluated to `value`: a literal, a variable's name,
## or what a reporter block worked out. The value tags show it on the block.
signal value_shown(block: Block, value: Variant)
## A parameter wasn't evaluated this time: the right side of an and/or whose left
## side already decided the answer.
signal value_skipped(block: Block)
## `block` is evaluating its parameters again, so what its parameters showed the
## last time is out of date.
signal values_cleared(block: Block)
signal error_raised(error: BlockError)
signal output_logged(line: String)

const MAX_DEPTH := 1000
const MAX_LOOPS := 10000
## Seconds a step lasts at normal speed. Fast mode starts at FAST_DELAY and
## shortens each step by RAMP, down to MIN_DELAY, so a long run speeds up.
const SLOW_DELAY := 0.7
const FAST_DELAY := 0.2
const MIN_DELAY := 0.02
const RAMP := 0.99

var is_running := false:
	set(value):
		is_running = value
		running_changed.emit()
		if not is_running:
			is_paused = false
			interrupted = false
var is_paused := false:
	set(value):
		if is_paused != value:
			is_paused = value
			paused_changed.emit()
## Set by Stop, an error or a failed goal: every block that is waiting returns
## as soon as it wakes. The frames are frozen first, so the Variables tab can
## show the values at that moment.
var interrupted := false:
	set(value):
		if value and not interrupted and scopes.size() > 1:
			_freeze_scopes()
		interrupted = value
var is_fast := false
var current_delay: float:
	get:
		return maxf(MIN_DELAY, FAST_DELAY * pow(RAMP, _steps)) if is_fast else SLOW_DELAY
var output_log: Array[String]
## What the last `return` gave, for the call that is waiting for it.
var return_value: Variant = null
var active_errors: Array[BlockError]
var scopes: Array[Frame]
var frozen_scopes: Array[Frame]

var _steps := 0


## Lights `block` up and waits one step, sounding a pulse.
func step(block: Block) -> void:
	block.visual.pulse(maxf(current_delay, BlockVisualComponent.PULSE_DURATION))
	SfxPlayer.play_pulse()
	_steps = (_steps + 1) if is_fast else 0
	await Game.sleep(current_delay)


## A beat with nothing lit, after a nested block (an if, a loop) is done and
## before the block under it, and at the end of the program: one step's delay,
## not counted as a step.
func settle() -> void:
	await Game.sleep(current_delay)


func clear_state() -> void:
	output_log.clear()
	active_errors.clear()
	clear_scopes()
	_steps = 0


#region Scopes
func push_scope(label: String, owner_id: int, is_function := false) -> void:
	var frame := Frame.new(label, owner_id)
	frame.is_function = is_function
	scopes.append(frame)
	scope_changed.emit()


func pop_scope() -> void:
	if scopes.size() > 1:
		scopes.pop_back()
	scope_changed.emit()


func clear_scopes() -> void:
	scopes.clear()
	frozen_scopes.clear()
	scope_changed.emit()


## Innermost frame already holding `var_name`, or null. A function's frames end
## at its call: past that, only the program's own first frame is seen, as a
## Python function sees its local names and the module's, not its caller's.
func find_frame(var_name: StringName) -> Frame:
	for i in range(scopes.size() - 1, -1, -1):
		if scopes[i].vars.has(var_name):
			return scopes[i]
		if scopes[i].is_function:
			return scopes[0] if i > 0 and scopes[0].vars.has(var_name) else null
	return null


func has_var(var_name: StringName) -> bool:
	return find_frame(var_name) != null


func read_var(var_name: StringName) -> Variant:
	var frame := find_frame(var_name)
	return frame.vars[var_name] if frame != null else null


## Writes to the frame the name was found in. False when it isn't declared
## anywhere, for the caller to raise as the block's error.
func assign_var(var_name: StringName, value: Variant) -> bool:
	var frame := find_frame(var_name)
	if frame == null:
		return false
	frame.vars[var_name] = value
	scope_changed.emit()
	return true


## Writes to the innermost frame. False when the name is already visible, so a
## loop can't quietly shadow a variable of the same name.
func declare_var(var_name: StringName, value: Variant) -> bool:
	if scopes.is_empty() or find_frame(var_name) != null:
		return false
	scopes.back().vars[var_name] = value
	scope_changed.emit()
	return true


## Every visible variable, the innermost frame winning, for an error's snapshot.
func flatten_scopes() -> Dictionary[StringName, Variant]:
	var result: Dictionary[StringName, Variant] = {}
	for frame in scopes:
		for var_name in frame.vars:
			result[var_name] = frame.vars[var_name]
	return result


func _freeze_scopes() -> void:
	frozen_scopes = scopes.duplicate()
#endregion


## The variables a block that opens a body (a loop, a call) can see and make.
class Frame:
	var label: String
	var owner_id: int
	## The frame a function call opens: names below it are the caller's.
	var is_function := false
	var vars: Dictionary[StringName, Variant]

	func _init(frame_label: String, frame_owner_id: int) -> void:
		label = frame_label
		owner_id = frame_owner_id


## What went wrong in a run: the message the student reads, the block that
## raised it, the blocks around it and the variables at that moment.
class BlockError:
	var message: String
	var block: Block
	var block_text: String
	var stack_trace: PackedStringArray
	var scope: Dictionary[StringName, Variant]

	func _init(
		msg: String,
		failing_block: Block,
		trace: PackedStringArray,
		vars: Dictionary[StringName, Variant]
	) -> void:
		message = msg
		block = failing_block
		block_text = failing_block.text.get_raw()
		stack_trace = trace
		scope = vars

	func _to_string() -> String:
		return """[ERROR]: {msg}, from "{raw_block}\"
		Stack trace: {trace}
		Stack variables: {vars}""".format({
			msg = message,
			raw_block = block_text,
			trace = " > ".join(stack_trace),
			vars = str(scope),
		})
