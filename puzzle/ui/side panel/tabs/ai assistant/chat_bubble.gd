class_name ChatBubble
extends HBoxContainer


@export_group("Children")
@export var panel: PanelContainer
@export var label: RichTextLabel

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

var max_width_ratio := 0.85
var is_temporary := false


func _ready() -> void:
	_update_alignment()
	_update_bubble()

func _update_alignment() -> void:
	alignment = BoxContainer.ALIGNMENT_END if right_aligned else BoxContainer.ALIGNMENT_BEGIN

func _update_bubble() -> void:
	label.text = text
	
	var max_label_width := size.x * max_width_ratio
	
	var stylebox := panel.get_theme_stylebox("panel")
	max_label_width -= stylebox.get_margin(SIDE_LEFT) + stylebox.get_margin(SIDE_RIGHT)
	
	var font := label.get_theme_font("font")
	var font_size := label.get_theme_font_size("font_size")
	var single_line_size := font.get_multiline_string_size(
		text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size
	)
	
	label.custom_minimum_size.x = min(single_line_size.x, max_label_width)
