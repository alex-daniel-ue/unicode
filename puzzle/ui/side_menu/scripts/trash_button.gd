extends Button


signal function_trashed(block: Block)


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	disabled = true

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
