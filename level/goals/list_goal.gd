@tool
class_name ListGoal
extends Goal

## A list has to end up holding `expected` when the program finishes. A query
## goal, like DestinationGoal: checked once, after the run.
##
## The fail message is built from both lists, because Level.fail() puts it in the
## output log and that's what the assistant reads. An authored fail_message, if
## any, goes in front of it.

@export var list: ListEntity:
	set(value):
		list = value
		update_configuration_warnings()
@export var expected: Array = []

var _authored_message := ""


func _ready() -> void:
	_authored_message = fail_message
	super()

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := super()
	if list == null:
		warnings.append("No list set, so this goal can't be checked.")
	return warnings

func check_condition() -> bool:
	if list == null:
		push_error("ListGoal '%s' has no list." % name)
		fail_message = "This room isn't set up correctly, so it can't be checked."
		return false

	if list.matches(expected):
		return true

	var detail := "'%s' should end up as %s, but it's %s." % [list.get_list_name(), list.repr_of(_expected_as_shown()), list.repr()]
	fail_message = detail if _authored_message.is_empty() else _authored_message + " " + detail
	return false

func _expected_as_shown() -> Array:
	return ListEntity.normalized(expected) if list.kind == ListEntity.Kind.SET else expected
