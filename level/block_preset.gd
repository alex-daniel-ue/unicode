class_name LevelBlockPreset
extends Node


## Preset blocks can't be dragged at all, not just not deleted. For worked
## examples, where the program on the canvas is the thing being studied.
@export var immovable := false

const IMMOVABLE_TOOLTIP := "This program is locked: read it, then watch it run."

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
			block.data.placeable = false
			block.data.draggable = false
		preset_data.append(block.data)

	# The flags above only take effect on the next read. ValueBlocks read theirs in
	# _ready(), which has already run, so tell them.
	for block in root.get_all_blocks(true):
		if block is ValueBlock:
			(block as ValueBlock).refresh_editable()

	if immovable:
		_mark_immovable(root)

	root_block = root
	return root

## Immovable blocks look like every other block, so they say so on hover: the
## "not allowed" cursor and a tooltip, instead of a drag that silently does
## nothing. Dropdowns and text fields are left alone; they still work.
func _mark_immovable(root: Block) -> void:
	var controls: Array[Node] = [root]
	controls.append_array(root.find_children("*", "Control", true, false))
	for node in controls:
		if node is OptionButton or node is LineEdit:
			continue
		var control := node as Control
		control.mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN
		if control is Block:
			control.tooltip_text = IMMOVABLE_TOOLTIP
