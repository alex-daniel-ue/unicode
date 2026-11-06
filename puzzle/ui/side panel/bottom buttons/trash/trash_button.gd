extends Button
## The trash can: a block dropped on it is thrown away, and pressing it asks
## whether to throw away everything (Trash all, PuzzleCanvas.clear()). A block
## the level placed is refused, and the can says why.

@export var confirm_dialog: PopupPanel

## The block being dragged, kept from the start of the drag: by the time the drag
## ends, the viewport no longer hands it out.
var _dragged: Block

@onready var puzzle := owner as Puzzle


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_DRAG_BEGIN:
			# Text selected in a chat bubble can be dragged too.
			var dragged: Variant = get_viewport().gui_get_drag_data()
			_dragged = dragged if dragged is Block else null
		NOTIFICATION_DRAG_END:
			var block := _dragged
			_dragged = null
			if not is_instance_valid(block) or block.is_queued_for_deletion():
				return
			var at := get_global_mouse_position()
			# Let go over the can, and the can said no: say why, instead of the
			# block just jumping back.
			if is_visible_in_tree() and get_global_rect().has_point(at):
				if not block.is_trashable():
					_refuse(block)
			# Put back in the toolbox: thrown away the same way, or refused the same way.
			elif puzzle != null and puzzle.returns_to_toolbox(block, at) \
					and not get_viewport().gui_is_drag_successful():
				if block.is_trashable():
					_drop_data(Vector2.ZERO, block)
				else:
					_refuse(block)


func _can_drop_data(_at_position: Vector2, drop: Variant) -> bool:
	return drop is Block and drop.is_trashable()


func _drop_data(_at_position: Vector2, drop: Variant) -> void:
	SfxPlayer.play(SfxPlayer.BLOCK_TRASH)
	Tutorial.block_trashed.emit(StringName(drop.data.name))
	drop.queue_free()


func _refuse(block: Block) -> void:
	var message := ""
	if not block.data.trashable:
		message = "You can't trash the %s block." % block.data.display_name()
	else:
		for inner in block.get_all_blocks():
			if not inner.data.trashable:
				message = "You can't trash this. It holds the %s block, and that block can't be trashed." % inner.data.display_name()
				break
	if not message.is_empty() and puzzle != null:
		puzzle.notifications.push(message, Notification.Type.ERROR)


## Asks before Trash all, when there is anything on the canvas to trash.
func _on_pressed() -> void:
	for child in puzzle.canvas.get_children():
		if child is Block:
			confirm_dialog.show()
			break
