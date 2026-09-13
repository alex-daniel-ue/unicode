@tool
extends Goal


@export var required_entity: PhysicsBody2D
@export var destination_area: Area2D

# Currently bypasses set_complete, therefore Goal.permanent does nothing
func check_condition() -> bool:
	# For a hypothetical CheckpointGoal (where in multiple of that make up a
	# Level such that the Robot must pass through each), Goal.permanent must be
	# used.
	return destination_area.overlaps_body(required_entity)
