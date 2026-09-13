extends Node


signal running_changed
signal block_highlighted(block: Block)
signal scope_changed

const MAX_DEPTH := 1000
const MAX_LOOPS := 10000
const SLOW_DELAY := 0.7
const FAST_DELAY := 0.2

const MIN_DELAY := 1./144
const RAMP := 0.99
var steps := 0


var is_running := false:
	set(value):
		is_running = value
		running_changed.emit()
		if not is_running:
			interrupted = false
var interrupted := false:
	set(value):
		if value and not interrupted and scopes.size() > 1:
			freeze_scopes()
		interrupted = value

var current_delay := SLOW_DELAY:
	get:
		current_delay = maxf(MIN_DELAY, FAST_DELAY * pow(RAMP, steps)) if is_fast else SLOW_DELAY
		return current_delay
var is_fast := false

var output_log: Array[String]
var active_errors: Array[Interpreter.Error]
var scopes: Array[Frame]
var frozen_scopes: Array[Frame]


func step(block: Block) -> void:
	block.visual.pulse()
	steps = (steps + 1) if is_fast else 0
	await Game.sleep(current_delay)

func clear_state() -> void:
	output_log.clear()
	active_errors.clear()
	clear_scopes()
	steps = 0

#region Scope stack
func push_scope(label: String, owner_id: int) -> void:
	scopes.append(Frame.new(label, owner_id))
	scope_changed.emit()

func pop_scope() -> void:
	if scopes.size() > 1:
		scopes.pop_back()
	scope_changed.emit()

func clear_scopes() -> void:
	scopes.clear()
	frozen_scopes.clear()
	scope_changed.emit()

## Innermost frame already holding `name`, or null.
func find_frame(var_name: StringName) -> Frame:
	for i in range(scopes.size() - 1, -1, -1):
		if scopes[i].vars.has(var_name):
			return scopes[i]
	return null

func has_var(var_name: StringName) -> bool:
	return find_frame(var_name) != null

func read_var(var_name: StringName) -> Variant:
	var frame := find_frame(var_name)
	return frame.vars[var_name] if frame != null else null

## Writes to the frame the name was found in.
## False if it isn't declared anywhere — caller should raise a block error.
func assign_var(var_name: StringName, value: Variant) -> bool:
	var frame := find_frame(var_name)
	if frame == null:
		return false
	frame.vars[var_name] = value
	scope_changed.emit()
	return true

## Writes to the innermost frame.
## False if the name is already visible — that's the shadowing catch.
func declare_var(var_name: StringName, value: Variant) -> bool:
	if scopes.is_empty() or find_frame(var_name) != null:
		return false
	scopes.back().vars[var_name] = value
	scope_changed.emit()
	return true

## Innermost-wins flattened view. For the watcher and for error snapshots.
func flatten_scopes() -> Dictionary[StringName, Variant]:
	var result: Dictionary[StringName, Variant] = {}
	for frame in scopes:
		for var_name in frame.vars:
			result[var_name] = frame.vars[var_name]
	return result

func freeze_scopes() -> void:
	frozen_scopes = scopes.duplicate()
#endregion

class Frame:
	var label: String
	var owner_id: int
	var vars: Dictionary[StringName, Variant]
	
	func _init(frame_label: String, frame_owner_id: int) -> void:
		label = frame_label
		owner_id = frame_owner_id

class Error:
	var message: String
	var block: Block
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
		stack_trace = trace
		scope = vars
	
	func _to_string() -> String:
		return """[ERROR]: {msg}, from "{raw_block}\"
		Stack trace: {trace}
		Stack variables: {vars}""".format({
			msg = message,
			raw_block = block.text.get_raw(),
			trace = " > ".join(stack_trace),
			vars = str(scope)
		})
