extends MarginContainer


func reset() -> void:
	push_warning("unimplemented.")

func get_exposed_blocks() -> Array[Block]:
	var blocks: Array[Block]
	for child in Utils.get_children(self):
		if child is EntityData:
			blocks.append_array(child.blocks)
	return blocks
