class_name ChatBubble
extends HBoxContainer
## One message in the assistant's chat: the student's on the right, the
## assistant's on the left, as wide as its text up to MAX_WIDTH_RATIO of the chat.

const MAX_WIDTH_RATIO := 0.85

@export_group("Children")
@export var panel: PanelContainer
@export var label: RichTextLabel
## The assistant's robot, beside its messages; not beside the student's.
@export var avatar: TextureRect
## The assistant's robot, beside its messages; not beside the student's.
@export var avatar: TextureRect

var bubble_theme := BubbleTheme.new():
	set(value):
		bubble_theme = value
		panel.self_modulate = bubble_theme.background
		label.add_theme_color_override("default_color", bubble_theme.font)
var text: String = "":
	set(value):
		text = value
		_update_bubble()
var right_aligned := false:
	set(value):
		right_aligned = value
		_update_alignment()
## Taken away by the next message: "Thinking...", and a message that failed.
var is_temporary := false


func _ready() -> void:
	_update_alignment()
	_update_bubble()


func _update_alignment() -> void:
	alignment = BoxContainer.ALIGNMENT_END if right_aligned else BoxContainer.ALIGNMENT_BEGIN
	avatar.visible = not right_aligned


func _update_bubble() -> void:
	label.text = text
	var font := label.get_theme_font(&"normal_font")
	var font_size := label.get_theme_font_size(&"normal_font_size")
	var text_width := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	text_width += label.get_theme_stylebox(&"normal").get_minimum_size().x

	var max_label_width := size.x * MAX_WIDTH_RATIO - panel.get_theme_stylebox(&"panel").get_minimum_size().x
	if avatar.visible:
		max_label_width -= avatar.get_combined_minimum_size().x + get_theme_constant(&"separation")
	label.custom_minimum_size.x = clampf(ceilf(text_width) + 2.0, 0.0, maxf(max_label_width, 0.0))
