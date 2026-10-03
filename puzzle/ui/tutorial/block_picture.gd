class_name BlockPicture
extends Control

## An inert picture of a block, for guide pages and their graphics: it looks like
## the real one and can't be dragged, clicked or typed into.
##
## `values` fills the block's slots in order: plain text is typed in, and
## "list:route" puts route's name block in the slot, as a student would. An
## empty entry leaves that slot as it is. `list_name` alone pictures that list's
## name block. `tag` puts a value tag on the block's corner, as a run would.
##
## A plain Control rather than a container, so the tag can sit over the block's
## corner; it takes its minimum size from the block, so containers around it
## place it like any other control.

const TAG := preload("res://puzzle/ui/canvas/value_tag.tscn")
## Room above and to the right of the block for the tag to stick out into.
const TAG_ROOM := Vector2(18, 12)

@export var data: BlockData
@export var values: PackedStringArray = []
@export var list_name := ""
@export var tag := ""

var _block: Control
var _badge: Control


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	if data == null and not list_name.is_empty():
		data = ListEntity.reporter_data(StringName(list_name))
	if data == null:
		return
	var shown := data.deep_copy()
	for i in mini(values.size(), shown.text_blocks.size()):
		var value := values[i].strip_edges()
		if value.is_empty():
			continue
		if value.begins_with("list:"):
			shown.text_blocks[i] = ListEntity.reporter_data(StringName(value.trim_prefix("list:")))
		else:
			shown.text_blocks[i].text = value
	var block := Block.construct(shown)
	block.display = true
	# format() builds the slots in the block's own _ready(), so they can only be
	# silenced once it has run.
	block.ready.connect(_silence.bind(block), CONNECT_ONE_SHOT)
	add_child(block)
	_block = block
	if not tag.is_empty():
		_badge = TAG.instantiate() as Control
		(_badge.get_node(^"Value") as Label).text = tag
		add_child(_badge)
		_badge.resized.connect(_fit)
	block.resized.connect(_fit)
	_fit()

## Sizes this control to the block (plus room for the tag) and pins the tag to
## the block's top-right corner.
func _fit() -> void:
	if _block == null:
		return
	var room := TAG_ROOM if _badge != null else Vector2.ZERO
	_block.position = Vector2(0, room.y)
	custom_minimum_size = _block.size + room
	if _badge != null:
		_badge.position = Vector2(_block.size.x + room.x - _badge.size.x, 0)

func _silence(block: Control) -> void:
	for node in [block] + block.find_children("*", "Control", true, false):
		var control := node as Control
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE
		control.focus_mode = Control.FOCUS_NONE
