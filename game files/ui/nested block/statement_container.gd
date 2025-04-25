extends VBoxContainer


## Uses [method Node.add_child and Node.move_child].
func insert_child(idx: int, node: Node):
	add_child(node)
	if idx != -1:
		move_child(node, idx)
