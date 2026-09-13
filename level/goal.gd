@tool
class_name Goal
extends Node


@warning_ignore("unused_signal")
signal completion_changed(goal: Goal)

@export var active := true
@export var is_complete: bool:
	set = set_complete
@export var permanent := true # If true, is_complete is "locked" once set to true
@export var must_maintain := false # If true, is_complete must remain true once true
@export var fail_message: String
@export var camera_focus: Node2D

var initial_complete: bool


func _ready() -> void:
	initial_complete = is_complete

func reset() -> void:
	force_complete(initial_complete)

func set_complete(value: bool) -> void:
	if active and (not permanent or value):
		is_complete = value
		completion_changed.emit(self)

# MILD FIXME: Code smell. This dedicated function is necessary to bypass the
# active/permanent checks in the setter. Bypassing couldn't be done cleanly
# because: (1) bound Callables cannot be assigned as setters, (2) setters
# enforce a strict function signature, (3) adding a default 'force' argument to
# the setter causes an infinite loop, and (4) adding an extra class variable
# just for forcing completion feels clunky.
func force_complete(value: bool) -> void:
	var temp := permanent
	permanent = false
	is_complete = value
	permanent = temp

func check_condition() -> bool:
	return is_complete
