extends PopupPanel
signal tutorials_requested 

func _on_resume_button_pressed() -> void:
	hide()

func _on_tutorials_button_pressed() -> void:
	hide() 
	tutorials_requested.emit() 

func _on_main_menu_button_pressed() -> void:
	Transition.change_scene(Core.MAIN_MENU)

func _on_level_select_button_pressed() -> void:
	Transition.change_scene(Core.LEVEL_SELECT)
