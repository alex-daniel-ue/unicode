@tool
class_name FileGoal
extends Goal
## A file has to end up holding `expected`, line for line. A query goal, like
## TerminalGoal; the lines it wants are on the file from the start, faded.

@export var file: FileEntity:
	set(value):
		file = value
		update_configuration_warnings()
		_show_goal()
@export var expected: PackedStringArray = []:
	set(value):
		expected = value
		_show_goal()


func _ready() -> void:
	super()
	_show_goal()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := super()
	if file == null:
		warnings.append("No file set, so this goal can't be checked.")
	return warnings


func check_condition() -> bool:
	if file == null:
		push_error("FileGoal '%s' has no file." % name)
		fail_message = "This room isn't set up correctly, so it can't be checked."
		return false
	if file.matches(expected):
		return true
	fail_message = file.mismatch()
	return false


func _show_goal() -> void:
	if file != null and is_inside_tree():
		file.set_target(expected)
