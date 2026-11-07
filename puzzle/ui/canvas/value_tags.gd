class_name ValueTags
extends Control
## What each expression came to while the program runs, shown on the block that
## worked it out: a small tag at the block's top-right corner, the way Python
## Tutor and Thonny show values next to the code. `i + 1` shows 3, `s >= 75`
## shows True, `index i of route` shows 4, and a slot with `i` typed in shows
## what i holds right then.
##
## Literals typed into a slot show nothing, since the block already says what
## they are, and neither does a list's name, since its board is in the room.
##
## A block evaluating its parameters again clears what they showed last time, so
## nothing on screen is older than the pass it belongs to, and the right side of
## an and/or that never ran says so. Tags stay after the run (an error is easier
## to read with them) until the next click, key or drag. When the next room
## starts, the last room's tags fade (fade_stale()): left up, they read as
## values the program carried from one room into the next.
##
## Sits over the canvas and under the side panels, and lays its tags out every
## frame from the blocks' rectangles, so they follow panning and zooming.

const MAX_CHARS := 14
## How far a tag reaches into its block, before scaling: enough to say whose it is.
const OVERLAP := Vector2(6, 8)
const FADE_IN := 0.12
const FADE_OUT := 0.25
const TRUE_COLOR := Color("#7dd3a0")
const FALSE_COLOR := Color("#fb7185")
const TEXT_COLOR := Color("#FF8F5E")  # strings, as their slots are coloured
const SKIPPED_COLOR := Color(0.62, 0.64, 0.7)
## One tag; the same scene shows a tag in the guide's pictures.
const TAG := preload("res://puzzle/ui/canvas/value_tag.tscn")

var _tags: Dictionary[Block, PanelContainer] = {}
## Tags left from the room before, still waiting to fade. A block that shows a
## new value in the meantime comes off this list.
var _stale: Dictionary[Block, bool] = {}


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	Interpreter.value_shown.connect(_on_value_shown)
	Interpreter.value_skipped.connect(_on_value_skipped)
	Interpreter.values_cleared.connect(_on_values_cleared)
	Interpreter.running_changed.connect(_on_running_changed)


func _process(_delta: float) -> void:
	if not _tags.is_empty():
		_layout()


func _input(event: InputEvent) -> void:
	if Interpreter.is_running or _tags.is_empty():
		return
	var clicked: bool = event is InputEventMouseButton and event.pressed \
			and not (event as InputEventMouseButton).button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]
	if clicked or (event is InputEventKey and event.pressed):
		clear()


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_BEGIN:
		clear()


func clear() -> void:
	for tag in _tags.values():
		tag.queue_free()
	_tags.clear()
	_stale.clear()


## A room was solved and the next one is starting: every tag on screen fades
## after `delay`, unless its block shows a new value by then.
func fade_stale(delay: float) -> void:
	for block: Variant in _tags.keys():
		if is_instance_valid(block):
			_stale[block] = true
	get_tree().create_timer(delay).timeout.connect(_fade_stale)


func _fade_stale() -> void:
	for block: Variant in _stale.keys():
		var tag: PanelContainer = _tags.get(block)
		_tags.erase(block)
		if is_instance_valid(tag):
			var tween := tag.create_tween()
			tween.tween_property(tag, "modulate:a", 0.0, FADE_OUT)
			tween.tween_callback(tag.queue_free)
	_stale.clear()


## [text, colour] for a value, or empty when there's nothing to add to what the
## block already says.
func _shown(block: Block, value: Variant) -> Array:
	if _typed_into(block):
		# A literal says what it is already. A variable's name gets its value,
		# read now, as the block using it is about to.
		if typeof(value) != TYPE_STRING_NAME or not Interpreter.has_var(value):
			return []
		value = Interpreter.read_var(value)
	elif typeof(value) == TYPE_STRING_NAME:
		return []
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


## A slot the student types into or picks from, as opposed to a rounded block
## that works something out (index of, length of, math), which shares its look.
func _typed_into(block: Block) -> bool:
	return block is ValueBlock and block.data.value != null and block.data.value.editable_shown


func _put(block: Block, text: String, color: Color) -> void:
	_stale.erase(block)
	var tag: PanelContainer = _tags.get(block)
	if tag == null:
		tag = TAG.instantiate() as PanelContainer
		add_child(tag)
		tag.modulate.a = 0.0
		create_tween().tween_property(tag, "modulate:a", 1.0, FADE_IN)
		_tags[block] = tag
	var label := tag.get_child(0) as Label
	label.text = text
	label.add_theme_color_override(&"font_color", color)
	tag.reset_size()


func _remove(block: Variant) -> void:
	var tag: PanelContainer = _tags.get(block)
	if tag != null:
		tag.queue_free()
	_tags.erase(block)


## Each tag at its block's top-right corner, outer expressions first; a tag that
## would cover one already placed slides left along the line until it doesn't.
func _layout() -> void:
	var order: Array = _tags.keys().filter(func(b: Variant) -> bool: return is_instance_valid(b))
	order.sort_custom(func(a: Block, b: Block) -> bool: return _depth(a) < _depth(b))
	var placed: Array[Rect2] = []
	for block: Block in order:
		var tag := _tags[block]
		tag.visible = block.is_visible_in_tree()
		if not tag.visible:
			continue
		var zoom := block.get_global_transform().get_scale()
		var rect := block.get_global_rect()
		var tag_size := tag.get_combined_minimum_size() * zoom
		var at := Rect2(
			Vector2(rect.end.x - tag_size.x + OVERLAP.x * zoom.x, rect.position.y - tag_size.y + OVERLAP.y * zoom.y),
			tag_size)
		for other in placed:
			if at.intersects(other):
				at.position.x = other.position.x - tag_size.x - 2.0 * zoom.x
		placed.append(at)
		tag.scale = zoom
		tag.global_position = at.position

	for block in _tags.keys():
		if not is_instance_valid(block):
			_tags[block].queue_free()
			_tags.erase(block)


func _depth(block: Block) -> int:
	var depth := 0
	var parent := block.get_parent_block()
	while parent != null:
		depth += 1
		parent = parent.get_parent_block()
	return depth


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
	for other in _tags.keys():  # untyped: a key may be a freed block
		if not is_instance_valid(other) or block.is_ancestor_of(other):
			_remove(other)
