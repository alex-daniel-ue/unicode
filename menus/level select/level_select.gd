extends ColorRect


@export var button_level_configuration: Dictionary[Button, PackedScene]


func _ready() -> void:
	for btn: Button in button_level_configuration.keys():
		var scn := button_level_configuration[btn]
		btn.pressed.connect(_on_button_pressed.bind(scn))

func _on_home_button_pressed() -> void:
	Transition.change_scene(Core.MAIN_MENU)

func _on_button_pressed(level: PackedScene) -> void:
	Game.level = level.instantiate() as Level
	Transition.change_scene(Core.PUZZLE_CANVAS)
