extends Control


func _on_start_button_pressed() -> void:
	Transition.change_scene("res://menus/level select/level_select.tscn")

func _on_exit_button_pressed() -> void:
	get_tree().quit()
