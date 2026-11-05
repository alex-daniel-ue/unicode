@tool
class_name Goal
extends Node
## One thing a room has to end with, held by the room's GoalManager.
##
## Two kinds. A contact goal completes or fails as the robot enters its
## detection_area (a battery, a puddle). A query goal is checked once, after
## the run (the green flag, a list's values): it overrides check_condition().

signal completion_changed(goal: Goal)

@export var active := true
@export var is_complete: bool:
	set = set_complete
## Once complete, stays complete until the room resets.
@export var permanent := true
## Fails the level the moment it stops being complete (a puddle stepped in),
## instead of being checked after the run.
@export var must_maintain := false
@export var fail_message: String
@export var camera_focus: Node2D
## The Area2D whose body_entered drives this goal. Only contact goals need one.
@export var detection_area: Area2D:
	set(value):
		detection_area = value
		update_configuration_warnings()

var initial_complete: bool


func _ready() -> void:
	initial_complete = is_complete
	update_configuration_warnings()

	if Engine.is_editor_hint():
		return
	if detection_area != null and not detection_area.body_entered.is_connected(_on_entity_entered):
		detection_area.body_entered.connect(_on_entity_entered)


func _get_configuration_warnings() -> PackedStringArray:
	if needs_detection() and detection_area == null:
		return ["This goal reacts to contact but has no detection_area, so nothing will ever trigger it."]
	return []


## True for goals that complete or fail on contact. They are the ones that fail
## silently when nothing is wired, so they are the ones that get a warning.
func needs_detection() -> bool:
	return false


func reset() -> void:
	force_complete(initial_complete)


func set_complete(value: bool) -> void:
	if active and (not permanent or value):
		is_complete = value
		completion_changed.emit(self)


## Sets is_complete even when the goal is permanent.
func force_complete(value: bool) -> void:
	var was_permanent := permanent
	permanent = false
	is_complete = value
	permanent = was_permanent


func check_condition() -> bool:
	return is_complete


func _on_entity_entered(_body: Node2D) -> void:
	pass
