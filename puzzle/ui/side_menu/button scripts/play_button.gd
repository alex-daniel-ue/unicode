extends Button


func _ready() -> void:
	pressed.connect($"/root/Puzzle".run_program)
