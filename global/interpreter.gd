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
