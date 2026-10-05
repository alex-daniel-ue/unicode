class_name PuzzleCanvas
extends ColorRect


signal focus_clicked

static var drag_preview: Block

var is_panning := false
var drag_start_position: Vector2
var node_start_position: Vector2

var zoom_speed := 1.15
var min_zoom := 0.25
var max_zoom := 2.5

@export var serializer: Serializer

var _dragging := false


func _process(_delta: float) -> void:
	# material is ShaderMaterial:
	material.set_shader_parameter("offset", -position / scale)
	if _dragging:
		_update_drag_cursor()

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_DRAG_BEGIN:
			_dragging = true
		NOTIFICATION_DRAG_END:
			_dragging = false
			Input.set_default_cursor_shape(Input.CURSOR_ARROW)

#region Drag cursor
## While a block is dragged, the cursor is a "no" sign wherever letting go would
## do nothing: over the panels, the room, the toolbox, or a block that won't take
## it. Anywhere it can land (empty canvas, a mouth, a slot, the trash) it stays
## an arrow.
func _update_drag_cursor() -> void:
	var data: Variant = get_viewport().gui_get_drag_data()
	if not data is Block:
		return
	# The drop managers hide the drag preview while they show where the block
	# will attach.
	var attaching := is_instance_valid(drag_preview) and not drag_preview.visible
	var lands := attaching or _accepts_drop(get_viewport().gui_get_hovered_control(), data)
	Input.set_default_cursor_shape(Input.CURSOR_ARROW if lands else Input.CURSOR_FORBIDDEN)

## The walk Godot makes to find who takes a drop: up from the hovered control,
## asking each, and stopping at the first that stops the mouse.
func _accepts_drop(control: Control, data: Variant) -> bool:
	var at := get_global_mouse_position()
	while control != null:
		if control.get_script() != null and control.has_method(&"_can_drop_data"):
			var local := control.get_global_transform_with_canvas().affine_inverse() * at
			if control.call(&"_can_drop_data", local, data):
				return true
		if control.mouse_filter == Control.MOUSE_FILTER_STOP:
			return false
		control = control.get_parent() as Control
	return false
#endregion

func _gui_input(event: InputEvent) -> void:
	handle_panning(event)
	handle_zooming(event)

func _can_drop_data(_at_position: Vector2, drop: Variant) -> bool:
	if is_instance_valid(drag_preview):
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
		position = node_start_position + offset

func handle_zooming(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	
	var btn_index := (event as InputEventMouseButton).button_index
	var zoom_in := btn_index == MOUSE_BUTTON_WHEEL_UP
	
	if not (zoom_in or btn_index == MOUSE_BUTTON_WHEEL_DOWN):
		return
	
	var factor := zoom_speed if zoom_in else (1.0 / zoom_speed)
	var new_scale := clampf(scale.x * factor, min_zoom, max_zoom)
	
	if new_scale == scale.x:
		return
	
	var local_mouse := get_local_mouse_position()
	
	var global_mouse_before := get_global_transform() * local_mouse
	scale = Vector2(new_scale, new_scale)
	
	var global_mouse_after := get_global_transform() * local_mouse
	
	global_position += global_mouse_before - global_mouse_after

#region Trash All functionality
func clear() -> void:
	for child in get_children():
		if not child is Block:
			continue
		
		var root := child as Block
		if root.is_pinned():
			_purge(root)
			continue
		
		# A doomed loose stack has no surviving container, so its survivors stay loose.
		var at := root.position
		var rescued := _rescue_from(root)
		_discard(root)
		for survivor in rescued:
			add_child(survivor)
			survivor.size = Vector2.ZERO  # shrink back from the mouth's width
			survivor.position = at
			at.y += survivor.get_combined_minimum_size().y + 16.0
			_purge(survivor)

func _purge(block: Block) -> void:
	for param in block.text.get_blocks():
		if param.is_pinned():
			_purge(param)
		elif param is SocketBlock and (param as SocketBlock).has_overridden():
			_discard(param)  # dropped in; a default slot has nothing behind it and stays
	
	if not block is NestedBlock:
		return
	
	var mouth := (block as NestedBlock).mouth
	for child in (block as NestedBlock).get_blocks():
		if child.is_pinned():
			_purge(child)
			continue
		
		var index := child.get_index()
		var rescued := _rescue_from(child)
		_discard(child)
		
		for survivor in rescued:
			mouth.add_child(survivor)
			mouth.move_child(survivor, index)
			index += 1
			_purge(survivor)

func _rescue_from(doomed: Block) -> Array[Block]:
	var rescued: Array[Block] = []
	if doomed is NestedBlock:
		for child in (doomed as NestedBlock).get_blocks():
			if child.is_pinned():
				child.orphan()
				rescued.append(child)
			else:
				rescued.append_array(_rescue_from(child))
	
	return rescued

func _discard(block: Block) -> void:
	var socket := block as SocketBlock
	if socket != null and socket.has_overridden():
		socket.overridden_socket.visible = true  # the slot gets its default back
		socket.overridden_socket = null
	# Trash all is a trash too. A tutorial step waiting for a block to be thrown
	# away otherwise waits forever once Trash all has taken the block it meant.
	Tutorial.block_trashed.emit(StringName(block.data.name))
	block.orphan()  # out of the tree now, so nothing reads it before the free lands
	block.queue_free()
#endregion
