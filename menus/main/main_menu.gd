extends Control


func _on_start_button_pressed() -> void:
	Transition.cover()
	await Transition.current_tween.finished
	get_tree().scene_changed.connect(Transition.reveal, CONNECT_ONE_SHOT)
	
	get_tree().change_scene_to_file("res://menus/level select/level_select.tscn")

func _on_exit_button_pressed() -> void:
	get_tree().quit()

func _on_settings_button_pressed() -> void:
	Settings.show()
