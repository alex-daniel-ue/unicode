extends Goal


@export var required_entity: PhysicsBody2D


func _on_entity_entered(body: Node2D) -> void:
	if body == required_entity:
		is_complete = true

func _on_entity_exited(body: Node2D) -> void:
	if body == required_entity:
		is_complete = false
