class_name Level
extends Node2D


@warning_ignore("unused_signal")
signal completed
@warning_ignore("unused_signal")
signal failed(reason: String)

@export var pan_speed := 1.0
@export_multiline var instructions: String

var is_panning := false
var drag_start_position: Vector2
var camera_start_position: Vector2

@onready var camera: Camera2D = $Camera2D


func _ready() -> void:
	clear_group(&"resettable")
	for child in Core.get_children_recursive(self, true):
		if child is Resettable:
			child.base.add_to_group(&"resettable")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pan"):
		is_panning = true
		drag_start_position = get_global_mouse_position()
		camera_start_position = camera.position
		get_viewport().set_input_as_handled()
	
	elif event.is_action_released("pan"):
		is_panning = false
		camera.position = camera_start_position
		get_viewport().set_input_as_handled()
	
	elif event is InputEventMouseMotion and is_panning:
		var mouse_offset = (get_global_mouse_position() - drag_start_position) * pan_speed / camera.zoom
		camera.position = camera_start_position - mouse_offset
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
