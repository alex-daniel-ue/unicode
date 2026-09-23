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

@export var star_slack := 1
@export var star_par_override := 0

## A tutorial overlay to lay over the whole puzzle while this level is open.
## Puzzle instances it; it can't live in the level itself, which renders in a
## SubViewport and would be clipped to the environment panel.
@export var tutorial_overlay: PackedScene

@export_group("Exports")
@export var rooms: Node
@export var preset: LevelBlockPreset
@export var description: LevelDescription

var zoom_speed := 1.15
var min_zoom := 0.5
var max_zoom := 3.0

var has_failed := false
## "Room 2 of 3 — " while a multi-room run is in progress. fail() prefixes it,
## so hazards and the Stop button name the room the same way goal checks do.
var _room_label := ""

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
	if not _room_label.is_empty() and not reason.begins_with(_room_label):
		reason = _room_label + reason
	Interpreter.output_log.append("LEVEL FAILED: " + reason)
	failed.emit(reason)

func run_rooms(begin: CapBlock) -> bool:
	has_failed = false
	_room_label = ""
	var room_count := maxi(room_goals.size(), 1)
	
	for room_index in range(room_count):
		var label := room_label(room_index, room_count)
		_room_label = label
		if room_count > 1:
			Interpreter.output_log.append(label.strip_edges())
		
		# Fail closed. With room_goals unwired, manager stays null, no goal is ever
		# checked and the level accepts any program including an empty one — which
		# is also the default state of a level freshly inherited from level.tscn.
		var manager: GoalManager = room_goals[room_index] if room_index < room_goals.size() else null
		if manager == null:
			push_error("Level '%s': no GoalManager for room %d. Set Level.room_goals." % [name, room_index])
			fail(label + "This level has no goals set up, so it can't be solved.")
			return false
		
		# Goals first, then entities: resetting a goal emits completion_changed, and
		# moving the robot queues area callbacks that should land against fresh goals.
		manager.reset_goals()
		if not reset_state(room_index):
			# Same reasoning as the room_goals guard above. A room that cannot
			# put its entities back where they belong is not a room a student
			# can fairly be asked to solve.
			push_error("Level '%s': room %d is missing a Resettable snapshot." % [name, room_index + 1])
			fail(label + "This room isn't set up correctly, so it can't be played.")
			return false
		camera.frame_rect(manager.bounds)
		
		await begin.function.run()
		
		if Interpreter.interrupted:
			return false
		
		# overlaps_body() reflects the last physics step, not the instant a move
		# finished. One frame is not always enough to cover the step the final move
		# landed in.
		await get_tree().physics_frame
		await get_tree().physics_frame
		
		var failing_goal := manager.find_failing_goal()
		if failing_goal:
			var reason := failing_goal.fail_message
			fail(label + (reason if not reason.is_empty() else "The room wasn't solved correctly."))
			return false
		
		room_completed.emit(room_index, room_count)
	
	completed.emit()
	return true

func get_star_par() -> int:
	if star_par_override > 0:
		return star_par_override
	if not intended_solution.is_empty():
		var total_solid := Serializer.count_solid_blocks(intended_solution, true)
		return maxi(1, total_solid)
	return 1

func calculate_stars(placed_block_count: int) -> int:
	var par := get_star_par()
	if placed_block_count <= par:
		return 3
	elif placed_block_count <= par + star_slack:
		return 2
	return 1

## False when any entity had no snapshot for this room.
func reset_state(room_index := 0) -> bool:
	var ok := true
	for node in get_tree().get_nodes_in_group(&"resettable"):
		for child in node.get_children():
			if child is Resettable:
				if not (child as Resettable).reset(room_index):
					ok = false
	return ok

func clear_group(group: StringName) -> void:
	for node in get_tree().get_nodes_in_group(group):
		node.remove_from_group(group)

func room_label(index: int, total: int) -> String:
	return "Room %d of %d — " % [index + 1, total] if total > 1 else ""
