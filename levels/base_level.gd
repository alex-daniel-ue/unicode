class_name BaseLevel
extends Node2D


@onready var goal_checker := $GoalChecker


func reset() -> void:
	for entity in get_all_entities():
		assert(entity.has_method(&"reset"))
		entity.reset()

func get_all_entities() -> Array[Node2D]:
	var result: Array[Node2D]
	for child in Utils.get_children(self):
		if child.find_child("EntityData", false) != null:
			result.append(child)
	return result
