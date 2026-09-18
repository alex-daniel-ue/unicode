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

var _focus_tween: Tween

@export var serializer: Serializer


func _ready() -> void:
	Interpreter.block_highlighted.connect(_on_block_highlighted)

func _process(_delta: float) -> void:
	# material is ShaderMaterial:
	material.set_shader_parameter("offset", -position / scale)

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
	block.orphan()  # out of the tree now, so nothing reads it before the free lands
	block.queue_free()
#endregion

func _on_block_highlighted(block: Block) -> void:
	if is_panning:
		return
	
	if not Interpreter.is_running or Interpreter.is_fast:
		return
	
	var screen_center := get_viewport_rect().size / 2.0
	
	var block_center_global := block.global_position + (block.size * scale) / 2.0
	var offset := screen_center - block_center_global
	
	if _focus_tween:
		_focus_tween.kill()
	
	_focus_tween = create_tween()
	_focus_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_focus_tween.tween_property(self, "position", position + offset, 0.25)
