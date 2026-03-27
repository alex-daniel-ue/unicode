extends ColorRect

@export var button_level_configuration: Dictionary[Button, PackedScene]

@onready var level_label: Label = $MarginContainer/LevelLabel
@onready var prev_button: Button = $MarginContainer/HBoxContainer/PrevButton
@onready var next_button: Button = $MarginContainer/HBoxContainer/NextButton
@onready var grid_container: GridContainer = $MarginContainer/GridContainer

const MODULES: PackedStringArray = [
	"Fundamentals", "Variables", "Operators", "Selection", "Loops", "Functions", "Lists"
]
var current_module_index := 0

func _ready() -> void:
	# Connect level buttons
	for btn: Button in button_level_configuration.keys():
		var scn := button_level_configuration[btn]
		btn.pressed.connect(_on_button_pressed.bind(scn))
		
	# Connect navigation buttons
	prev_button.pressed.connect(_on_prev_button_pressed)
	next_button.pressed.connect(_on_next_button_pressed)
	
	_update_module_display()

func _on_home_button_pressed() -> void:
	Transition.change_scene(Core.MAIN_MENU)

func _on_button_pressed(level: PackedScene) -> void:
	Game.level = level.instantiate() as Level
	Transition.change_scene(Core.PUZZLE_CANVAS)

func _on_prev_button_pressed() -> void:
	if current_module_index > 0:
		current_module_index -= 1
		_update_module_display()

func _on_next_button_pressed() -> void:
	if current_module_index < MODULES.size() - 1:
		current_module_index += 1
		_update_module_display()

func _update_module_display() -> void:
	# Update the label text
	level_label.text = MODULES[current_module_index]
	
	# Disable arrows if at the start or end of the modules list
	prev_button.disabled = (current_module_index == 0)
	next_button.disabled = (current_module_index == MODULES.size() - 1)
	
	# Smoke and mirrors: Check if we are on the playable "Fundamentals" module
	var is_fundamentals := current_module_index == 0
	
	for child in grid_container.get_children():
		if child is Button:
			if is_fundamentals:
				# Enable only if the button is configured with a level in the inspector
				# This keeps buttons 6, 7, and 8 correctly disabled
				child.disabled = not button_level_configuration.has(child)
			else:
				# Disable all buttons to fake them being locked or "Coming Soon"
				child.disabled = true
