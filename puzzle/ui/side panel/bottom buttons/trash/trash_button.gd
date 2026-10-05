extends Button


const TRASH_SOUND := preload("res://audio/block_trash.mp3")

@export var confirm_dialog: PopupPanel

@onready var puzzle := $"/root/Puzzle"

## The block being dragged, kept from the start of the drag: by the time the drag
## ends, the viewport no longer hands it out.
var _dragged: Block


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_DRAG_BEGIN:
			_dragged = get_viewport().gui_get_drag_data() as Block
		NOTIFICATION_DRAG_END:
			var block := _dragged
			_dragged = null
			# Let go over the can, and the can said no: say why, instead of the
			# block just jumping back.
			if is_instance_valid(block) and not block.is_queued_for_deletion() \
					and is_visible_in_tree() and get_global_rect().has_point(get_global_mouse_position()) \
					and not block.is_trashable():
				_refuse(block)

func _can_drop_data(_at_position: Vector2, drop: Variant) -> bool:
	return drop is Block and drop.is_trashable()

func _drop_data(_at_position: Vector2, drop: Variant) -> void:
	# drop is Block, drop is trashable
	SfxPlayer.play(TRASH_SOUND)
	Tutorial.block_trashed.emit(StringName(drop.data.name))
	drop.queue_free()

func _refuse(block: Block) -> void:
	var message := ""
	if not block.data.trashable:
		message = "You can't trash the \"%s\" block." % block.data.display_name()
	else:
		for inner in block.get_all_blocks():
			if not inner.data.trashable:
				message = "You can't trash this. It holds the \"%s\" block, and that block can't be trashed." % inner.data.display_name()
				break
	if not message.is_empty() and puzzle != null:
		puzzle.notif.push(message, Notification.Type.ERROR)

func _on_pressed() -> void:
	# If can actually trash, show dialog
	for child in puzzle.canvas.get_children():
		if child is Block:
			confirm_dialog.show()
			break
