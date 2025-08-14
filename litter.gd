@tool
class_name Litter
extends Area2D


signal picked_up

const x_offset := 5
const y_offset := 5

@export var litter_offsets: Dictionary[Texture2D, Vector2]
@export var sprite: Sprite2D

func _ready() -> void:
	sprite.flip_h = randi() % 2 == 0
	sprite.flip_v = randi() % 2 == 0
	
	sprite.texture = litter_offsets.keys().pick_random()
	sprite.offset = litter_offsets[sprite.texture] * -Vector2(int(sprite.flip_h), int(sprite.flip_v))
	sprite.position = Vector2(
		randf_range(-x_offset, x_offset),
		randf_range(-y_offset, y_offset),
	)

func pick_up() -> void:
	picked_up.emit()
	visible = false
