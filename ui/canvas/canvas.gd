extends ColorRect


var is_panning = false
var drag_start_position: Vector2
var node_start_position: Vector2

@onready var drop_manager := $DropManager
@onready var audio_stream_player := $AudioStreamPlayer


func _gui_input(event: InputEvent) -> void:
	if drop_manager.is_block_dragging:
		return
	
	# Check is_panning first before checking hovered Control is Canvas
	if not (is_panning or get_viewport().gui_get_hovered_control() == self):
		return
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			is_panning = true
			drag_start_position = get_global_mouse_position()
			node_start_position = position
		else:
			is_panning = false
	elif event is InputEventMouseMotion and is_panning:
		var current_global_mouse = get_global_mouse_position()
		var offset = current_global_mouse - drag_start_position
		position = node_start_position + offset

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return (
		data is Block and
		data.placeable
	)

func _drop_data(at_position: Vector2, data: Variant) -> void:
	# data is Block && data.placeable
	add_child(data)
	data.position = at_position - data.get_center()

func _on_block_dropped() -> void:
	audio_stream_player.play(0.05)
