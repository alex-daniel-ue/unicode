@tool
extends Goal
 
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
