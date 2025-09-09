extends Button


@export var confirm_dialog: PopupPanel
@onready var puzzle := $"/root/Puzzle"


func _can_drop_data(_at_position: Vector2, drop: Variant) -> bool:
	return (
		drop is Block and
		not (drop is CapBlock and drop.is_type(NestedData.Type.BEGIN))
	)

func _drop_data(_at_position: Vector2, drop: Variant) -> void:
	# drop is Block, drop is not CapBlock.BEGIN
	drop.queue_free()

func _on_pressed() -> void:
	for child in puzzle.canvas.get_children():
		if child is Block:
			confirm_dialog.show()
			break
