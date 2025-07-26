@tool
class_name ExpressionBlock
extends SocketableBlock


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return (
		super(_at_position, data) and
		data is ExpressionBlock
	)

func _get_block_name() -> String: return "ExpressionBlock"
