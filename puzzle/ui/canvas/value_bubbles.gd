class_name ValueBubbles
extends Control

## What each expression came to while the program runs, shown on the block that
## worked it out: a small tag at the block's top-right corner, the way Python
## Tutor and Thonny show values next to the code. `item i of route` shows 3,
## `s >= 75` shows True, and the `i` inside shows 0. Literals show nothing,
## since the block already says what they are, and neither does a list's name,
## since its shelf is in the room.
##
## A block evaluating its parameters again clears what they showed last time, so
## nothing on screen is older than the pass it belongs to, and the right side of
## an and/or that never ran says so. Tags stay after the run (an error is easier
## to read with them) until the next click, key or drag.
##
## Sits over the canvas and under the side panels, and lays its tags out every
## frame from the blocks' rectangles, so they follow panning and zooming.

const MAX_CHARS := 14
## How far a tag reaches into its block, before scaling: enough to say whose it is.
const OVERLAP := Vector2(6, 8)
const FADE_IN := 0.12
const TRUE_COLOR := Color("#7dd3a0")
const FALSE_COLOR := Color("#fb7185")
const TEXT_COLOR := Color("#ffd166")
const SKIPPED_COLOR := Color(0.62, 0.64, 0.7)

@export var template: PanelContainer

var _bubbles: Dictionary[Block, PanelContainer] = {}


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	template.visible = false
	Interpreter.value_shown.connect(_on_value_shown)
	Interpreter.value_skipped.connect(_on_value_skipped)
	Interpreter.values_cleared.connect(_on_values_cleared)
	Interpreter.running_changed.connect(_on_running_changed)

func _process(_delta: float) -> void:
	if not _bubbles.is_empty():
		_layout()

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_BEGIN:
		clear()

func _input(event: InputEvent) -> void:
	if Interpreter.is_running or _bubbles.is_empty():
		return
	var clicked: bool = event is InputEventMouseButton and event.pressed \
			and not (event as InputEventMouseButton).button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]
	if clicked or (event is InputEventKey and event.pressed):
		clear()

func clear() -> void:
	for bubble in _bubbles.values():
		bubble.queue_free()
	_bubbles.clear()


#region Signals
func _on_running_changed() -> void:
	if Interpreter.is_running:
		clear()

func _on_value_shown(block: Block, value: Variant) -> void:
	var shown := _shown(block, value)
	if shown.is_empty():
		_remove(block)
		return
	_put(block, shown[0], shown[1])

func _on_value_skipped(block: Block) -> void:
	_put(block, "skipped", SKIPPED_COLOR)

func _on_values_cleared(block: Block) -> void:
	for other in _bubbles.keys():  # untyped: a key may be a freed block
		if not is_instance_valid(other) or block.is_ancestor_of(other):
			_remove(other)
#endregion


## [text, colour] for a value, or empty when there's nothing to add to what the
## block already says.
func _shown(block: Block, value: Variant) -> Array:
	if typeof(value) == TYPE_STRING_NAME:
		# A name: a variable shows its value now; a list's name shows nothing.
		if not Interpreter.has_var(value):
			return []
		value = Interpreter.read_var(value)
	elif block is ValueBlock:
		return []  # a literal: the block already says it
	if value == null or value is Object:
		return []
	var text := Core.to_python_repr(value)
	if text.length() > MAX_CHARS:
		text = text.left(MAX_CHARS - 1) + "…"
	var color := Color.WHITE
	if typeof(value) == TYPE_BOOL:
		color = TRUE_COLOR if value else FALSE_COLOR
	elif typeof(value) == TYPE_STRING:
		color = TEXT_COLOR
	return [text, color]

func _put(block: Block, text: String, color: Color) -> void:
	var bubble: PanelContainer = _bubbles.get(block)
	if bubble == null:
		bubble = template.duplicate() as PanelContainer
		add_child(bubble)
		bubble.visible = true
		bubble.modulate.a = 0.0
		create_tween().tween_property(bubble, "modulate:a", 1.0, FADE_IN)
		_bubbles[block] = bubble
	var label := bubble.get_child(0) as Label
	label.text = text
	label.add_theme_color_override(&"font_color", color)
	bubble.reset_size()

func _remove(block: Variant) -> void:
	var bubble: PanelContainer = _bubbles.get(block)
	if bubble != null:
		bubble.queue_free()
	_bubbles.erase(block)

## Each tag at its block's top-right corner, outer expressions first; a tag that
## would cover one already placed slides left along the line until it doesn't.
func _layout() -> void:
	var order: Array = _bubbles.keys().filter(func(b: Variant) -> bool: return is_instance_valid(b))
	order.sort_custom(func(a: Block, b: Block) -> bool: return _depth(a) < _depth(b))
	var placed: Array[Rect2] = []
	for block: Block in order:
		var bubble := _bubbles[block]
		bubble.visible = block.is_visible_in_tree()
		if not bubble.visible:
			continue
		var zoom := block.get_global_transform().get_scale()
		var rect := block.get_global_rect()
		var tag_size := bubble.get_combined_minimum_size() * zoom
		var at := Rect2(
			Vector2(rect.end.x - tag_size.x + OVERLAP.x * zoom.x, rect.position.y - tag_size.y + OVERLAP.y * zoom.y),
			tag_size)
		for other in placed:
			if at.intersects(other):
				at.position.x = other.position.x - tag_size.x - 2.0 * zoom.x
		placed.append(at)
		bubble.scale = zoom
		bubble.global_position = at.position

	for block in _bubbles.keys():
		if not is_instance_valid(block):
			_bubbles[block].queue_free()
			_bubbles.erase(block)

func _depth(block: Block) -> int:
	var depth := 0
	var parent := block.get_parent_block()
	while parent != null:
		depth += 1
		parent = parent.get_parent_block()
	return depth
