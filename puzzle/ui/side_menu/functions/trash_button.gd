extends Button



func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	disabled = true

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Block

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	# data is Block
	data.queue_free()
