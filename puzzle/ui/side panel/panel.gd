class_name SidePanel
extends Panel


const VIEWPORT_RATIO := 1. / 3.5

var is_open := false
var keep_state := false

var expand_size: float
var shown_content: Control


func _ready() -> void:
	get_viewport().size_changed.connect(_update_expand_size)
	_update_expand_size()

func show_menu(to_open: bool) -> void:
	if keep_state:
		return
	
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
	var was_open := is_open
	if not is_open:
		show_menu(true)
	elif shown_content == control:
		show_menu(false)

	_switch_to(control)
	if is_open != was_open:
		Tutorial.panel_toggled.emit(self, is_open)

## Opens the panel on `control`. Unlike show_content(), calling this on the
## already-visible tab won't toggle the panel shut.
func focus_content(control: Control) -> void:
	if not is_open:
		show_menu(true)

	_switch_to(control)

## Shows `control` and hides the other tabs, fading the new one in when it is a
## different tab from the one already showing.
func _switch_to(control: Control) -> void:
	var changed := shown_content != control
	for child in get_children():
		child.visible = child == control
	shown_content = control
	if changed and control != null:
		UiMotion.fade_in(control, 0.16)

func _update_expand_size() -> void:
	expand_size = get_viewport_rect().size.x * VIEWPORT_RATIO
	if is_open:
		custom_minimum_size.x = expand_size
