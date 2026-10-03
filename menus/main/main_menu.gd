extends Control

const MENU := "MarginContainer/HBoxContainer/PanelContainer/VBoxContainer"


func _ready() -> void:
	# The logo pops in, then the buttons arrive one after another.
	UiMotion.pop_in(get_node(MENU + "/PanelContainer"), 0.3)
	UiMotion.stagger_in(get_node(MENU + "/VBoxContainer").get_children(), 0.06)

func _on_start_button_pressed() -> void:
	Transition.change_scene(Core.LEVEL_SELECT)

func _on_exit_button_pressed() -> void:
	get_tree().quit()
