class_name Goal
extends Node


@warning_ignore("unused_signal")
signal completion_changed

@export var active := true
@export var is_complete: bool:
	set = set_complete
@export var permanent := true
@export var must_maintain := false
@export var fail_message: String

func set_complete(value: bool) -> void:
	if active and (not permanent or value):
		is_complete = value
		completion_changed.emit()

# MILD FIXME: Code smell. This dedicated function is necessary to bypass the
# active/permanent  checks in the setter. Bypassing couldn't be done cleanly
# because: (1) bound Callables cannot be assigned as setters, (2) setters
# enforce a strict function signature, (3) adding a default 'force' argument to
# the setter causes an infinite loop, and (4) adding an extra class variable
# just for forcing completion feels clunky.
func force_complete(value: bool) -> void:
	var temp := permanent
	permanent = false
	is_complete = value
	permanent = temp
