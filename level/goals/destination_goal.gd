@tool
class_name DestinationGoal
extends Goal
## The green flag: met when the robot ends the run standing on it. A query goal,
## checked once after the run, so it needs no detection_area.

@export var required_entity: PhysicsBody2D
@export var destination_area: Area2D


## Both settings are checked here rather than mid-run: without them the goal
## can't be checked at all, which is an authoring mistake, not a student's.
func _get_configuration_warnings() -> PackedStringArray:
	var warnings := super()
	if destination_area == null:
		warnings.append("No destination_area set, so this goal cannot be checked.")
	if required_entity == null:
		warnings.append("No required_entity set, so this goal can never be satisfied.")
	return warnings


func check_condition() -> bool:
	if destination_area == null or required_entity == null:
		push_error("DestinationGoal '%s' is missing destination_area or required_entity." % name)
		return false
	return destination_area.overlaps_body(required_entity)
