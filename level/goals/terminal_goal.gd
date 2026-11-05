@tool
class_name TerminalGoal
extends Goal

## A terminal has to end up showing `expected`, line for line, when the program
## finishes. A query goal, like ListGoal: checked once, after the run. Only what
## the program printed counts; what the user typed is shown under the screen,
## not on it.
##
## The lines are also shown on the screen, faded, in their places, so what the
## room wants is on screen the way a flag is.

@export var terminal: TerminalEntity:
	set(value):
		terminal = value
		update_configuration_warnings()
		_show_goal()
@export var expected: PackedStringArray = []:
	set(value):
		expected = value
		_show_goal()

var _authored_message := ""


func _ready() -> void:
	_authored_message = fail_message
	super()
	_show_goal()

func _show_goal() -> void:
	if terminal != null and is_inside_tree():
		terminal.set_target(expected)

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := super()
	if terminal == null:
		warnings.append("No terminal set, so this goal can't be checked.")
	return warnings

func check_condition() -> bool:
	if terminal == null:
		push_error("TerminalGoal '%s' has no terminal." % name)
		fail_message = "This room isn't set up correctly, so it can't be checked."
		return false
	if terminal.matches(expected):
		return true
	var detail := terminal.mismatch()
	fail_message = detail if _authored_message.is_empty() else _authored_message + " " + detail
	return false
