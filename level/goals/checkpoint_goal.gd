@tool
class_name CheckpointGoal
extends Goal
## A battery to collect: done once the robot has passed over it. The battery pops
## and fades when picked up, and comes back when the room resets.

const PICKUP_TIME := 0.25
const COLLECTED_ALPHA := 0.0

@export var required_entity: PhysicsBody2D

## The battery drawn on detection_area, and its look before it was collected.
var _sprite: CanvasItem
var _rest_scale := Vector2.ONE
var _tween: Tween


func _ready() -> void:
	# The starting value lands before permanent latches: set_complete() drops
	# `is_complete = false` while permanent is true, and initial_complete would
	# then keep whatever the scene file held.
	must_maintain = false
	permanent = false
	is_complete = false
	permanent = true
	super()
	if Engine.is_editor_hint() or detection_area == null:
		return
	_sprite = detection_area.get_node_or_null(^"Sprite") as CanvasItem
	if _sprite is Node2D:
		_rest_scale = (_sprite as Node2D).scale
	completion_changed.connect(_on_completion_changed)


func needs_detection() -> bool:
	return true


func _on_entity_entered(body: Node2D) -> void:
	if body == required_entity:
		is_complete = true


func _on_completion_changed(_goal: Goal) -> void:
	if _sprite == null:
		return
	if _tween != null:
		_tween.kill()
	if is_complete:
		_tween = _sprite.create_tween().set_parallel()
		_tween.tween_property(_sprite, "modulate:a", COLLECTED_ALPHA, PICKUP_TIME)
		if _sprite is Node2D:
			_tween.tween_property(_sprite, "scale", _rest_scale * 1.6, PICKUP_TIME) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		_sprite.modulate.a = 1.0
		if _sprite is Node2D:
			(_sprite as Node2D).scale = _rest_scale
