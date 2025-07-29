@tool
class_name ExpressionBlock
extends SocketBlock


func _can_drop_data(_at_position: Vector2, drop: Variant) -> bool:
	return (
		super(_at_position, drop) and
		drop is ExpressionBlock
	)
