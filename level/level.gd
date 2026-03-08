class_name Level
extends Node2D


@warning_ignore("unused_signal")
signal completed
@warning_ignore("unused_signal")
signal failed(reason: String)

@export_multiline var instructions: String
@export_multiline var intended_solution: String

var zoom_speed := 1.15
var min_zoom := 0.5
var max_zoom := 3.0

@onready var camera: LevelCamera = $Camera2D


func _ready() -> void:
	clear_group(&"resettable")
	for child in Core.get_children_recursive(self, true):
		if child is Resettable:
			child.base.add_to_group(&"resettable")

func _unhandled_input(event: InputEvent) -> void:
	if not camera:
		return
	
	if event is InputEventMouseButton and event.pressed:
		var button_index := (event as InputEventMouseButton).button_index
		
		var zoom_in := button_index == MOUSE_BUTTON_WHEEL_UP
		var zoom_out := button_index == MOUSE_BUTTON_WHEEL_DOWN
		
		if zoom_in or zoom_out:
			var factor := zoom_speed if zoom_in else (1.0 / zoom_speed)
			var new_zoom_val := clampf(camera.zoom.x * factor, min_zoom, max_zoom)
			
			if new_zoom_val != camera.zoom.x:
				var screen_mouse_pos := get_viewport().get_mouse_position()
				var center_pos := get_viewport().get_visible_rect().size / 2.0
				var offset := screen_mouse_pos - center_pos
				
				var world_before := camera.global_position + offset / camera.zoom.x
				camera.zoom = Vector2(new_zoom_val, new_zoom_val)
				var world_after := camera.global_position + offset / camera.zoom.x
				
				camera.global_position += world_before - world_after
			
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
