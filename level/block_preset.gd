class_name LevelBlockPreset
extends Node

var root_block: Block

func get_preset() -> Block:
	var root: Block
	for child in get_children():
		if child is Block:
			root = child as Block
	if root == null:
		return null
	
	for block in root.get_all_blocks(true):
		block.data = block.data.duplicate(true)
		block.data.toolbox = false
		block.data.trashable = false
		block.data.copyable = false
		print(block)
	
	root_block = root
	return root
