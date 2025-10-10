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

# MILD FIXME: Code smell. This function was made necessary because (1) you can't
# 	assign a bound Callable as a setter, (2) you must have the exact function
#	signature for the setter, (3) making the setter be an overloaded setter with
#	default false `force` will result in an infinite loop, and (4) I don't want to
#	add another variable for forcing completion.
func force_complete(value: bool) -> void:
	var temp := permanent
	permanent = false
	is_complete = value
	permanent = temp
