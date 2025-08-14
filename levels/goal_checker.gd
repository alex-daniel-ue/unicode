extends Node


signal goal_achieved

enum GOAL_TYPE {
	COLLECT
}

@export var collect_amount_needed: int
var collected := 0:
	set = set_collected


func set_collected(value) -> void:
	collected = value
	if collected >= collect_amount_needed:
		goal_achieved.emit()
