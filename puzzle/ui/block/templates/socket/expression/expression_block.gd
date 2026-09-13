class_name ExpressionBlock
extends SocketBlock


func _can_drop_data(_at_position: Vector2, drop: Variant) -> bool:
	if preview_type == Block.PreviewType.DROP:
		return drop is SocketBlock
	return (super(_at_position, drop) and drop is ExpressionBlock)
