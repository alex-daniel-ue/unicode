@tool
extends Goal
 
@export var required_entity: PhysicsBody2D
 
func _ready() -> void:
	# ORDER MATTERS. set_complete() gates on `not permanent or value`, so assigning
	# is_complete = false while permanent is already true is silently dropped — and
	# initial_complete would then record whatever the .tscn happened to hold. Land
	# the starting value first, latch afterwards.
	must_maintain = false
	permanent = false
	is_complete = false
	permanent = true
	super()
 
func needs_detection() -> bool:
	return true
 
func _on_entity_entered(body: Node2D) -> void:
	if body == required_entity:
		is_complete = true
