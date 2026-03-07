extends PopupPanel


func _on_main_menu_button_pressed() -> void:
	Transition.change_scene(Core.MAIN_MENU)

func _on_level_select_button_pressed() -> void:
	Transition.change_scene(Core.LEVEL_SELECT)
