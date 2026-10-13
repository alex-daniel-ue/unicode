class_name SlotExamples
extends VBoxContainer

## A block on a guide page with sample values floating under it, and an arrow
## from each to the slot they could go in: "this slot takes a number, or a
## variable". Without them, a slot that is typed into read as part of the
## block's picture, and a student didn't know what could go there.
##
## The samples are real slots with the values typed in, so they wear the type
## label (var, int) and colour that the slot will when the student types.

const SLOT := preload("res://puzzle/blocks/_common/value/receptive_editable_line.tres")
## The slots a student can type a value into, by data name.
const TYPABLE := ["ValueSlot", "ValueSlotPlain"]
## What floats under the slot: a variable, then a number.
const SAMPLES := ["x", "2"]
## Better samples for some blocks' slots, by block data name: an index is i or 0.
const SAMPLES_FOR := {
	"ItemOfBlock": ["i", "0"],
	"SetItemBlock": ["i", "0"],
}
## Which slot to point at, for blocks where the first one is a poor pick: the
## For block's start sits on its top line, and the arrows to it crossed the
## whole block. Its end is on the line nearest the samples.
const SLOT_FOR := {
	"ForBlock (Integer)": 2,
}
const COLOR := Color(1.0, 0.82, 0.3)
const RIM := Color(0.105882354, 0.09411765, 0.13725491)
const WIDTH := 3.0
const HEAD := 10.0

var _picture: BlockPicture
var _slot_index := 0
var _samples: Array[BlockPicture] = []
## Drawn after the block and the samples, so the arrows reach into the block
## right up to the slot instead of stopping under the block's bottom edge.
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

## `picture` with samples floating under its slot number `slot_index`.
static func build(picture: BlockPicture, slot_index: int) -> SlotExamples:
	var examples := SlotExamples.new()
	examples._picture = picture
	examples._slot_index = slot_index
	return examples


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override(&"separation", 40)  # the arrows run in this gap
	_picture.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_child(_picture)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 36)
	row.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(row)
	for value: String in SAMPLES_FOR.get(_picture.data.name, SAMPLES):
		var data := SLOT.deep_copy()
		data.text = value
		var sample := BlockPicture.new()
		sample.data = data
		row.add_child(sample)
		_samples.append(sample)
	# A Node2D, so the container leaves it out of the layout; last, so it draws
	# over the rest.
	_arrows = Node2D.new()
	_arrows.draw.connect(_draw_arrows)
	add_child(_arrows)

func _process(_delta: float) -> void:
	_arrows.queue_redraw()

func _draw_arrows() -> void:
	var root := _root()
	var slot := _slot(root)
	if slot == null or slot.size == Vector2.ZERO:
		return
	var to_local := get_global_transform().affine_inverse()
	var slot_rect := slot.get_global_rect()
	var end := to_local * Vector2(slot_rect.get_center().x, slot_rect.end.y + 2.0)
	for sample in _samples:
		if sample.size == Vector2.ZERO:
			continue
		var rect := sample.get_global_rect()
		var start := to_local * Vector2(rect.get_center().x, rect.position.y + 4.0)
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

## The slot block the samples point at: the `_slot_index`th block directly in
## `root`, not one inside another slot.
func _slot(root: Block) -> Control:
	if root == null:
		return null
	var direct: Array[Block] = []
	for node in root.find_children("*", "Block", true, false):
		var parent := node.get_parent()
		while parent != null and not parent is Block:
			parent = parent.get_parent()
		if parent == root:
			direct.append(node as Block)
	return direct[_slot_index] if _slot_index < direct.size() else null
