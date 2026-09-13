@tool
extends Goal


@export var required_entity: PhysicsBody2D


func _ready() -> void:
	permanent = true # Latches once touched
	must_maintain = false # Leaving it again is fine
	is_complete = false # Has to be earned
	super()

func _on_entity_entered(body: Node2D) -> void:
	if body == required_entity:
		is_complete = true
