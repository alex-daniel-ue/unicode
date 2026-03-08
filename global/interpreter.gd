extends Node


signal running_changed

const MAX_DEPTH := 1000
const MAX_LOOPS := 10000
const SLOW_DELAY := 0.5
const FAST_DELAY := 0.15

var is_running := false:
	set(value):
		is_running = value
		running_changed.emit()
		if not is_running:
			interrupted = false

var interrupted := false

var interpret_delay := SLOW_DELAY
var is_fast := false:
	set(value):
		is_fast = value
		interpret_delay = FAST_DELAY if is_fast else SLOW_DELAY

var output_log: Array[String]
var active_errors: Array[Interpreter.Error]


func clear_state() -> void:
	output_log.clear()
	active_errors.clear()

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
