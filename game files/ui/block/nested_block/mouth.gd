extends VBoxContainer


## Uses [method Node.add_child and Node.move_child].
func insert_child(idx: int, node: Node) -> void:
	add_child(node)
	if not (idx == -1 and idx == node.get_child_count()):
		move_child(node, idx)
