extends ColorRect


const MAIN_MENU_SCENE := preload("res://menus/main/main_menu.tscn")

@onready var stars_label := $MarginContainer/Label


func _ready() -> void:
	var total := 0
	for key in Game.level_star_counts:
		total += Game.level_star_counts[key]
	
	stars_label.text = "STARS: %d/6" % total

func _on_home_button_pressed() -> void:
	Transition.cover()
	await Transition.current_tween.finished
	get_tree().scene_changed.connect(Transition.reveal, CONNECT_ONE_SHOT)
	
	get_tree().change_scene_to_packed(MAIN_MENU_SCENE)

func _on_button_pressed() -> void:
	Game.pending_level = load("res://puzzle/level/levels/level_1/level_1.tscn")
	Game.start_puzzle()

func _on_button_2_pressed() -> void:
	Game.pending_level = load("res://puzzle/level/levels/level_2/level_2.tscn")
	Game.start_puzzle()
