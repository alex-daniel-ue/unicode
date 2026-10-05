class_name GuideGraphics
extends RefCounted

## Pictures of what the robot's and the lists' blocks do, for the guide page
## that brings each one in. A guide page names one with its "picture" key. Built
## in code from the rooms' own sprites (TileStrip) and boards (ListEntity), so
## they look like the game and change with it.
##
## Words are kept to single labels: the picture carries it.

const ACCENT := Color(1.0, 0.82, 0.3)
const TRUE_COLOR := Color("#86EFAC")
## The colour of a dropdown's words on a block, so a picture's labels read as
## the choices in the dropdown.
const CHOICE_COLOR := Color("#FF8F5E")
const LABEL_FONT := preload("res://puzzle/ui/themes/fonts/Kenney Mini.ttf")
const LIST_SCALE := 2.0

const KINDS := ["move", "move_n", "turn", "ahead_is", "length_of", "set_index", "append", "contains", "for_each"]


static func build(kind: String) -> Control:
	match kind:
		"move": return _move()
		"move_n": return _move_n()
		"turn": return _turn()
		"ahead_is": return _ahead_is()
		"length_of": return _length_of()
		"set_index": return _set_index()
		"append": return _append()
		"contains": return _contains()
		"for_each": return _for_each()
	push_warning("GuideGraphics: no picture called '%s'." % kind)
	return null

#region Robot
## One step: the robot, and where it ends up, one tile on.
static func _move() -> Control:
	var strip := _strip("...")
	strip.robot = 0
	strip.ghost = 1
	strip.arrow_from = 0
	strip.arrow_to = 1
	return _centered([strip])

## Three steps, counted on the tiles.
static func _move_n() -> Control:
	var strip := _strip("....")
	strip.robot = 0
	strip.ghost = 3
	strip.arrow_from = 0
	strip.arrow_to = 3
	strip.marks = {1: "1", 2: "2", 3: "3"}
	return _centered([strip])

## The three turns, each from the same start: facing up.
static func _turn() -> Control:
	var row := _row(28)
	for pair in [["left", Vector2.LEFT], ["right", Vector2.RIGHT], ["back", Vector2.DOWN]]:
		var column := _column(4)
		var before := _strip(".")
		before.robot = 0
		before.facing = Vector2.UP
		column.add_child(before)
		column.add_child(_arrow_down())
		var after := _strip(".")
		after.robot = 0
		after.facing = pair[1]
		column.add_child(after)
		column.add_child(_label(pair[0], CHOICE_COLOR))
		row.add_child(column)
	return row

## The robot looking at the tile in front of it, then what each choice in the
## dropdown means, as the thing in the room it looks for.
static func _ahead_is() -> Control:
	var stack := _column(14)
	var top := _row(16)
	var strip := _strip(".P")
	strip.robot = 0
	strip.looked_at = 1
	top.add_child(strip)
	top.add_child(_label("True", TRUE_COLOR, 22))
	stack.add_child(top)
	var legend := _row(22)
	for pair in [["D", "blocked"], ["F", "destination"], ["P", "puddle"]]:
		var item := _column(2)
		item.add_child(_strip(pair[0]))
		item.add_child(_label(pair[1], CHOICE_COLOR))
		legend.add_child(item)
	stack.add_child(legend)
	return stack
#endregion

#region Lists
static func _length_of() -> Control:
	var row := _row(14)
	row.add_child(_list("route", [3, 2, 4]))
	row.add_child(_label("= 3", ACCENT, 26))
	return row

## Before and after: the box at index 0 gets the new value.
static func _set_index() -> Control:
	var after := _list("lockers", [1, 0, 0])
	after.set_meta(&"point_at", 0)
	return _before_after(_list("lockers", [0, 0, 0]), after)

## Before and after: a new box at the end.
static func _append() -> Control:
	var after := _list("passed", [75, 90, 82])
	after.set_meta(&"point_at", 2)
	return _before_after(_list("passed", [75, 90]), after)

static func _contains() -> Control:
	var row := _row(14)
	var list := _list("choir", [5, 2, 7])
	list.set_meta(&"point_at", 1)
	row.add_child(list)
	row.add_child(_label("True", TRUE_COLOR, 26))
	return row

## The first pass: the loop is on the first box, and its variable holds that
## value.
static func _for_each() -> Control:
	var stack := _column(8)
	var list := _list("route", [2, 3, 1])
	list.set_meta(&"point_at", 0)
	stack.add_child(list)
	stack.add_child(_label("leg = 2, then 3, then 1", ACCENT, 18))
	return stack

static func _before_after(before: Control, after: Control) -> Control:
	var stack := _column(2)
	stack.add_child(before)
	stack.add_child(_arrow_down())
	stack.add_child(after)
	return stack
#endregion

#region Parts
static func _strip(cells: String) -> TileStrip:
	var strip := TileStrip.new()
	strip.cells = cells
	return strip

## A list board as the rooms draw it, scaled up and sized to fit.
static func _list(list_name: String, values: Array) -> Control:
	var frame := ListPicture.new()
	frame.list_name = StringName(list_name)
	frame.values = values
	frame.zoom = LIST_SCALE
	return frame

static func _label(text: String, color: Color, size := 16) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override(&"font", LABEL_FONT)
	label.add_theme_font_size_override(&"font_size", size)
	label.add_theme_color_override(&"font_color", color)
	label.add_theme_color_override(&"font_outline_color", Color(0.105882354, 0.09411765, 0.13725491))
	label.add_theme_constant_override(&"outline_size", 4)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

static func _arrow_down() -> Control:
	var arrow := GuideArrow.new()
	arrow.custom_minimum_size = Vector2(24, 26)
	arrow.from = Vector2(0.5, 0.0)
	arrow.to = Vector2(0.5, 1.0)
	arrow.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return arrow

static func _row(gap: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", gap)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return row

static func _column(gap: int) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override(&"separation", gap)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return column

static func _centered(children: Array) -> Control:
	var row := _row(0)
	for child: Control in children:
		row.add_child(child)
	return row
#endregion
