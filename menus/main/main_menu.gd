extends Control
@onready var tutorial_menu: PopupPanel = $TutorialMenu

func _on_start_button_pressed() -> void:
	Transition.change_scene(Core.LEVEL_SELECT)

func _on_exit_button_pressed() -> void:
	get_tree().quit()


func _on_tutorials_button_pressed() -> void:
	tutorial_menu.show()
