class_name Goal
extends Node


@warning_ignore("unused_signal")
signal completion_changed

@export var is_complete: bool:
	set(value):
		is_complete = value
		completion_changed.emit()
@export var must_maintain := false
@export var fail_warning: String
