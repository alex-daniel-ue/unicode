class_name FunctionDefinitions
extends BlockProvider

## The functions a level gives: for each one, a define block on the canvas
## beside Begin (Python's def) and a call block in the Toolbox. The level names
## the function and its parameters, and the student writes what it does, or
## uses one that is already written. Naming is a level's design decision here,
## as a list's name is: a name typed by the student would have to rename call
## blocks already on the canvas, and a misspelt call has nothing to call.
##
## `functions` is JSON, a list of:
##   {"name": "zigzag", "params": ["n"], "returns": false (or true, or "bool"),
##    "body": [preset program], "locked": true}
## "body" uses LevelBlockPreset's program format; "locked" fixes those blocks
## in place, for a level that only calls a function that is already written.

const DEFINE := preload("res://puzzle/blocks/functions/define.tres")
const CALL := preload("res://puzzle/blocks/functions/call.tres")
const CALL_VALUE := preload("res://puzzle/blocks/functions/call_value.tres")
## For a function that gives back True or False: shaped like a condition, so
## it fits an If or a While, where a round value block doesn't.
const CALL_BOOL := preload("res://puzzle/blocks/functions/call_bool.tres")
const SLOT := preload("res://puzzle/blocks/_common/value/receptive_editable_line.tres")
## Where the define blocks go, from Begin: to its left, one under another.
## To its right they sat under the room's panel; under it, the program growing
## down from Begin ran into them.
const OFFSET := Vector2(-400, 0)
const GAP := 40.0

@export_multiline var functions := ""


func specs() -> Array:
	if functions.strip_edges().is_empty():
		return []
	var parsed: Variant = JSON.parse_string(functions)
	if not parsed is Array:
		push_error("FunctionDefinitions: functions isn't a JSON list.")
		return []
	return parsed

func get_block_data() -> Array[BlockData]:
	if block_data.is_empty():
		for spec: Dictionary in specs():
			block_data.append(call_data(spec))
	return block_data

## The call block for `spec`: `name ( {} , {} )`, a slot per parameter, each
## showing the parameter's name until something is put in it.
static func call_data(spec: Dictionary) -> BlockData:
	var name: String = spec.name
	var params := PackedStringArray(spec.get("params", []))
	var returns: Variant = spec.get("returns", false)
	var template: BlockData = CALL_BOOL if returns is String and returns == "bool" else (CALL_VALUE if returns else CALL)
	var data := template.deep_copy()
	var slots: PackedStringArray = []
	var text_blocks: Array[BlockData] = []
	for param in params:
		slots.append("{}")
		text_blocks.append(SLOT)
	data.name = "Call_%s" % name
	data.title = name
	data.text = "%s ( %s )" % [name, ", ".join(slots)] if not params.is_empty() else "%s ( )" % name
	data.text_blocks = text_blocks
	data.text_hints = params
	data.func_entity_name = StringName(name)
	data.syntax = "%s(%s)" % [name, ", ".join(params)]
	data.note = ("This block runs the blocks under define %s, and gives back what its Return block gives." if spec.get("returns", false)
			else "This block runs the blocks under define %s.") % name
	return data

## The call block's data for the function called `name` in the running level.
static func call_data_for(name: String) -> BlockData:
	if Game.level == null:
		return null
	for node in Core.get_children_recursive(Game.level, true):
		if node is FunctionDefinitions:
			for spec: Dictionary in (node as FunctionDefinitions).specs():
				if spec.name == name:
					return call_data(spec)
	return null

## A define block for each function, with its body when the level gives one.
func define_blocks() -> Array[Block]:
	var out: Array[Block] = []
	for spec: Dictionary in specs():
		var name: String = spec.name
		var params := PackedStringArray(spec.get("params", []))
		var data := DEFINE.deep_copy()
		data.name = "Define_%s" % name
		data.text = "define %s ( %s )" % [name, ", ".join(params)]
		data.func_entity_name = StringName(name)
		data.syntax = "def %s(%s):" % [name, ", ".join(params)]
		data.toolbox = false
		var define := Block.construct(data) as NestedBlock
		for item: Variant in spec.get("body", []):
			var item_data := LevelBlockPreset._data_for(item)
			if item_data != null:
				define.mouth.add_child(Block.construct(item_data))
		for block in define.get_all_blocks(true) + _body(define):
			block.data = block.data if block == define else block.data.deep_copy()
			block.data.toolbox = false
			block.data.copyable = false
			if block != define and spec.get("locked", false):
				block.data.trashable = false
				block.data.draggable = false
		for block in _body(define):
			if block is ValueBlock:
				(block as ValueBlock).refresh_editable()
		out.append(define)
	return out

static func _body(define: NestedBlock) -> Array[Block]:
	var out: Array[Block] = []
	for block in define.get_blocks():
		out.append_array(block.get_all_blocks(true))
		if block is NestedBlock:
			out.append_array(_body(block as NestedBlock))
	return out
