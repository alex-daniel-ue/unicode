extends VBoxContainer


func _ready() -> void:
	name = "Mouth"
	size = Vector2.ZERO

## Uses [method Node.add_child and Node.move_child].
func insert_child(idx: int, node: Node) -> void:
	add_child(node)
	if idx >= get_child_count():
		idx = -1
	if idx != -1:
		move_child(node, idx)
