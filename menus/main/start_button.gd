extends Button


func _on_pressed() -> void:
	Transition.cover()
	await Transition.current_tween.finished
	get_tree().scene_changed.connect(Transition.reveal, CONNECT_ONE_SHOT)
	
	get_tree().change_scene_to_file("res://menus/level select/level_select.tscn")
