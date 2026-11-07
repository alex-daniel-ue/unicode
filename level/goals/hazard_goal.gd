@tool
class_name HazardGoal
extends Goal
## A puddle: met while the robot has never entered it. Stepping in fails the
## level at once (must_maintain), rather than at the end of the run.

@export var required_entity: PhysicsBody2D


func _ready() -> void:
	permanent = false
	must_maintain = true
	is_complete = true
	super()


func needs_detection() -> bool:
	return true


func _on_entity_entered(body: Node2D) -> void:
	if body == required_entity:
		is_complete = false
