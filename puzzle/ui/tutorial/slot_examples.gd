class_name SlotExamples
extends VBoxContainer
## A block on a guide page with sample values floating above it, and an arrow
## from each to the slot they could go in: "this slot takes a number, or a
## variable". Without them, a slot that is typed into reads as part of the
## block's picture, and a student doesn't know what could go there.
##
## Above the block, not under it: the page's words sit under its graphics, and
## samples between the block and the words read as what the words were about.
##
## The samples are real slots with the values typed in, so they wear the type
## label (var, int) and colour that the slot will when the student types. A
## sample written as a block spec (LevelBlockPreset's format) is that block
## instead, for a slot whose point is that another block's answer goes in it.

const SLOT := preload("res://puzzle/blocks/_common/value/receptive_editable_line.tres")
## The slots a student can type a value into, by data name.
const TYPABLE := ["ValueSlot", "ValueSlotPlain"]
## What floats above the slot: a variable, then a number.
const SAMPLES := ["x", "2"]
## Better samples for some blocks' slots, by block data name: an index is i or 0,
## and Math works on another block's answer, like a list's length, or a number.
const SAMPLES_FOR := {
	"ItemOfBlock": ["i", "0"],
	"SetItemBlock": ["i", "0"],
	"ArithmeticBlock": [["len", ["list", "route"]], "2"],
}
## Which slot to point at, for blocks where the first one is a poor pick: the
## For block's first slot names its variable, so the arrows go to its start.
const SLOT_FOR := {
	"ForBlock (Integer)": 1,
}
## Blocks whose samples point at more than one slot: either sample can go on
## either side of Math or Compare, and an arrow to one side only said otherwise.
const SLOTS_FOR := {
	"ArithmeticBlock": [0, 2],
	"ComparisonBlock": [0, 2],
}
const COLOR := Color(1.0, 0.82, 0.3)
const RIM := Color(0.105882354, 0.09411765, 0.13725491)
const WIDTH := 3.0
const HEAD := 10.0

var _picture: BlockPicture
var _slot_indices: Array[int] = []
var _samples: Array[BlockPicture] = []
## Drawn after the block and the samples, so the arrows reach into the block
## right up to the slot instead of stopping at the block's top edge.
var _arrows: Node2D


## The first slot of `data` that a value is typed into and that `values` leaves
## empty (or the one SLOT_FOR names), or -1 when there is none.
static func example_slot(data: BlockData, values: PackedStringArray) -> int:
	var wanted: int = SLOT_FOR.get(data.name, -1)
	if wanted >= 0 and wanted < data.text_blocks.size() and (wanted >= values.size() or values[wanted].strip_edges().is_empty()):
		return wanted
	for i in data.text_blocks.size():
		var slot := data.text_blocks[i]
		if slot == null or not slot.name in TYPABLE:
			continue
		if i < values.size() and not values[i].strip_edges().is_empty():
			continue
		return i
	return -1


## `picture` with samples floating above its slot number `slot_index`, or above
## every slot SLOTS_FOR names for it.
static func build(picture: BlockPicture, slot_index: int) -> SlotExamples:
	var examples := SlotExamples.new()
	examples._picture = picture
	examples._slot_indices.assign(SLOTS_FOR.get(picture.data.name, [slot_index]))
	return examples


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override(&"separation", 40)  # the arrows run in this gap
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 36)
	row.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(row)
	for value: Variant in SAMPLES_FOR.get(_picture.data.name, SAMPLES):
		var sample := BlockPicture.new()
		if value is Array:
			sample.data = LevelBlockPreset.data_for(value)
		else:
			var data := SLOT.deep_copy()
			data.text = value
			sample.data = data
		row.add_child(sample)
		_samples.append(sample)
	_picture.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_child(_picture)
	# A Node2D, so the container leaves it out of the layout; last, so it draws
	# over the rest.
	_arrows = Node2D.new()
	_arrows.draw.connect(_draw_arrows)
	add_child(_arrows)


func _process(_delta: float) -> void:
	_arrows.queue_redraw()


func _draw_arrows() -> void:
	var root := _root()
	var to_local := get_global_transform().affine_inverse()
	for index in _slot_indices:
		var slot := _slot(root, index)
		if slot == null or slot.size == Vector2.ZERO:
			continue
		var slot_rect := slot.get_global_rect()
		var end := to_local * Vector2(slot_rect.get_center().x, slot_rect.position.y - 2.0)
		for sample in _samples:
			if sample.size == Vector2.ZERO:
				continue
			var rect := sample.get_global_rect()
			var start := to_local * Vector2(rect.get_center().x, rect.end.y - 4.0)
			_arrow(start, end)


func _arrow(a: Vector2, b: Vector2) -> void:
	var direction := (b - a).normalized()
	if direction == Vector2.ZERO:
		return
	var base := b - direction * HEAD
	var side := direction.orthogonal() * HEAD * 0.6
	_arrows.draw_line(a, base, RIM, WIDTH + 3.0, true)
	_arrows.draw_colored_polygon(PackedVector2Array([b + direction * 2.0, base + side * 1.35, base - side * 1.35]), RIM)
	_arrows.draw_line(a, base, COLOR, WIDTH, true)
	_arrows.draw_colored_polygon(PackedVector2Array([b, base + side, base - side]), COLOR)


## The pictured block.
func _root() -> Block:
	for child in _picture.get_children():
		if child is Block:
			return child as Block
	return null


## The slot block the samples point at: the `index`th block directly in `root`,
## not one inside another slot.
func _slot(root: Block, index: int) -> Control:
	if root == null:
		return null
	var direct: Array[Block] = []
	for node in root.find_children("*", "Block", true, false):
		var parent := node.get_parent()
		while parent != null and not parent is Block:
			parent = parent.get_parent()
		if parent == root:
			direct.append(node as Block)
	return direct[index] if index < direct.size() else null
