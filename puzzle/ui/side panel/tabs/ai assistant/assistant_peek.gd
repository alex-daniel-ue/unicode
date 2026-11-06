class_name AssistantPeek
extends Control

## The assistant suggesting itself: the robot peeks out from behind its tab
## button, and what it says pops out of it in a bubble, in the blue of its chat
## bubbles. A click on the robot or the bubble takes the suggestion. It goes
## back behind the button after HOLD seconds, or when told to (retreat()).
##
## Puzzle puts it over the canvas, beside the button, and it follows the button
## as the side panel slides.

const ROBOT_FRAMES := preload("res://level/objects/entities/robot/sprite_frames.tres")
const ROBOT_SIZE := Vector2(32, 48)
const BODY_FONT := preload("res://puzzle/ui/themes/fonts/AtkinsonHyperlegible-Regular.ttf")
const CAPTION_FONT := preload("res://puzzle/ui/themes/fonts/Kenney Mini.ttf")
## ai_assistant.tscn's bubble_theme_ai, and that blue a little lighter for the
## pointer over it.
const BUBBLE := Color(0.388, 0.7954, 0.97)
const BUBBLE_HOVER := Color(0.56, 0.86, 0.99)
const TEXT := Color(0.007843138, 0.023529412, 0.09019608)
const OUTLINE := Color(0.03, 0.05, 0.1)
const MAX_TEXT_WIDTH := 230.0
const HOLD := 12.0
## Between the button and the robot, and the robot and the bubble's tail.
const GAP := 4.0
const TAIL := 9.0

## The button it peeks out of.
var button: Control

var _window: Control
var _robot: AnimatedSprite2D
var _bubble: PanelContainer
var _box: StyleBoxFlat
var _body: Label
var _action := Callable()
var _tween: Tween
## Bumped by each suggest() and retreat(), so an older suggestion's timer
## doesn't send a newer one away.
var _shown := 0


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	visible = false

	# The robot slides out of this window's left edge, the button's side, so
	# it looks to come from behind the button.
	_window = Control.new()
	_window.clip_contents = true
	_window.size = ROBOT_SIZE
	_window.mouse_filter = MOUSE_FILTER_STOP
	_window.mouse_default_cursor_shape = CURSOR_POINTING_HAND
	_window.gui_input.connect(_on_gui_input)
	add_child(_window)
	_robot = AnimatedSprite2D.new()
	_robot.sprite_frames = ROBOT_FRAMES
	_robot.centered = false
	_window.add_child(_robot)

	_box = StyleBoxFlat.new()
	_box.bg_color = BUBBLE
	_box.set_corner_radius_all(10)
	_box.set_border_width_all(2)
	_box.border_color = OUTLINE
	_box.content_margin_left = 12
	_box.content_margin_right = 12
	_box.content_margin_top = 8
	_box.content_margin_bottom = 8
	_bubble = PanelContainer.new()
	_bubble.add_theme_stylebox_override(&"panel", _box)
	_bubble.position = Vector2(ROBOT_SIZE.x + GAP + TAIL, -6)
	_bubble.mouse_filter = MOUSE_FILTER_STOP
	_bubble.mouse_default_cursor_shape = CURSOR_POINTING_HAND
	_bubble.gui_input.connect(_on_gui_input)
	_bubble.mouse_entered.connect(_set_bubble_color.bind(BUBBLE_HOVER))
	_bubble.mouse_exited.connect(_set_bubble_color.bind(BUBBLE))
	_bubble.draw.connect(_draw_tail)
	add_child(_bubble)

	var lines := VBoxContainer.new()
	lines.add_theme_constant_override(&"separation", 4)
	lines.mouse_filter = MOUSE_FILTER_IGNORE
	_bubble.add_child(lines)
	_body = _label(BODY_FONT, 18)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lines.add_child(_body)
	var ask := _label(CAPTION_FONT, 16)
	ask.text = "Ask me  >"
	lines.add_child(ask)

func _process(_delta: float) -> void:
	if visible:
		# Wrapped text is only as tall as it should be once it has its width,
		# and a container outside a container doesn't shrink back by itself.
		_bubble.reset_size()
		_follow()

## Peeks out saying `text`; a click on the robot or the bubble calls `action`.
func suggest(text: String, action: Callable) -> void:
	_action = action
	_body.text = text
	var text_width := BODY_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	_body.custom_minimum_size.x = minf(ceilf(text_width) + 2.0, MAX_TEXT_WIDTH)
	_bubble.reset_size()
	_shown += 1
	var shown := _shown
	if _tween != null and _tween.is_valid():
		_tween.kill()
	visible = true
	_follow()
	# Facing the player: "backward" is the robot turned toward the screen, as
	# menu_demo.gd's FACING_ANIMATION has it for down.
	_robot.play(&"idle_backward")
	_robot.position = Vector2(-ROBOT_SIZE.x, 0)
	_bubble.modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(_robot, "position:x", 0.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(UiMotion.pop_in.bind(_bubble, 0.22))
	get_tree().create_timer(HOLD).timeout.connect(_on_hold_over.bind(shown))

func _on_hold_over(shown: int) -> void:
	if shown == _shown:
		retreat()

## Back behind the button.
func retreat() -> void:
	if not visible:
		return
	_shown += 1
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_bubble, "modulate:a", 0.0, 0.12)
	_tween.tween_property(_robot, "position:x", -ROBOT_SIZE.x, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_callback(hide)

## Beside the button, level with it, on whole pixels.
func _follow() -> void:
	if not is_instance_valid(button):
		return
	var rect := button.get_global_rect()
	global_position = Vector2(rect.end.x + GAP, rect.get_center().y - ROBOT_SIZE.y / 2.0).round()

func _on_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	get_viewport().set_input_as_handled()
	var action := _action
	retreat()
	if action.is_valid():
		action.call()

func _set_bubble_color(color: Color) -> void:
	_box.bg_color = color
	_bubble.queue_redraw()

## The bubble's tail, pointing back at the robot, drawn over the bubble's
## outline where it joins.
func _draw_tail() -> void:
	var mid := 20.0
	var tip := Vector2(-TAIL, mid)
	_bubble.draw_colored_polygon(PackedVector2Array([Vector2(2, mid - 7), tip, Vector2(2, mid + 7)]), _box.bg_color)
	_bubble.draw_polyline(PackedVector2Array([Vector2(1, mid - 8), tip, Vector2(1, mid + 8)]), OUTLINE, 2.0)

func _label(font: Font, font_size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_override(&"font", font)
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", TEXT)
	label.mouse_filter = MOUSE_FILTER_IGNORE
	return label
