class_name LevelBlockPreset
extends Node


@export var immovable := false

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
		if immovable:
			block.data.draggable = false
		preset_data.append(block.data)

	# The flags above only take effect on the next read. ValueBlocks read theirs in
	# _ready(), which has already run, so tell them.
	for block in root.get_all_blocks(true):
		if block is ValueBlock:
			(block as ValueBlock).refresh_editable()

	root_block = root
	return root
