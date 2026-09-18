class_name Level
extends Node2D


@warning_ignore("unused_signal")
signal completed  ## This is for this Level's completion
@warning_ignore("unused_signal")
signal failed(reason: String)
@warning_ignore("unused_signal")
signal room_completed(index: int, total: int)  ## Emitted for every Room/GoalManager

@export_multiline var intended_solution: String
@export var room_goals: Array[GoalManager]

@export_group("Exports")
@export var rooms: Node
@export var preset: LevelBlockPreset
@export var description: LevelDescription

var zoom_speed := 1.15
var min_zoom := 0.5
var max_zoom := 3.0

var has_failed := false

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

func get_block_data() -> Array[BlockData]:
	var result: Array[BlockData]
	for node in Core.get_children_recursive(self, true):
		if node is BlockProvider:
			result.append_array((node as BlockProvider).block_data)
	return result

func fail(reason: String) -> void:
	if has_failed: return
	has_failed = true
	Interpreter.output_log.append("LEVEL FAILED: " + reason)
	failed.emit(reason)

func run_rooms(begin: CapBlock) -> bool:
	has_failed = false
	var room_count := maxi(room_goals.size(), 1)
	
	for room_index in range(room_count):
		var label := room_label(room_index, room_count)
		if room_count > 1:
			Interpreter.output_log.append(label.strip_edges())
		reset_state(room_index)
		
		var manager: GoalManager = null # Each manager serves as a "Room"
		if room_index < room_goals.size():
			manager = room_goals[room_index]
			manager.reset_goals()
			camera.frame_rect(manager.bounds)
		
		await begin.function.run()
		
		if Interpreter.interrupted:
			#fail(room_label(room_index, room_count) + "The program didn't finish.")
			return false
		
		# Let the physics engine catch up before asking Area2Ds what's overlapping
		# overlaps_body() reflects the last physics step, not the instant a move
		# finished
		await get_tree().physics_frame
		
		if manager:
			var failing_goal := manager.find_failing_goal()
			if failing_goal:
				var reason := failing_goal.fail_message
				fail(room_label(room_index, room_count) + (
					reason if not reason.is_empty() else "The room wasn't solved correctly."
				))
				return false
		
		room_completed.emit(room_index, room_count)
	
	completed.emit()
	return true

func reset_state(room_index := 0) -> void:
	for node in get_tree().get_nodes_in_group(&"resettable"):
		for child in node.get_children():
			if child is Resettable:
				child.reset(room_index)

func clear_group(group: StringName) -> void:
	for node in get_tree().get_nodes_in_group(group):
		node.remove_from_group(group)

func room_label(index: int, total: int) -> String:
	return "Room %d of %d — " % [index + 1, total] if total > 1 else ""
