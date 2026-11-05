@tool
class_name FileEntity
extends RoomEntity
## A text file in the room: a sheet of paper with a name tab (notes.txt) and
## its lines, numbered. A program reads it line by line (For Each, as Python's
## `for line in f:`), counts its lines (Length Of), and writes to it (Write,
## Python's f.write()), one line at a time, at the end. The terminal is what a
## program says to the user while it runs; a file is what it keeps.
##
## Its name block comes from its FileBlockProvider. A FileGoal shows the lines
## the file should end up with, faded, and colours each line written green or red.
##
## Lines are kept without Python's "\n" at their end, as `line.strip()` gives
## them, so a line reads the way it looks.

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

## The file's name as a program opens it, like notes.txt.
@export var file_name := "notes.txt"
## What the file holds when the level starts, a line each.
@export var lines: PackedStringArray = []:
	set(value):
		lines = value
		queue_redraw()

var _initial: PackedStringArray = []
var _expected: PackedStringArray = []
var _has_target := false
## Where the lines the program wrote this run start, which the goal colours.
var _written_from := -1
var _flash_line := -1
var _flash := 0.0
var _pointed := -1


## The file a block means by `p_name` right now.
static func find(p_name: StringName) -> FileEntity:
	return find_named(FileEntity, p_name) as FileEntity


func _ready() -> void:
	super()
	queue_redraw()
	if not Engine.is_editor_hint():
		_initial = lines.duplicate()


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 2.0)
		queue_redraw()


func _draw() -> void:
	var sheet_size := _size()
	var tab_w := text_width(file_name) + 12.0
	_draw_box(Rect2(0, 0, tab_w, TAB_H + 4.0), TAB, TAB.darkened(0.3), 4)
	draw_string(FONT, Vector2(6, 16), file_name, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, INK)
	var sheet := Rect2(0, TAB_H, sheet_size.x, sheet_size.y - TAB_H)
	_draw_box(sheet, PAPER, PAPER_EDGE, 3)
	for i in _rows():
		var top := TAB_H + PAD + i * LINE_H
		draw_line(Vector2(4, top + LINE_H - 1), Vector2(sheet_size.x - 4, top + LINE_H - 1), RULE, 1.0)
		if i == _flash_line and _flash > 0.0:
			draw_rect(Rect2(2, top, sheet_size.x - 4, LINE_H), Color(FLASH_COLOR, 0.35 * _flash))
		if i == _pointed:
			draw_rect(Rect2(2, top, sheet_size.x - 4, LINE_H), FLASH_COLOR, false, 2.0)
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


func get_entity_name() -> StringName:
	return StringName(file_name)


func restore() -> void:
	lines = _initial.duplicate()
	_written_from = -1
	_pointed = -1


func get_global_bounds() -> Rect2:
	return global_transform * Rect2(Vector2.ZERO, _size())


#region Queries
func repr() -> String:
	return "open('%s')" % file_name


func matches(expected: PackedStringArray) -> bool:
	return lines == expected


func set_target(expected: PackedStringArray) -> void:
	_expected = expected.duplicate()
	_has_target = true
	queue_redraw()


## The first line that is wrong, for a FileGoal's message.
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
#endregion


#region What blocks do (each paces itself)
## f.write(text): a new line at the end, or one per line of a text with \n in it.
func write_line(text: String, from_this: Block) -> void:
	var added := text.split("\n")
	if lines.size() + added.size() > MAX_LINES:
		from_this.function.error("%s can hold %d lines. Is something writing again and again?" % [file_name, MAX_LINES])
		return
	if _written_from < 0:
		_written_from = lines.size()
	lines.append_array(added)
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


func _rows() -> int:
	return maxi(1, maxi(lines.size(), _expected.size()))


func _size() -> Vector2:
	var widest := text_width(file_name) + 12.0
	for line in lines:
		widest = maxf(widest, text_width(line) + NUMBER_W + PAD * 2.0)
	for line in _expected:
		widest = maxf(widest, text_width(line) + NUMBER_W + PAD * 2.0)
	return Vector2(maxf(MIN_W, widest), TAB_H + PAD + _rows() * LINE_H + PAD)
