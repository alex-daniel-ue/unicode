extends ColorRect


@onready var stars_label := $MarginContainer/Label


func _ready() -> void:
	var total := 0
	for key in Game.level_star_counts:
		total += Game.level_star_counts[key]
	
	stars_label.text = "STARS: %d/6" % total

func _on_home_button_pressed() -> void:
	Transition.change_scene(Core.MAIN_MENU)

func _on_button_pressed() -> void:
	Game.pending_level = load("res://puzzle/level/levels/level_1/level_1.tscn")
	Game.start_puzzle()

func _on_button_2_pressed() -> void:
	Game.pending_level = load("res://puzzle/level/levels/level_2/level_2.tscn")
	Game.start_puzzle()
