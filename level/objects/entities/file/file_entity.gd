@tool
class_name FileEntity
extends Node2D
## A text file in the room: a sheet of paper with a name tab (notes.txt) and
## its lines, numbered. A program reads it line by line (For Each, as Python's
## `for line in f:`), counts its lines (Length Of), and writes to it (Write,
## Python's f.write()), one line at a time, at the end. The terminal is what a
## program says to the user while it runs; a file is what it keeps.
##
## One file per room, as with lists: every room's file has the same name and
## its own room_index, and a block finds the running room's (find()). Its name
## block comes from its FileBlockProvider. A FileGoal shows the lines the file
## should end up with, faded, and colours each line written green or red.
##
## Lines are kept without Python's "\n" at their end, as `line.strip()` gives
## them, so a line reads the way it looks.

const GROUP := &"file_entity"
const FONT := preload("res://puzzle/ui/themes/fonts/Kenney Mini.ttf")
const FONT_SIZE := 16
const LINE_H := 20.0
const PAD := 6.0
const TAB_H := 22.0
const NUMBER_W := 22.0
const MIN_W := 110.0
const MAX_LINES := 40

const PAPER := Color("#fbfbf6")
const PAPER_EDGE := Color("#8a96ab")
const TAB := Color("#9ad1ff")
const RULE := Color("#dfe6f0")
const INK := Color("#1d2433")
const NUMBER := Color("#8a96ab")
const GHOST := Color(0.35, 0.4, 0.5, 0.45)
const RIGHT := Color("#2f9e5b")
const WRONG := Color("#d0384f")
const FLASH := Color(1.0, 0.82, 0.3)

## The file's name as a program opens it, like notes.txt.
@export var file_name := "notes.txt"
@export var room_index := 0
## What the file holds when the level starts, a line each.
@export var lines: PackedStringArray = []:
	set(value):
		lines = value
		queue_redraw()

var _initial: PackedStringArray = []
var _expected: PackedStringArray = []
var _has_target := false
## Lines the program wrote this run, which the goal colours.
var _written_from := -1
var _flash_line := -1
var _flash := 0.0
var _pointed := -1


func _ready() -> void:
	queue_redraw()
	if Engine.is_editor_hint():
		return
	_initial = lines.duplicate()
	if Game.level != null and Game.level.is_ancestor_of(self):
		add_to_group(GROUP)

func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 2.0)
		queue_redraw()


#region Queries
func repr() -> String:
	return "open('%s')" % file_name

static func find(p_name: StringName) -> FileEntity:
	var level := Game.level
	if level == null or not level.is_inside_tree():
		return null
	var named: Array[FileEntity] = []
	for node in level.get_tree().get_nodes_in_group(GROUP):
		var file := node as FileEntity
		if file != null and file.file_name == String(p_name) and level.is_ancestor_of(file):
			named.append(file)
	if named.size() == 1:
		return named[0]
	for file in named:
		if file.room_index == level.current_room:
			return file
	return null

func is_canonical() -> bool:
	var best: FileEntity = null
	for node in get_tree().get_nodes_in_group(GROUP):
		var other := node as FileEntity
		if other == null or other.file_name != file_name:
			continue
		if best == null or other.room_index < best.room_index:
			best = other
	return best == self

func matches(expected: PackedStringArray) -> bool:
	return lines == expected

func set_target(expected: PackedStringArray) -> void:
	_expected = expected.duplicate()
	_has_target = true
	queue_redraw()

func mismatch() -> String:
	for i in maxi(lines.size(), _expected.size()):
		if i < lines.size() and i < _expected.size() and lines[i] == _expected[i]:
			continue
		if i >= lines.size():
			return "Line %d of %s should say %s, but the file ends before it." % [i + 1, file_name, Core.to_python_repr(_expected[i])]
		if i >= _expected.size():
			return "Line %d of %s says %s, but the file should end before it." % [i + 1, file_name, Core.to_python_repr(lines[i])]
		return "Line %d of %s should say %s, but it says %s." % [i + 1, file_name, Core.to_python_repr(_expected[i]), Core.to_python_repr(lines[i])]
	return ""

func get_global_bounds() -> Rect2:
	return global_transform * Rect2(Vector2.ZERO, _size())
#endregion


#region What blocks do (each paces itself)
func restore() -> void:
	lines = _initial.duplicate()
	_written_from = -1
	_pointed = -1

## f.write(text): a new line at the end.
func write_line(text: String, from_this: Block) -> void:
	if lines.size() >= MAX_LINES:
		from_this.function.error("%s already has %d lines. Is something writing again and again?" % [file_name, MAX_LINES])
		return
	if _written_from < 0:
		_written_from = lines.size()
	for line in text.split("\n"):
		lines.append(line)
	_light(lines.size() - 1)
	await Interpreter.step(from_this)

func size(from_this: Block) -> int:
	_light(-1)
	await Interpreter.step(from_this)
	return lines.size()

## The lines, for For Each: a copy, so a program writing to the file it reads
## doesn't read its own lines forever.
func line_list() -> PackedStringArray:
	return lines.duplicate()

func point_at(i: int) -> void:
	_pointed = i
	queue_redraw()
#endregion


func _light(i: int) -> void:
	_flash_line = i
	_flash = 1.0
	queue_redraw()


#region Drawing
func _w(text: String) -> float:
	return FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x

func _rows() -> int:
	return maxi(1, maxi(lines.size(), _expected.size()))

func _size() -> Vector2:
	var widest := _w(file_name) + 12.0
	for line in lines:
		widest = maxf(widest, _w(line) + NUMBER_W + PAD * 2.0)
	for line in _expected:
		widest = maxf(widest, _w(line) + NUMBER_W + PAD * 2.0)
	return Vector2(maxf(MIN_W, widest), TAB_H + PAD + _rows() * LINE_H + PAD)

func _draw() -> void:
	var size := _size()
	var tab_w := _w(file_name) + 12.0
	_box(Rect2(0, 0, tab_w, TAB_H + 4.0), TAB, TAB.darkened(0.3), 4)
	draw_string(FONT, Vector2(6, 16), file_name, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, INK)
	var sheet := Rect2(0, TAB_H, size.x, size.y - TAB_H)
	_box(sheet, PAPER, PAPER_EDGE, 3)
	for i in _rows():
		var top := TAB_H + PAD + i * LINE_H
		draw_line(Vector2(4, top + LINE_H - 1), Vector2(size.x - 4, top + LINE_H - 1), RULE, 1.0)
		if i == _flash_line and _flash > 0.0:
			draw_rect(Rect2(2, top, size.x - 4, LINE_H), Color(FLASH, 0.35 * _flash))
		if i == _pointed:
			draw_rect(Rect2(2, top, size.x - 4, LINE_H), FLASH, false, 2.0)
		draw_string(FONT, Vector2(PAD, top + 16), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, NUMBER)
		var at := Vector2(PAD + NUMBER_W, top + 16)
		if i < lines.size():
			var color := INK
			if _has_target and _written_from >= 0 and i >= _written_from:
				color = RIGHT if i < _expected.size() and lines[i] == _expected[i] else WRONG
			elif _has_target and (i >= _expected.size() or lines[i] != _expected[i]) and _written_from >= 0:
				color = WRONG
			draw_string(FONT, at, lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, color)
		elif i < _expected.size():
			draw_string(FONT, at, _expected[i], HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, GHOST)

func _box(rect: Rect2, fill: Color, edge: Color, radius: int) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	draw_style_box(style, rect)
#endregion
