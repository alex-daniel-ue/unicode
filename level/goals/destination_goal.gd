@tool
extends Goal


@export var required_entity: PhysicsBody2D
@export var destination_area: Area2D


## A destination is a query goal, so it has no detection_area and so never got a
## configuration warning. A missing destination_area crashed check_condition()
## mid-run; a missing required_entity failed every run with nothing on screen to
## explain it. Both are author-time mistakes, so they are now reported at author
## time, and the runtime fails the room closed rather than crashing.
func _get_configuration_warnings() -> PackedStringArray:
	var warnings := super()
	if destination_area == null:
		warnings.append("No destination_area set, so this goal cannot be checked.")
	if required_entity == null:
		warnings.append("No required_entity set, so this goal can never be satisfied.")
	return warnings

# Currently bypasses set_complete, therefore Goal.permanent does nothing
func check_condition() -> bool:
	if destination_area == null or required_entity == null:
		push_error("DestinationGoal '%s' is missing destination_area or required_entity." % name)
		return false
	# For a hypothetical CheckpointGoal (where in multiple of that make up a
	# Level such that the Robot must pass through each), Goal.permanent must be
	# used.
	return destination_area.overlaps_body(required_entity)
