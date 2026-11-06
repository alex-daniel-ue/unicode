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

## Loose blocks keep this far apart, in canvas pixels (see _separate()).
const SEPARATION_GAP := 16.0
## How quickly an overlap closes: the share of it closed each second.
const SEPARATION_SPEED := 9.0

var _dragging := false


func _process(delta: float) -> void:
	# The grid needs nothing from here: canvas_bg.gdshader draws it in the
	# canvas's own coordinates, so it pans and zooms with the blocks.
	if _dragging:
		_update_drag_cursor()
	elif not Interpreter.is_running:
		_separate(delta)

#region Separation
## Loose blocks that overlap drift apart until there's a small gap between
## them. A block dropped where it can't attach used to land on top of another
## and sit there looking attached, and students built on it; drifting off says
## it isn't part of anything. Begin and any block that can't be dragged hold
## still, and the loose block moves all the way. Only overlaps push, so once
## nothing overlaps nothing moves: this is not a field that keeps blocks
## sliding about.
func _separate(delta: float) -> void:
	var stacks: Array[Block] = []
	for child in get_children():
		if child is Block and (child as Block).visible and not (child as Block).display:
			stacks.append(child as Block)
	if stacks.size() < 2:
		return
	var pushes: Dictionary[Block, Vector2] = {}
	for i in stacks.size():
		for j in range(i + 1, stacks.size()):
			var a := stacks[i]
			var b := stacks[j]
			var a_fixed := _anchored(a)
			var b_fixed := _anchored(b)
			if a_fixed and b_fixed:
				continue
			var ra := a.get_rect().grow(SEPARATION_GAP / 2.0)
			var rb := b.get_rect().grow(SEPARATION_GAP / 2.0)
			if not ra.intersects(rb):
				continue
			# Out along the shorter way: a block dropped across a tall stack
			# slides off its side, not all the way down its length.
			var overlap := ra.intersection(rb)
			var away := ra.get_center() - rb.get_center()
			var push := Vector2(overlap.size.x * (1.0 if away.x >= 0.0 else -1.0), 0.0) 				if overlap.size.x < overlap.size.y 				else Vector2(0.0, overlap.size.y * (1.0 if away.y >= 0.0 else -1.0))
			if a_fixed:
				pushes[b] = pushes.get(b, Vector2.ZERO) - push
			elif b_fixed:
				pushes[a] = pushes.get(a, Vector2.ZERO) + push
			else:
				pushes[a] = pushes.get(a, Vector2.ZERO) + push / 2.0
				pushes[b] = pushes.get(b, Vector2.ZERO) - push / 2.0
	var share := minf(1.0, delta * SEPARATION_SPEED)
	for block: Block in pushes:
		var push: Vector2 = pushes[block]
		# The last pixel in one go, so the block comes to rest.
		block.position += push if push.length() < 1.0 else push * share

## Blocks that hold still while others make room: Begin, and anything the
## level placed that can't be dragged.
func _anchored(block: Block) -> bool:
	return block is CapBlock or not block.data.draggable
#endregion

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_DRAG_BEGIN:
			_dragging = true
		NOTIFICATION_DRAG_END:
			_dragging = false
			Input.set_default_cursor_shape(Input.CURSOR_ARROW)

#region Drag cursor
## While a block is dragged, the cursor is a "no" sign wherever letting go would
## do nothing: over the panels, the room, or a block that won't take it.
## Anywhere it can land (empty canvas, a mouth, a slot, the trash, or the
## toolbox for a block from the canvas, which throws it away) it stays an arrow.
func _update_drag_cursor() -> void:
	var data: Variant = get_viewport().gui_get_drag_data()
	if not data is Block:
		return
	# The drop managers hide the drag preview while they show where the block
	# will attach.
	var attaching := is_instance_valid(drag_preview) and not drag_preview.visible
	var lands := attaching or _accepts_drop(get_viewport().gui_get_hovered_control(), data) \
		or (owner is Puzzle and (owner as Puzzle).returns_to_toolbox(data, get_global_mouse_position()))
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
	if event.is_action_pressed("pan"):
		if not _pans_from_here(event):
			return
		if has_focus():
			focus_clicked.emit()
		get_viewport().gui_release_focus()

		is_panning = true
		drag_start_position = get_global_mouse_position()
		node_start_position = position
	elif not is_panning:
		return
	elif event.is_action_released("pan"):
		is_panning = false

	elif event is InputEventMouseMotion:
		var current_global_mouse := get_global_mouse_position()
		var offset := current_global_mouse - drag_start_position
		position = node_start_position + offset

## Whether a press of a pan button, which has reached the canvas, pans it. On
## the canvas itself it does, and in a block's box where the block isn't drawn
## (beside narrower blocks under it, inside a loop), which is canvas as far as
## a student can see. The middle button pans over blocks too: nothing else uses
## it. A left press on a block is that block's, to pick it up.
func _pans_from_here(event: InputEvent) -> bool:
	var hovered := get_viewport().gui_get_hovered_control()
	if hovered == self:
		return true
	if hovered == null or not is_ancestor_of(hovered):
		return false
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_MIDDLE:
		return true
	var at := get_global_mouse_position()
	var node: Node = hovered
	while node != self:
		if node is Block and (node as Block).shows_at(at):
			return false
		node = node.get_parent()
	return true

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
	if block is SocketBlock:
		(block as SocketBlock).release_slot()  # the slot gets its default back
	# Trash all is a trash too. A tutorial step waiting for a block to be thrown
	# away otherwise waits forever once Trash all has taken the block it meant.
	Tutorial.block_trashed.emit(StringName(block.data.name))
	block.orphan()  # out of the tree now, so nothing reads it before the free lands
	block.queue_free()
#endregion
