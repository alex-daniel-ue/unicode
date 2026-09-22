class_name LevelBlockPreset
extends Node

var root_block: Block
var preset_data: Array[BlockData]


func get_preset() -> Block:
	var root: Block
	for child in get_children():
		if child is Block:
			root = child as Block
	if root == null:
		return null

	preset_data.clear()
	for block in root.get_all_blocks(true):
		block.data = block.data.deep_copy()
		block.data.toolbox = false
		block.data.trashable = false
		block.data.copyable = false
		preset_data.append(block.data)

	root_block = root
	return root
