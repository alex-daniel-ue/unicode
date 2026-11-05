class_name ExpressionBlock
extends SocketBlock
## A six-sided block that gives True or False: Ahead Is, Compare, Not, And/Or,
## In. Its slot takes only another expression block.


func _can_drop_data(at_position: Vector2, drop: Variant) -> bool:
	if preview_type == Block.PreviewType.DROP:
		return drop is SocketBlock
	return super(at_position, drop) and drop is ExpressionBlock
