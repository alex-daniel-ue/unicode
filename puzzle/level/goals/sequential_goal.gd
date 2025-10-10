extends Goal


var goals: Array[Goal]
var current_goal := 0


func _ready() -> void:
	for child in get_children():
		if child is Goal:
			goals.append(child as Goal)
			child.completion_changed.connect(_on_goal_completion_changed)
	
	if goals.is_empty():
		is_complete = true
		return
	
	for i in range(len(goals)):
		goals[i].active = (i == 0)

func _on_goal_completion_changed() -> void:
	if current_goal >= len(goals):
		return
	
	if goals[current_goal].is_complete:
		advance_sequence()

func advance_sequence() -> void:
	goals[current_goal].active = false
	
	current_goal += 1
	if current_goal >= len(goals):
		is_complete = true
	else:
		goals[current_goal].active = true
