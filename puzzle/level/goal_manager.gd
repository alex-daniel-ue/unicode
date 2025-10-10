@tool
extends Node


@export var goals: Array[Goal]

@onready var level := $".."


func _ready() -> void:
	goals.clear()
	for node in get_children():
		if node is Goal:
			goals.append(node as Goal)
			node.completion_changed.connect(_goal_completion_changed)

func _goal_completion_changed() -> void:
	for goal in goals:
		if not goal.is_complete:
			if goal.must_maintain:
				level.failed.emit()
			return
	
	level.completed.emit()
