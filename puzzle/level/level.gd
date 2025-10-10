class_name Level
extends Node2D


@warning_ignore("unused_signal")
signal completed
@warning_ignore("unused_signal")
signal failed(reason: String)

@export var pan_speed := 1.0
@export_multiline var instructions: String

var is_panning := false
var pan_start: Vector2
var visuals_origin: Vector2

@onready var visuals: Node2D = $Visuals


func _ready() -> void:
	clear_group(&"resettable")
	for child in Core.get_children_recursive(self, true):
		if child is Resettable:
			child.base.add_to_group(&"resettable")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pan"):
		is_panning = true
		pan_start = get_global_mouse_position()
		visuals_origin = visuals.global_position
		get_viewport().set_input_as_handled()
	
	elif event.is_action_released("pan"):
		is_panning = false
		get_viewport().set_input_as_handled()
	
	elif event is InputEventMouseMotion and is_panning:
		var mouse_offset = get_global_mouse_position() - pan_start
		visuals.global_position = visuals_origin + mouse_offset
		Debug.log(get_global_mouse_position())
		get_viewport().set_input_as_handled()

func get_blocks() -> Array[Block]:
	var result: Array[Block]
	
	for node in Core.get_children_recursive(self, true):
		if node is BlockProvider:
			var blocks := node.initialize_blocks() as Array[Block]
			result.append_array(blocks)
	
	return result

func reset_state() -> void:
	for node in get_tree().get_nodes_in_group(&"resettable"):
		for child in node.get_children():
			if child is Resettable:
				child.reset()

func clear_group(group: StringName) -> void:
	for node in get_tree().get_nodes_in_group(group):
		node.remove_from_group(group)
