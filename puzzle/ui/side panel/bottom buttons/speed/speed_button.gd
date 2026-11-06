extends Button
## Speeds the running program up, and back down. The icon stays the same; it's
## blue while the program runs fast. Disabled (nothing running), it fades as
## the other side panel buttons do, fast or not.

## The theme's own blue for a pressed side panel button.
const FAST_COLOR := Color(0.21960784, 0.7411765, 0.972549)
const TINTED := [&"icon_normal_color", &"icon_hover_color", &"icon_focus_color", &"icon_pressed_color", &"icon_hover_pressed_color"]


func _ready() -> void:
	_update_look()


func _update_look() -> void:
	for item: StringName in TINTED:
		if Interpreter.is_fast:
			add_theme_color_override(item, FAST_COLOR)
		else:
			remove_theme_color_override(item)
	tooltip_text = "Back to normal speed" if Interpreter.is_fast else "Speed up"


func _on_pressed() -> void:
	_update_look.call_deferred()  # after button_manager.gd flips Interpreter.is_fast
