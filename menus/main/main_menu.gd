extends Control

const MENU := "MarginContainer/HBoxContainer/PanelContainer/VBoxContainer"
const QUIT := "PopupPanel"
const QUIT_CODE := "PopupPanel/VBoxContainer/CodeRow"
## The code flashes this colour a few times when the quit popup opens: leaving
## is the last chance to copy it, and a code sitting quietly in a dialog was
## walked past.
const FLASH := Color(1.0, 0.82, 0.3)
const FLASHES := 3


func _ready() -> void:
	# The logo pops in, then the buttons arrive one after another, and the demo
	# fades in beside them.
	UiMotion.pop_in(get_node(MENU + "/PanelContainer"), 0.3)
	UiMotion.stagger_in(get_node(MENU + "/VBoxContainer").get_children(), 0.06)
	UiMotion.fade_in(get_node(^"Demo") as CanvasItem, 0.5)

func _on_start_button_pressed() -> void:
	Transition.change_scene(Core.LEVEL_SELECT)

## Exit asks first, and shows the progress code while it asks, once there are
## stars to keep.
func _on_quit_pressed() -> void:
	var popup := get_node(QUIT) as PopupPanel
	var has_stars := Progress.total_stars() > 0
	var code := get_node(QUIT_CODE + "/Code") as Label
	code.text = Progress.get_code()
	(get_node(QUIT_CODE) as Control).visible = has_stars
	(get_node(QUIT + "/VBoxContainer/CodeCaption") as Control).visible = has_stars
	(get_node(QUIT_CODE + "/CopyButton") as Button).text = "Copy"
	popup.reset_size()
	popup.popup_centered()
	if has_stars:
		_flash(code)

func _flash(label: Label) -> void:
	label.modulate = Color.WHITE
	var tween := label.create_tween()
	for i in FLASHES:
		tween.tween_property(label, "modulate", FLASH, 0.14)
		tween.tween_property(label, "modulate", Color.WHITE, 0.3)
	tween.tween_property(label, "modulate", FLASH, 0.14)

func _on_copy_code_pressed() -> void:
	DisplayServer.clipboard_set(Progress.get_code())
	(get_node(QUIT_CODE + "/CopyButton") as Button).text = "Copied"

func _on_exit_button_pressed() -> void:
	get_tree().quit()
