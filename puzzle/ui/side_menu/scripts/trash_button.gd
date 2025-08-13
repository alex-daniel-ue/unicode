extends Button


signal function_trashed(block: Block)

var confirm := (preload("res://puzzle/ui/side_menu/scripts/confirm_popup.tscn")
	.instantiate() as PopupPanel)

@onready var puzzle := $"/root/Puzzle"


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	
	add_child(confirm)
	
	var is_block = func(this: Node) -> bool:
		return this is Block
	var canvas_has_blocks = func() -> bool:
		return not puzzle.canvas.get_children().filter(is_block).is_empty()
	pressed.connect(func() -> void:
		if canvas_has_blocks.call():
			confirm.show()
	)
	
	confirm.confirmed.connect(puzzle.canvas.clear)
	
	#get_viewport().size_changed.connect(_update_position)
	#_update_position()

func _can_drop_data(_at_position: Vector2, drop: Variant) -> bool:
	return (
		drop is Block and
		not (drop is CapBlock and
			drop.check_type(NestedBlockData.Type.BEGIN))
	)

func _drop_data(_at_position: Vector2, drop: Variant) -> void:
	# drop is Block, drop is not CapBlock.BEGIN
	if drop is FunctionBlock:
		function_trashed.emit()
	drop.queue_free()

#func _update_position() -> void:
	#confirm.position = puzzle.camera.get_screen_center_position() - confirm.size / 2.
