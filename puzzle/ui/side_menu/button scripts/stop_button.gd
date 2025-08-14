extends Button


func _ready() -> void:
	pressed.connect($"/root/Puzzle".force_stop_program)
