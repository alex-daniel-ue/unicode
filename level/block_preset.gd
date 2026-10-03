class_name LevelBlockPreset
extends Node


## Preset blocks can't be dragged at all, not just not deleted. For worked
## examples, where the program on the canvas is the thing being studied.
@export var immovable := false
## A program to put under begin, written out instead of built in the editor,
## for presets whose slots hold other blocks (a level generator writes these).
## JSON: a list of blocks, each [name, slot, slot...], where a slot is typed in
## or is a block itself, and ["list", "route"] is route's name block:
##   [["moven", ["item", 0, ["list", "route"]]], ["turn", "left"]]
## Only used while begin is empty, so blocks authored in the editor win.
@export_multiline var program := ""

## The block names `program` can use.
const PROGRAM_BLOCKS := {
	"move": "res://level/objects/entities/robot/blocks/move.tres",
	"moven": "res://level/objects/entities/robot/blocks/move_n.tres",
	"turn": "res://level/objects/entities/robot/blocks/turn.tres",
	"item": "res://puzzle/blocks/lists/item_of.tres",
	"len": "res://puzzle/blocks/lists/length_of.tres",
	"arith": "res://puzzle/blocks/socket/arithmetic.tres",
	"cmp": "res://puzzle/blocks/socket/comparison.tres",
}

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
	if not program.is_empty() and root is NestedBlock and (root as NestedBlock).get_blocks().is_empty():
		_build_program(root as NestedBlock)

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

func _build_program(root: NestedBlock) -> void:
	var parsed: Variant = JSON.parse_string(program)
	if not parsed is Array:
		push_error("LevelBlockPreset: program isn't a JSON list of blocks.")
		return
	for spec: Variant in parsed:
		var data := _data_for(spec)
		if data != null:
			root.mouth.add_child(Block.construct(data))

## The block `spec` describes, as data: slots filled by typing into them, or by
## putting another block's data in their place, the way a preset authored
## through data nests blocks.
static func _data_for(spec: Variant) -> BlockData:
	if not spec is Array or (spec as Array).is_empty():
		push_error("LevelBlockPreset: '%s' isn't a block." % str(spec))
		return null
	var parts := spec as Array
	if parts[0] == "list":
		return ListEntity.reporter_data(StringName(parts[1]))
	if not PROGRAM_BLOCKS.has(parts[0]):
		push_error("LevelBlockPreset: no block called '%s' (see PROGRAM_BLOCKS)." % parts[0])
		return null
	var data := (load(PROGRAM_BLOCKS[parts[0]]) as BlockData).deep_copy()
	for i in range(1, parts.size()):
		var value: Variant = parts[i]
		if i - 1 >= data.text_blocks.size():
			break
		if value is Array:
			var inner := _data_for(value)
			if inner != null:
				data.text_blocks[i - 1] = inner
		else:
			# JSON numbers arrive as floats; a whole one is typed as an int.
			if value is float and is_equal_approx(value, roundf(value)):
				value = int(value)
			data.text_blocks[i - 1].text = str(value)
	return data
