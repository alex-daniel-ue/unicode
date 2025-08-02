extends ColorRect


signal clicked

var is_panning = false
var drag_start_position: Vector2
var node_start_position: Vector2

var zoom_speed := 0.05
var min_zoom := 0.5
var max_zoom := 2.0

var drop_sound := preload("res://puzzle/ui/block/sounds/drop_1.mp3")

@onready var drop_manager := $DropManager as Control
@onready var audio_stream_player := $AudioStreamPlayer as AudioStreamPlayer


func _ready() -> void:
	var viewport_size = get_viewport_rect().size
	pivot_offset = -position + viewport_size / 2

func _gui_input(event: InputEvent) -> void:
	handle_panning(event)
	handle_zooming(event)

func _can_drop_data(_at_position: Vector2, drop: Variant) -> bool:
	Utils.drag_preview_container.scale = scale
	return (
		drop is Block and
		drop.data.placeable
	)

func _drop_data(at_position: Vector2, drop: Variant) -> void:
	# drop is Block && drop.data.placeable
	add_child(drop)
	drop.position = at_position - drop.size / 2.

func handle_panning(event: InputEvent) -> void:
	if drop_manager.is_block_dragging:
		return
	
	# Check is_panning first before checking hovered Control is Canvas
	if not (is_panning or get_viewport().gui_get_hovered_control() == self):
		return
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			clicked.emit()
			get_viewport().gui_release_focus()
			
			is_panning = true
			drag_start_position = get_global_mouse_position()
			node_start_position = position
		else:
			is_panning = false
	
	elif event is InputEventMouseMotion and is_panning:
		var current_global_mouse := get_global_mouse_position()
		var offset := current_global_mouse - drag_start_position
		position = node_start_position + offset / scale
		pivot_offset = -position + get_viewport_rect().size / 2

func handle_zooming(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	
	var zoom_direction := 0
	match event.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			zoom_direction = -1
		MOUSE_BUTTON_WHEEL_DOWN:
			zoom_direction = 1
		_:
			return
	
	scale *= 1 + zoom_direction * zoom_speed
	scale = scale.clampf(min_zoom, max_zoom)

func _on_block_dropped() -> void:
	#var sound := drop_sounds[randi() % len(drop_sounds)]
	audio_stream_player.stream = drop_sound
	audio_stream_player.play(0.05)
