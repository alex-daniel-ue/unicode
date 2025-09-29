extends Node2D


@export var label: Label

var current_interactions: Array[Interactable]


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and not current_interactions.is_empty():
		var nearest_interactable := current_interactions[0]
		
		if is_instance_valid(nearest_interactable):
			nearest_interactable.interact()

func _process(_delta: float) -> void:
	label.hide()
	
	if not current_interactions.is_empty():
		current_interactions.sort_custom(_sort_by_nearest)
		
		var nearest_interactable := current_interactions[0]
		
		label.text = nearest_interactable.call_to_action
		label.show()

func _sort_by_nearest(area1: Area2D, area2: Area2D) -> bool:
	var area1_dist := global_position.distance_squared_to(area1.global_position)
	var area2_dist := global_position.distance_squared_to(area2.global_position)
	return area1_dist < area2_dist

func _on_area_entered(area: Area2D) -> void:
	if area is Interactable:
		current_interactions.push_back(area as Interactable)

func _on_area_exited(area: Area2D) -> void:
	if area is Interactable:
		current_interactions.erase(area)
