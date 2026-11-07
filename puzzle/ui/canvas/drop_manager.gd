extends Control
## Where a dragged statement or nested block will attach: a see-through copy of
## it (the drop preview) sits in the mouth it would go into, at the place it
## would take, and the block goes there when it is let go. Slot blocks are
## socket_drop_manager.gd's.

@export var canvas: PuzzleCanvas

## The block being dragged, while it is a statement or nested block.
var _dragged: Block
var _drop_preview: Block
var _drop_container: Container
var _drop_index: int


func _process(_delta: float) -> void:
	if is_instance_valid(_dragged):
		_update_drop_preview()


func _unhandled_input(event: InputEvent) -> void:
	# A copy is dragged with the right button held (BlockDragComponent), but a
	# drag ends on the left button's release, so the right one's ends it too.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		var fake_drop := InputEventMouseButton.new()
		fake_drop.pressed = false
		fake_drop.button_index = MOUSE_BUTTON_LEFT
		Input.parse_input_event(fake_drop)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_DRAG_BEGIN:
			_dragged = null
			var dragged: Variant = get_viewport().gui_get_drag_data()
			# Slot blocks are socket_drop_manager.gd's, and text selected in a
			# chat bubble can be dragged too.
			if not dragged is Block or dragged is SocketBlock:
				return
			_dragged = dragged

			# A copy built from the data rather than duplicated, so every block in
			# it can be marked as a drop preview, which the hover checks look for:
			# the drop preview can itself be under the pointer.
			_drop_preview = Block.construct(_dragged.data)
			_drop_preview.name = "DropPreview_%s" % _drop_preview.name
			_drop_preview.modulate = PuzzleCanvas.drag_preview.modulate
			for block in [_drop_preview] + _drop_preview.find_children("*", "Block", true, false):
				(block as Block).preview_type = Block.PreviewType.DROP

			# A nested block's body is summed up, as in its drag preview.
			if _drop_preview is NestedBlock and not _dragged.get_blocks().is_empty():
				var summary := PuzzleCanvas.drag_preview.mouth.get_child(0) as Block
				_drop_preview.mouth.add_child(summary.duplicate(0))

		NOTIFICATION_DRAG_END:
			if _dragged == null:
				return

			if not _dragged.is_queued_for_deletion():
				_dragged.visible = true
				# The click is for attaching only. Dropping on empty canvas, or
				# letting go where nothing takes the block, makes no sound.
				if _drop_container != null:
					SfxPlayer.play(SfxPlayer.BLOCK_DROP)
					_dragged.orphan()
					_drop_container.add_child(_dragged)
					_drop_container.move_child(_dragged, _drop_index)
					Tutorial.block_placed.emit(_dragged, Core.get_block(_drop_container))

			_drop_preview.queue_free()
			_drop_preview = null
			_drop_container = null
			_dragged = null


## Moves the drop preview to the mouth and place under the pointer, or takes it
## away when there is none, showing the drag preview again.
func _update_drop_preview() -> void:
	if _drop_preview == null:
		return

	var container := _drop_container_under_pointer()
	if container != null:
		var index := _drop_index_in(container)
		PuzzleCanvas.drag_preview.visible = false
		if container != _drop_container:
			if _drop_container != null:
				_drop_container.remove_child(_drop_preview)
			container.add_child(_drop_preview)
			container.move_child(_drop_preview, index)
			_drop_container = container
			_drop_index = index
		elif index != _drop_index:
			_drop_container.move_child(_drop_preview, index)
			_drop_index = index

	elif _drop_container != null:
		if _drop_preview.get_parent() == _drop_container:
			_drop_container.remove_child(_drop_preview)
		_drop_container = null
		PuzzleCanvas.drag_preview.visible = true


## The mouth the dragged block would go into if let go now, or null.
func _drop_container_under_pointer() -> Container:
	if not _dragged.data.top_notch:
		return null

	var mouse_pos := get_global_mouse_position()
	var control := get_viewport().gui_get_hovered_control()
	var hovered_block := Core.get_block(control)
	if hovered_block == null or hovered_block.data.toolbox:
		return null

	hovered_block = hovered_block.get_parent_matching(Block.is_solid)
	if hovered_block == null:
		return null

	# Over the drop preview itself: the mouth it is already in.
	var parent_block := hovered_block.get_parent_block()
	if hovered_block.preview_type == Block.PreviewType.DROP:
		while parent_block.preview_type == Block.PreviewType.DROP:
			parent_block = parent_block.get_parent_block()
		return parent_block.mouth

	# The nested block this one is in, if any.
	while not (parent_block is NestedBlock or parent_block == null):
		parent_block = parent_block.get_parent_block()

	if hovered_block is StatementBlock:
		# Over a statement: the mouth it is in, if the pointer is over that mouth.
		if parent_block != null and parent_block.within_mouth(mouse_pos):
			return parent_block.mouth
		return null

	if hovered_block is NestedBlock:
		# Over a nested block's outer half of a lip: the mouth it is in, beside
		# it. Over its inner half, or its mouth: its own mouth.
		var hovering_above_control := mouse_pos.y < control.global_position.y + control.size.y * 0.5 * canvas.scale.y
		var is_outer_lip := control.name == (NestedBlock.UPPER_LIP_NAME if hovering_above_control else NestedBlock.LOWER_LIP_NAME)
		var is_inner_lip := control.name == (NestedBlock.LOWER_LIP_NAME if hovering_above_control else NestedBlock.UPPER_LIP_NAME)
		if is_outer_lip and parent_block != null and parent_block.within_mouth(mouse_pos):
			return parent_block.mouth
		if is_inner_lip or hovered_block.within_mouth(mouse_pos) or (parent_block == null and hovered_block.is_ancestor_of(control)):
			if hovered_block._can_drop_data(mouse_pos, _dragged):
				return hovered_block.mouth
		return null

	push_error('Unhandled case for drop container! "%s" of Block "%s"' % [control, hovered_block])
	return null


## Where in `container` the dragged block would go: before the first block whose
## middle is below the pointer.
func _drop_index_in(container: Container) -> int:
	var mouse_pos := get_global_mouse_position()
	var index := 0
	for child in container.get_children():
		# The drop preview itself doesn't count, or it would push itself along.
		if not child is Block or child.preview_type == Block.PreviewType.DROP:
			continue
		var center_y: float = child.global_position.y + (child.size.y * canvas.scale.y) * 0.5
		if mouse_pos.y < center_y:
			return index
		index += 1
	return index
