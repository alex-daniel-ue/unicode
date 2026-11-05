@tool
class_name TerminalEntity
extends RoomEntity
## A terminal standing in a room: the screen where Print shows its lines, and,
## under it, what the user types, waiting for Input to read it. It is Python's
## console made into an object in the room, so print() and input() have
## somewhere to be seen.
##
## One terminal per room, each with its own typed lines. A room is then one run
## of the program with one set of typed lines, the way a CodeChum exercise shows
## Sample Output 1, 2 and 3: one program has to work for all of them, so typing
## a room's answer in doesn't pass.
##
## What the user types are chips in the colour of text, because input() always
## gives text, even when the user types a number; that is the first thing a
## student trips on (`step forward input() times`). A TerminalGoal shows the
## lines the screen should end up with, faded, in their places; each printed
## line turns green when it matches its line and red when it doesn't.
##
## Drawn in _draw() rather than built from Labels: the screen grows a line at a
## time, and the room's framing (get_global_bounds) and the level generator
## both work out its size from the same numbers.

const CAPTION_SIZE := 8
## The bezel round the screen, the screen's padding, and a line of text.
const BEZEL := 4.0
const PAD := 6.0
const LINE_H := 20.0
## The strip under the screen that shows what the user types.
const STRIP_H := 26.0
const CHIP_PAD := 4.0
const CHIP_GAP := 4.0
const CAPTION_W := 30.0
const LEG_H := 8.0
const MIN_SCREEN_W := 120.0
## More lines than this is a runaway loop, not a program's output.
const MAX_LINES := 40
const BEZEL_COLOR := Color("#c9d1de")
const BEZEL_EDGE := Color("#7d8aa3")
const SCREEN_COLOR := Color("#151a2e")
const STRIP_COLOR := Color("#e9edf3")
const LEG_COLOR := Color("#5c6474")
const TEXT_COLOR := Color("#e8ecf4")
const GHOST_COLOR := Color(0.62, 0.68, 0.8, 0.5)
const RIGHT_COLOR := Color("#86efac")
const WRONG_COLOR := Color("#fca5a5")
## Text's own colour on a value slot (visual_component_value.gd).
const CHIP_COLOR := Color("#ff8f5e")
const CHIP_TEXT := Color("#1d2433")
const CAPTION_COLOR := Color("#5b6478")

## What the user types in this room, a line each, in the order Input reads them.
@export var inputs: PackedStringArray = []:
	set(value):
		inputs = value
		queue_redraw()

## What the program has printed in this room's run, a line each.
var printed: PackedStringArray = []
## How many typed lines Input has read.
var used := 0

var _expected: PackedStringArray = []
var _has_target := false
## The line or the chip just written or read, glowing for a moment.
var _flash_line := -1
var _flash_chip := -1
var _flash := 0.0


## The terminal a block means right now: the only one, or the running room's.
static func find() -> TerminalEntity:
	return find_named(TerminalEntity, &"") as TerminalEntity


## Size of a terminal with `rows` lines on a screen `screen_w` wide. Shared with
## the level generator's numbers (tools/modules/gen_modules.py).
static func size_for(rows: int, screen_w: float, has_strip: bool, with_legs: bool) -> Vector2:
	var h := BEZEL * 2.0 + PAD * 2.0 + rows * LINE_H
	if has_strip:
		h += STRIP_H
	if with_legs:
		h += LEG_H
	return Vector2(screen_w + BEZEL * 2.0, h)


func _ready() -> void:
	super()
	queue_redraw()


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 2.5)
		queue_redraw()


func _draw() -> void:
	var rows := _rows()
	var screen_w := _screen_width()
	var has_strip := not inputs.is_empty()
	var body := size_for(rows, screen_w, has_strip, false)

	# The stand, then the bezel, then the screen inside it.
	draw_rect(Rect2(body.x * 0.25 - 2.0, body.y, 4.0, LEG_H), LEG_COLOR)
	draw_rect(Rect2(body.x * 0.75 - 2.0, body.y, 4.0, LEG_H), LEG_COLOR)
	_draw_box(Rect2(Vector2.ZERO, body), BEZEL_COLOR, BEZEL_EDGE, 4)
	var screen := Rect2(BEZEL, BEZEL, screen_w, PAD * 2.0 + rows * LINE_H)
	_draw_box(screen, SCREEN_COLOR, SCREEN_COLOR.darkened(0.3), 2)

	for i in rows:
		var top := screen.position.y + PAD + i * LINE_H
		var at := Vector2(screen.position.x + PAD, top + 16.0)
		if i == _flash_line and _flash > 0.0:
			draw_rect(Rect2(screen.position.x + 2.0, top, screen_w - 4.0, LINE_H), Color(FLASH_COLOR, 0.25 * _flash))
		if i < printed.size():
			var color := TEXT_COLOR
			if _has_target:
				color = RIGHT_COLOR if i < _expected.size() and printed[i] == _expected[i] else WRONG_COLOR
			draw_string(FONT, at, printed[i], HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, color)
		elif i < _expected.size():
			draw_string(FONT, at, _expected[i], HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, GHOST_COLOR)

	if has_strip:
		var strip := Rect2(BEZEL, screen.end.y, screen_w, STRIP_H)
		draw_rect(strip, STRIP_COLOR)
		draw_string(FONT, Vector2(strip.position.x + 3.0, strip.position.y + 11.0), "user", HORIZONTAL_ALIGNMENT_LEFT, -1, CAPTION_SIZE, CAPTION_COLOR)
		draw_string(FONT, Vector2(strip.position.x + 3.0, strip.position.y + 20.0), "types", HORIZONTAL_ALIGNMENT_LEFT, -1, CAPTION_SIZE, CAPTION_COLOR)
		var x := strip.position.x + CAPTION_W
		for i in inputs.size():
			var w := text_width(inputs[i]) + CHIP_PAD * 2.0
			var chip := Rect2(x, strip.position.y + 3.0, w, STRIP_H - 6.0)
			var color := CHIP_COLOR if i >= used else CHIP_COLOR.lerp(STRIP_COLOR, 0.65)
			if i == _flash_chip and _flash > 0.0:
				color = color.lerp(FLASH_COLOR, _flash)
			_draw_box(chip, color, color.darkened(0.25), 4)
			draw_string(FONT, Vector2(chip.position.x + CHIP_PAD, chip.position.y + 16.0), inputs[i], HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, CHIP_TEXT if i >= used else CHIP_TEXT.lerp(STRIP_COLOR, 0.5))
			x += w + CHIP_GAP


## One terminal per room, so a terminal has no name a block uses.
func get_entity_name() -> StringName:
	return &""


## Nothing printed and nothing read yet.
func restore() -> void:
	printed.clear()
	used = 0
	_flash = 0.0
	queue_redraw()


func get_global_bounds() -> Rect2:
	return global_transform * Rect2(Vector2.ZERO, size_for(_rows(), _screen_width(), not inputs.is_empty(), true))


#region Queries
## True when what was printed is exactly `expected`, line for line.
func matches(expected: PackedStringArray) -> bool:
	return printed == expected


## Called by a TerminalGoal: the lines the screen should end up with.
func set_target(expected: PackedStringArray) -> void:
	_expected = expected.duplicate()
	_has_target = true
	queue_redraw()


## Why the screen isn't right yet, for a goal's fail message: the first line
## that differs, in Python's quotes. Empty when it is right.
func mismatch() -> String:
	for i in maxi(printed.size(), _expected.size()):
		var got := printed[i] if i < printed.size() else ""
		var want := _expected[i] if i < _expected.size() else ""
		if i < printed.size() and i < _expected.size() and got == want:
			continue
		if i >= printed.size():
			return "Line %d of the terminal should say %s, but nothing was printed there." % [i + 1, Core.to_python_repr(want)]
		if i >= _expected.size():
			return "Line %d of the terminal says %s, but nothing should be printed there." % [i + 1, Core.to_python_repr(got)]
		return "Line %d of the terminal should say %s, but it says %s." % [i + 1, Core.to_python_repr(want), Core.to_python_repr(got)]
	return ""


## What the terminal shows, for the assistant: what the user types, what was
## printed, and what should be.
func describe() -> String:
	var parts := PackedStringArray()
	parts.append("the user types %s" % Core.to_python_repr(Array(inputs)))
	parts.append("printed so far %s" % Core.to_python_repr(Array(printed)))
	if _has_target:
		parts.append("it should show %s" % Core.to_python_repr(Array(_expected)))
	return "; ".join(parts)
#endregion


#region What blocks do
## Prints `text`, one line per line of it, as print() does with "\n" in it.
## False when the screen is full, so the block can say so.
func write_text(text: String) -> bool:
	for line in text.split("\n"):
		if printed.size() >= MAX_LINES:
			return false
		printed.append(line)
	_flash_line = printed.size() - 1
	_flash_chip = -1
	_flash = 1.0
	queue_redraw()
	return true


## The next line the user typed, or null when they typed nothing more.
func read_input() -> Variant:
	if used >= inputs.size():
		return null
	var line := inputs[used]
	_flash_chip = used
	_flash_line = -1
	_flash = 1.0
	used += 1
	queue_redraw()
	return line
#endregion


func _rows() -> int:
	return maxi(1, maxi(printed.size(), _expected.size()))


func _screen_width() -> float:
	var widest := 0.0
	for line in printed:
		widest = maxf(widest, text_width(line))
	for line in _expected:
		widest = maxf(widest, text_width(line))
	var strip := CAPTION_W
	for line in inputs:
		strip += text_width(line) + CHIP_PAD * 2.0 + CHIP_GAP
	return maxf(MIN_SCREEN_W, maxf(widest + PAD * 2.0, strip + PAD))
