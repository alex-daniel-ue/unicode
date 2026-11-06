class_name Notification
extends PanelContainer
## One toast: it fades in, stays long enough to be read, and fades out. Its
## border is the colour of its type.

enum Type {
	LOG,
	ERROR,
	SUCCESS,
}

const COLORS: Dictionary[Type, Color] = {
	Type.LOG: Color("#38BDF8"),
	Type.ERROR: Color("#FB7185"),
	Type.SUCCESS: Color("#34D399"),
}
const MIN_TIME := 2.0
const MAX_TIME := 8.0
const BASE_TIME := 1.2
## About 175 words a minute.
const CHARS_PER_SEC := 14.0
## The widest a notification gets, as a share of the stack's width; its text
## wraps past that, as a chat bubble's does (chat_bubble.gd).
const MAX_WIDTH_RATIO := 0.85

@export var label: Label

var type: Type
## Run when the toast is clicked, if valid.
var action: Callable


func _ready() -> void:
	var stylebox := (get_theme_stylebox("panel") as StyleBoxFlat).duplicate(true)
	stylebox.border_color = COLORS[type]
	add_theme_stylebox_override("panel", stylebox)

	_fit()
	var stack := get_parent() as Control
	if stack != null:
		stack.resized.connect(_fit)

	modulate.a = 0.0
	var tween_in := create_tween()
	tween_in.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween_in.tween_property(self, "modulate:a", 1.0, 0.25)

	var duration := reading_time(label.text)
	await get_tree().create_timer(duration / 2.0).timeout

	var tween_out := create_tween()
	tween_out.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUART)
	tween_out.tween_property(self, "modulate:a", 0.0, duration / 2.0)
	tween_out.finished.connect(queue_free)


func _gui_input(event: InputEvent) -> void:
	if not action.is_valid():
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		action.call()
		queue_free()


## The label as wide as its text, up to MAX_WIDTH_RATIO of the stack, and
## wrapped onto more lines past that.
func _fit() -> void:
	var stack := get_parent() as Control
	if stack == null:
		return
	var font := label.get_theme_font(&"font")
	var font_size := label.get_theme_font_size(&"font_size")
	var text_width := font.get_multiline_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var max_width := stack.size.x * MAX_WIDTH_RATIO - get_theme_stylebox(&"panel").get_minimum_size().x
	label.custom_minimum_size.x = clampf(ceilf(text_width) + 2.0, 0.0, maxf(max_width, 0.0))


## How long `text` stays on screen, in seconds: long enough to read it.
func reading_time(text: String) -> float:
	return clampf(BASE_TIME + text.length() / CHARS_PER_SEC, MIN_TIME, MAX_TIME)


func set_action(callable: Callable) -> void:
	action = callable
	if action.is_valid():
		mouse_filter = Control.MOUSE_FILTER_STOP  # only clickable ones eat canvas clicks
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
