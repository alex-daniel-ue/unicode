class_name Canvas
extends ColorRect


const ZOOM_SPEED := Vector2(0.1, 0.1)
const ZOOM_MINIMUM := 0.2


func _process(_delta: float) -> void:
	if Input.is_action_just_released("scroll_up"):
		scale += ZOOM_SPEED
	elif Input.is_action_just_released("scroll_down"):
		scale -= ZOOM_SPEED
	scale = scale.maxf(ZOOM_MINIMUM)
	size = get_parent().size / scale

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	Utils.current_drag_preview_container.scale = scale
	
	return (
		data is Block and
		data.placeable
	)

func _drop_data(at_position: Vector2, data: Variant) -> void:
	# data is Block && data.placeable
	add_child(data)
	data.position = at_position - data.get_center()
