class_name PauseMenu
extends PopupPanel

## Shows this level's guide again, or skips the one on screen.
signal tutorials_requested

@onready var tutorials_button: Button = $VBoxContainer/TutorialsButton

## Called by Puzzle as the menu opens: whether the level has a guide to show,
## and whether one is showing now.
func set_tutorial_state(available: bool, running: bool) -> void:
	tutorials_button.visible = available
	tutorials_button.text = "Skip tutorial" if running else "Show tutorial again"

func _on_resume_button_pressed() -> void:
	hide()

func _on_tutorials_button_pressed() -> void:
	hide()
	tutorials_requested.emit()

func _on_main_menu_button_pressed() -> void:
	Transition.change_scene(Core.MAIN_MENU)

func _on_level_select_button_pressed() -> void:
	Transition.change_scene(Core.LEVEL_SELECT)
