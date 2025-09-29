extends Panel


const VIEWPORT_RATIO := 1. / 3.5

var is_open := false
var keep := false

var expand_size: float
var shown_content: Control


func _ready() -> void:
	_update_expand_size()
	get_viewport().size_changed.connect(_update_expand_size)

func show_menu(to_open: bool) -> void:
	if keep: return
	
	is_open = to_open
	
	var destination := Vector2(
		expand_size if to_open else 0.0,
		custom_minimum_size.y
	)
	
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "custom_minimum_size", destination, 0.2)

func show_content(control: Control) -> void:
	if not is_open:
		show_menu(true)
	elif shown_content == control:
		show_menu(false)
	
	for child in get_children():
		child.visible = child == control
	
	shown_content = control

func _update_expand_size() -> void:
	expand_size = get_viewport_rect().size.x * VIEWPORT_RATIO
	if is_open:
		custom_minimum_size.x = expand_size
