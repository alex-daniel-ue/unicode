extends PopupPanel


const MAIN_MENU_SCENE := preload("res://menus/main/main_menu.tscn")

func _on_return_button_5_pressed() -> void:
	hide()
	
	Transition.cover()
	await Transition.current_tween.finished
	get_tree().scene_changed.connect(Transition.reveal, CONNECT_ONE_SHOT)
	
	get_tree().change_scene_to_packed(MAIN_MENU_SCENE)


func _on_return_button_7_pressed() -> void:
	hide()
	
	Transition.cover()
	await Transition.current_tween.finished
	get_tree().scene_changed.connect(Transition.reveal, CONNECT_ONE_SHOT)
	
	get_tree().change_scene_to_file("res://menus/level select/level_select.tscn")


func _on_return_button_4_pressed() -> void:
	Settings.show()
	hide()
