@tool
extends Goal


@export var required_entity: PhysicsBody2D


func _ready() -> void:
	permanent = false # Must stay off the hazard to stay true
	must_maintain = true # Must not become false after being true
	is_complete = true # Completed by default
	super()

func _on_entity_entered(body: Node2D) -> void:
	if body == required_entity:
		is_complete = false
