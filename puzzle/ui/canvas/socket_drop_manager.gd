extends Control
## Where a dragged slot block will go: a see-through copy of it (the drop
## preview) stands in the slot under the pointer, hiding the slot, and the block
## takes the slot's place when it is let go. drop_manager.gd does the same for
## statement and nested blocks.

## A slot that would take a block but not this one tints the drag preview this.
const REFUSED_TINT := Color(1.0, 0.45, 0.45, 1.0)

var _dragged: SocketBlock
var _drop_preview: SocketBlock
## The slot the drop preview stands in now.
var _target: SocketBlock
var _preview_modulate := Color.WHITE


func _process(_delta: float) -> void:
	if _dragged == null:
		return

	var slot := _slot_under_pointer()
	PuzzleCanvas.drag_preview.visible = slot == null
	var refusing := slot == null and _is_over_refusing_slot()
	PuzzleCanvas.drag_preview.modulate = (_preview_modulate * REFUSED_TINT) if refusing else _preview_modulate

	if slot != null:
		if slot != _target:
			# The drop preview stands in the slot, as the block will.
			var container := slot.get_parent()
			var index := slot.get_index()
			_drop_preview.orphan()
			container.add_child(_drop_preview)
			container.move_child(_drop_preview, index)
			slot.visible = false
			if _target != null:
				_target.visible = true
			_drop_preview.overridden_socket = slot
	elif _target != null:
		_target.visible = true
		_drop_preview.orphan()
		if _drop_preview.has_overridden():
			_drop_preview.overridden_socket = null

	_target = slot


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_DRAG_BEGIN:
			var drag_data: Variant = get_viewport().gui_get_drag_data()
			if not drag_data is SocketBlock:
				_dragged = null
				return

			_dragged = drag_data
			_preview_modulate = PuzzleCanvas.drag_preview.modulate

			_drop_preview = Block.construct(_dragged.data)
			_drop_preview.name = "DropPreview_%s" % _drop_preview.name
			_drop_preview.modulate = PuzzleCanvas.drag_preview.modulate
			# An entity block's preview talks to the same entity.
			if _dragged.data.func_type == BlockData.FuncType.ENTITY:
				_drop_preview.function.object = _dragged.function.object
			for block in [_drop_preview] + _drop_preview.find_children("*", "Block", true, false):
				(block as Block).preview_type = Block.PreviewType.DROP

		NOTIFICATION_DRAG_END:
			if _dragged == null:
				return

			# Thrown in the trash: the slot it was in gets its default back.
			if _dragged.is_queued_for_deletion():
				if _dragged.has_overridden():
					_dragged.overridden_socket.visible = true
					_dragged.overridden_socket = null
				if _drop_preview != null:
					_drop_preview.queue_free()
					_drop_preview = null
				_target = null
				_dragged = null
				return

			_dragged.visible = true
			var dropped := _target != null
			var left_slot := dropped or _dragged.get_parent() is PuzzleCanvas
			if _dragged.has_overridden():
				if left_slot:
					_dragged.overridden_socket = null
				else:
					_dragged.overridden_socket.visible = false

			if _target != null:
				SfxPlayer.play(SfxPlayer.BLOCK_DROP)
				var container := _target.get_parent()
				var index := _target.get_index()
				_target.visible = false
				_dragged.orphan()
				container.add_child(_dragged)
				container.move_child(_dragged, index)
				_dragged.overridden_socket = _target

			if _drop_preview != null:
				_drop_preview.queue_free()
				_drop_preview = null
			_target = null
			_dragged = null


## The slot the dragged block would go into if let go now, or null.
func _slot_under_pointer() -> SocketBlock:
	var control := get_viewport().gui_get_hovered_control()
	if control == null:
		return null

	# Anywhere over the drop preview, or anything in it, keeps the slot it is in.
	if _target != null and is_instance_valid(_drop_preview) and _drop_preview.is_inside_tree():
		if control == _drop_preview or _drop_preview.is_ancestor_of(control):
			return _target

	var block := Core.get_block(control)
	if block == null or not block is SocketBlock or block.data.toolbox:
		return null

	# Over the drop preview, or a block inside it: the same slot.
	if block.preview_type == Block.PreviewType.DROP:
		return _target
	var in_preview := block.get_parent_matching(func(b: Block) -> bool: return b.preview_type == Block.PreviewType.DROP)
	if in_preview != null:
		return _target

	if not block._can_drop_data(Vector2.ZERO, _dragged):
		return null
	return block as SocketBlock


## True when the pointer is over a slot that could have taken a block but
## refuses this one. Empty canvas isn't a refusal and doesn't look like one;
## _slot_under_pointer() gives null for both, so it can't tell them apart.
func _is_over_refusing_slot() -> bool:
	var block := Core.get_block(get_viewport().gui_get_hovered_control())
	if block == null or not (block is SocketBlock):
		return false
	if block.data.socket == null or not block.data.socket.receptive:
		return false
	return not block._can_drop_data(Vector2.ZERO, _dragged)
