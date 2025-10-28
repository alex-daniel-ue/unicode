class_name PuzzleCanvas
extends ColorRect


signal focus_clicked

static var drag_preview: Block

var is_panning := false
var drag_start_position: Vector2
var node_start_position: Vector2

var zoom_speed := 0.05
var min_zoom := 0.5
var max_zoom := 2.0

@export var serializer: Node
@export var drop_manager: Control
#@onready var audio_stream_player := $AudioStreamPlayer as AudioStreamPlayer

func _ready() -> void:
	var viewport_size := get_viewport_rect().size
	pivot_offset = -position + viewport_size / 2

func _gui_input(event: InputEvent) -> void:
	handle_panning(event)
	handle_zooming(event)

func _can_drop_data(_at_position: Vector2, drop: Variant) -> bool:
	drag_preview.scale = scale
	return (
		drop is Block and
		drop.data.placeable
	)

func _drop_data(at_position: Vector2, drop: Variant) -> void:
	# drop is Block && drop.data.placeable
	drop.orphan()
	add_child(drop)
	drop.position = at_position - drag_preview.size / 2.

func handle_panning(event: InputEvent) -> void:
	# Check is_panning first before checking hovered Control is Canvas
	if not (is_panning or get_viewport().gui_get_hovered_control() == self):
		return
	
	if event.is_action_pressed("pan"):
		if has_focus():
			focus_clicked.emit()
		get_viewport().gui_release_focus()
		
		is_panning = true
		drag_start_position = get_global_mouse_position()
		node_start_position = position
	elif event.is_action_released("pan"):
		is_panning = false
	
	elif event is InputEventMouseMotion and is_panning:
		var current_global_mouse := get_global_mouse_position()
		var offset := current_global_mouse - drag_start_position
		position = node_start_position + offset / scale
		pivot_offset = -position + get_viewport_rect().size / 2

func handle_zooming(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	
	var zoom_amount := zoom_speed
	if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		zoom_amount *= -1
	elif event.button_index != MOUSE_BUTTON_WHEEL_UP:
		return
	
	var new_scale := scale.x + zoom_amount
	if min_zoom < new_scale and new_scale < max_zoom:
		scale = Vector2(new_scale, new_scale)

func clear() -> void:
	for child in get_children():
		if not child is Block:
			continue
		
		if not child is CapBlock:
			child.queue_free()
			continue
		
		for inner_block in child.get_blocks():
			inner_block.queue_free()
