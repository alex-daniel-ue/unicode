@tool
class_name DictEntity
extends Node2D
## A dictionary in the room: a board with one row per key, `key : value`, in
## the order the keys were added, as Python keeps them. It is the list board's
## idea for data that is found by a name rather than by a position: a price
## list, a phone book, a tally of votes.
##
## Drawn, like the terminal, rather than built from boxes: a list's boxes are
## a tile wide for one number, and a key like "notebook" isn't.
##
## One board per room, as with lists: every room's board has the same name and
## its own room_index, and a block finds the running room's (find()). Its name
## block comes from its DictBlockProvider. A DictGoal shows the rows the board
## should end up with: a missing row faded, a row the program wrote green when
## it is right and red when it isn't, with the wanted value beside it.

const GROUP := &"dict_entity"
const FONT := preload("res://puzzle/ui/themes/fonts/Kenney Mini.ttf")
const FONT_SIZE := 16
const ROW_H := 24.0
const PAD := 6.0
const GAP := 8.0
const CHIP_PAD := 5.0
const NAME_H := 26.0
const MAX_KEYS := 20

const BOARD := Color("#e9edf3")
const BOARD_EDGE := Color("#8a96ab")
const NAME_CHIP := Color("#c4a5ff")
const KEY_TEXT := Color("#ff8f5e")
const KEY_NUMBER := Color("#93c5fd")
const VALUE_BOX := Color("#ffffff")
const INK := Color("#1d2433")
const GHOST := Color(0.35, 0.4, 0.5, 0.45)
const RIGHT := Color("#b6ecc6")
const WRONG := Color("#ffb8b8")
const WANTED := Color("#2f9e5b")
const FLASH := Color(1.0, 0.82, 0.3)

## What students read, and what the name block says. Empty means the node's name.
@export var dict_name: StringName = &""
@export var room_index := 0
## The keys and values the level starts with, in order.
@export var entries: Dictionary = {}:
	set(value):
		entries = value
		queue_redraw()

var _initial: Dictionary = {}
var _target: Dictionary = {}
var _has_target := false
var _written: Array = []
var _flash_key: Variant = null
var _flash := 0.0
## For each's row, or null.
var _pointed: Variant = null


func _ready() -> void:
	queue_redraw()
	if Engine.is_editor_hint():
		return
	_initial = entries.duplicate(true)
	if Game.level != null and Game.level.is_ancestor_of(self):
		add_to_group(GROUP)

func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 2.0)
		queue_redraw()


#region Queries
func get_dict_name() -> StringName:
	return dict_name if not dict_name.is_empty() else StringName(name)

func kind_name() -> String:
	return "dict"

func repr() -> String:
	return repr_of(entries)

func repr_of(d: Dictionary) -> String:
	var parts := PackedStringArray()
	for key: Variant in d:
		parts.append("%s: %s" % [Core.to_python_repr(key), Core.to_python_repr(d[key])])
	return "{" + ", ".join(parts) + "}"

func initial_repr() -> String:
	return repr_of(_initial)

## The board a block means by `p_name` right now.
static func find(p_name: StringName) -> DictEntity:
	var level := Game.level
	if level == null or not level.is_inside_tree():
		return null
	var named: Array[DictEntity] = []
	for node in level.get_tree().get_nodes_in_group(GROUP):
		var board := node as DictEntity
		if board != null and board.get_dict_name() == p_name and level.is_ancestor_of(board):
			named.append(board)
	if named.size() == 1:
		return named[0]
	for board in named:
		if board.room_index == level.current_room:
			return board
	return null

## Among every board of this name in the level, the one that hands out the name block.
func is_canonical() -> bool:
	var best: DictEntity = null
	for node in get_tree().get_nodes_in_group(GROUP):
		var other := node as DictEntity
		if other == null or other.get_dict_name() != get_dict_name():
			continue
		if best == null or other.room_index < best.room_index:
			best = other
	return best == self

## Python's == for two dicts: the same keys with the same values, in any order.
func matches(expected: Dictionary) -> bool:
	if expected.size() != entries.size():
		return false
	for key: Variant in expected:
		var found: Variant = _key_in(entries, key)
		if found == null or not ListEntity.same(entries[found], expected[key]):
			return false
	return true

func set_target(expected: Dictionary) -> void:
	_target = expected.duplicate(true)
	_has_target = true
	queue_redraw()

## The first row that is wrong, for a DictGoal's message.
func mismatch() -> String:
	for key: Variant in _target:
		var found: Variant = _key_in(entries, key)
		if found == null:
			return "'%s' should have the key %s, with the value %s." % [get_dict_name(), Core.to_python_repr(key), Core.to_python_repr(_target[key])]
		if not ListEntity.same(entries[found], _target[key]):
			return "In '%s', %s should be %s, but it is %s." % [get_dict_name(), Core.to_python_repr(key), Core.to_python_repr(_target[key]), Core.to_python_repr(entries[found])]
	for key: Variant in entries:
		if _key_in(_target, key) == null:
			return "'%s' has the key %s, but it shouldn't." % [get_dict_name(), Core.to_python_repr(key)]
	return ""

func get_global_bounds() -> Rect2:
	return global_transform * Rect2(Vector2.ZERO, _size())
#endregion


#region What blocks do (each paces itself)
func restore() -> void:
	_written.clear()
	_pointed = null
	entries = _initial.duplicate(true)

## d[key], or null after raising Python's KeyError, in plain words.
func read(key: Variant, from_this: Block) -> Variant:
	var found: Variant = _key_in(entries, key)
	if found == null:
		from_this.function.error("%s isn't a key in '%s'. Its keys are %s." % [Core.to_python_repr(key), get_dict_name(), _keys_text()])
		return null
	_light(found)
	await Interpreter.step(from_this)
	return entries[found]

## d[key] = value: changes the value, or adds the key when it is new.
func write(key: Variant, value: Variant, from_this: Block) -> void:
	if not _usable_key(key, from_this):
		return
	if value == null or value is Object:
		from_this.function.error("There's nothing to put into '%s'. Fill in the value slot." % get_dict_name())
		return
	var found: Variant = _key_in(entries, key)
	if found == null and entries.size() >= MAX_KEYS:
		from_this.function.error("'%s' already has %d keys." % [get_dict_name(), entries.size()])
		return
	var at: Variant = found if found != null else key
	entries[at] = value
	if not _written.has(at):
		_written.append(at)
	_light(at)
	await Interpreter.step(from_this)

## del d[key]
func remove(key: Variant, from_this: Block) -> void:
	var found: Variant = _key_in(entries, key)
	if found == null:
		from_this.function.error("%s isn't a key in '%s', so it can't be removed." % [Core.to_python_repr(key), get_dict_name()])
		return
	entries.erase(found)
	_written.erase(found)
	queue_redraw()
	await Interpreter.step(from_this)

## key in d
func has(key: Variant, from_this: Block) -> bool:
	var found: Variant = _key_in(entries, key)
	if found != null:
		_light(found)
	await Interpreter.step(from_this)
	return found != null

func size(from_this: Block) -> int:
	_flash = 1.0
	_flash_key = null
	await Interpreter.step(from_this)
	return entries.size()

## The keys, for For Each, which walks a dict's keys as Python does.
func key_list() -> Array:
	return entries.keys()

func point_at(key: Variant) -> void:
	_pointed = key
	queue_redraw()
#endregion


func _usable_key(key: Variant, from_this: Block) -> bool:
	if typeof(key) not in [TYPE_STRING, TYPE_INT, TYPE_FLOAT, TYPE_BOOL]:
		from_this.function.error("A key has to be text or a number, but it's %s." % Core.to_python_repr(key))
		return false
	return true

## The key in `d` that equals `key` in Python's terms (3 and 3.0 are one key),
## or null.
static func _key_in(d: Dictionary, key: Variant) -> Variant:
	if d.has(key):
		return key
	for k: Variant in d:
		if ListEntity.same(k, key):
			return k
	return null

func _keys_text() -> String:
	var parts := PackedStringArray()
	for key: Variant in entries:
		parts.append(Core.to_python_repr(key))
	return ", ".join(parts) if not parts.is_empty() else "none yet"

func _light(key: Variant) -> void:
	_flash_key = key
	_flash = 1.0
	queue_redraw()


#region Drawing
func _rows() -> Array:
	var rows: Array = entries.keys()
	if _has_target:
		for key: Variant in _target:
			if _key_in(entries, key) == null:
				rows.append(key)
	return rows

func _text(value: Variant) -> String:
	return Core.to_python_repr(value) if not Engine.is_editor_hint() else str(value)

func _w(text: String) -> float:
	return FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x

func _columns() -> Vector2:
	var key_w := 30.0
	var value_w := 30.0
	for key: Variant in _rows():
		key_w = maxf(key_w, _w(_text(key)) + CHIP_PAD * 2.0)
		if _key_in(entries, key) != null:
			value_w = maxf(value_w, _w(_text(entries[_key_in(entries, key)])) + CHIP_PAD * 2.0)
		if _has_target and _key_in(_target, key) != null:
			value_w = maxf(value_w, _w(_text(_target[_key_in(_target, key)])) + CHIP_PAD * 2.0 + 30.0)
	return Vector2(key_w, value_w)

func _size() -> Vector2:
	var cols := _columns()
	var name_w := _w(String(get_dict_name())) + CHIP_PAD * 2.0
	var w := maxf(name_w, cols.x + GAP * 2.0 + cols.y) + PAD * 2.0
	return Vector2(w, PAD + NAME_H + GAP * 0.5 + maxi(_rows().size(), 1) * ROW_H + PAD)

func _draw() -> void:
	var size := _size()
	_box(Rect2(Vector2.ZERO, size), BOARD, BOARD_EDGE, 4)
	var label := String(get_dict_name())
	_box(Rect2(PAD, PAD, _w(label) + CHIP_PAD * 2.0, NAME_H - 4.0), NAME_CHIP, NAME_CHIP.darkened(0.25), 6)
	draw_string(FONT, Vector2(PAD + CHIP_PAD, PAD + 17.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, INK)
	var cols := _columns()
	var y := PAD + NAME_H + GAP * 0.5
	for key: Variant in _rows():
		var found: Variant = _key_in(entries, key)
		var row := Rect2(PAD - 2.0, y, size.x - PAD * 2.0 + 4.0, ROW_H)
		if found != null and _flash > 0.0 and _flash_key != null and ListEntity.same(found, _flash_key):
			draw_rect(row, Color(FLASH, 0.45 * _flash))
		if _pointed != null and found != null and ListEntity.same(found, _pointed):
			draw_rect(row, FLASH, false, 2.0)
		var key_color := KEY_NUMBER if typeof(key) in [TYPE_INT, TYPE_FLOAT] else KEY_TEXT
		var faded := found == null
		var chip := Rect2(PAD, y + 2.0, cols.x, ROW_H - 4.0)
		_box(chip, key_color if not faded else Color(key_color, 0.35), key_color.darkened(0.25), 5)
		draw_string(FONT, Vector2(chip.position.x + CHIP_PAD, y + 17.0), _text(key), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, INK if not faded else GHOST)
		draw_string(FONT, Vector2(PAD + cols.x + 3.0, y + 17.0), ":", HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, INK)
		var box := Rect2(PAD + cols.x + GAP * 2.0, y + 2.0, cols.y, ROW_H - 4.0)
		var want: Variant = _target[_key_in(_target, key)] if _has_target and _key_in(_target, key) != null else null
		if found == null:
			_box(box, Color(VALUE_BOX, 0.4), Color(BOARD_EDGE, 0.5), 3)
			draw_string(FONT, Vector2(box.position.x + CHIP_PAD, y + 17.0), _text(want), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, GHOST)
		else:
			var fill := VALUE_BOX
			var right := want != null and ListEntity.same(entries[found], want)
			if _has_target and (_written.has(found) or want == null):
				fill = RIGHT if right else WRONG
			_box(box, fill, BOARD_EDGE, 3)
			draw_string(FONT, Vector2(box.position.x + CHIP_PAD, y + 17.0), _text(entries[found]), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, INK)
			if _has_target and not right and want != null:
				draw_string(FONT, Vector2(box.position.x + _w(_text(entries[found])) + CHIP_PAD * 2.0 + 2.0, y + 17.0), _text(want), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, WANTED)
		y += ROW_H

func _box(rect: Rect2, fill: Color, edge: Color, radius: int) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	draw_style_box(style, rect)
#endregion
