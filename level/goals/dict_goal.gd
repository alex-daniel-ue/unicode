@tool
class_name DictGoal
extends Goal
## A dictionary has to end up holding `expected`, key for key, in any order, as
## Python's == compares two dicts. A query goal, like ListGoal. The rows it
## wants are on the board from the start, faded until the program writes them.

@export var board: DictEntity:
	set(value):
		board = value
		update_configuration_warnings()
		_show_goal()
@export var expected: Dictionary = {}:
	set(value):
		expected = value
		_show_goal()


func _ready() -> void:
	super()
	_show_goal()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := super()
	if board == null:
		warnings.append("No dictionary set, so this goal can't be checked.")
	return warnings


func check_condition() -> bool:
	if board == null:
		push_error("DictGoal '%s' has no board." % name)
		fail_message = "This room isn't set up correctly, so it can't be checked."
		return false
	if board.matches(expected):
		return true
	fail_message = board.mismatch()
	return false


func _show_goal() -> void:
	if board != null and is_inside_tree():
		board.set_target(expected)
