class_name Level
extends Node2D
## A level: one or more rooms, the goals each room has to meet, the blocks the
## level gives, and its brief. Every level scene inherits level.tscn.
##
## The same program runs in every room, one after another (run_rooms()). Each
## room puts every entity back where that room starts it (Resettable), runs the
## program, then checks the room's goals (GoalManager).

signal completed
signal failed(reason: String)
## Emitted for each room as it is solved.
signal room_completed(index: int, total: int)

const ZOOM_SPEED := 0.7
const MIN_ZOOM := 0.5
const MAX_ZOOM := 3.0
## How much of the view, per axis, the level must still fill after a pan or a
## zoom (0.25 = a quarter). Stops the view being dragged off into the void.
const KEEP_VISIBLE := 0.25

@export_multiline var intended_solution: String
@export var room_goals: Array[GoalManager]
@export var star_slack := 1
@export var star_par_override := 0
## Runs the preset program by itself shortly after the level opens, for worked
## examples the student watches instead of building. Play still works after.
@export var auto_run := false
@export var auto_run_delay := 2.5
## Hides what the first levels don't use (the assistant, the Variables tab, the
## speed button), so a newcomer sees only what this level needs. Guides
## introduce each part when a later level first needs it.
@export var minimal_ui := false

@export_group("Exports")
@export var preset: LevelBlockPreset
@export var description: LevelDescription

var has_failed := false
## The room the program is running in, counted from 0. A block that talks to a
## list or a terminal finds the one in this room (RoomEntity.find_named()).
var current_room := 0

var _panning := false
## "Room 2 of 3 — " while a run of several rooms is under way. fail() puts it
## in front, so hazards and the Stop button name the room as goal checks do.
var _room_prefix := ""

@onready var camera: LevelCamera = $Camera2D


func _ready() -> void:
	# A level left from the screen before can still be in the group until it is
	# freed; only this level's entities belong in it.
	for node in get_tree().get_nodes_in_group(&"resettable"):
		node.remove_from_group(&"resettable")
	for keeper in find_children("*", "Resettable", true, false):
		(keeper as Resettable).base.add_to_group(&"resettable")


func _unhandled_input(event: InputEvent) -> void:
	if not camera:
		return

	# Drag with the left or middle button to look around. Nothing else in the
	# level view takes a click, so there is nothing for this to get in the way of.
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MIDDLE]:
			_panning = button.pressed
			Input.set_default_cursor_shape(Input.CURSOR_DRAG if _panning else Input.CURSOR_ARROW)
			get_viewport().set_input_as_handled()
			return

	if event is InputEventMouseMotion and _panning:
		var motion := event as InputEventMouseMotion
		if (motion.button_mask & (MOUSE_BUTTON_MASK_LEFT | MOUSE_BUTTON_MASK_MIDDLE)) == 0:
			# The release happened somewhere this never heard about.
			_panning = false
			Input.set_default_cursor_shape(Input.CURSOR_ARROW)
			return
		camera.global_position -= motion.relative / camera.zoom.x
		_clamp_camera()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton and event.pressed:
		var button_index := (event as InputEventMouseButton).button_index
		var zoom_in := button_index == MOUSE_BUTTON_WHEEL_UP
		var zoom_out := button_index == MOUSE_BUTTON_WHEEL_DOWN
		if zoom_in or zoom_out:
			var factor := ZOOM_SPEED if zoom_in else (1.0 / ZOOM_SPEED)
			var new_zoom := clampf(camera.zoom.x * factor, MIN_ZOOM, MAX_ZOOM)
			if new_zoom != camera.zoom.x:
				# Zoom around the pointer: the point under it stays under it.
				var offset := get_viewport().get_mouse_position() - get_viewport().get_visible_rect().size / 2.0
				var world_before := camera.global_position + offset / camera.zoom.x
				camera.zoom = Vector2(new_zoom, new_zoom)
				var world_after := camera.global_position + offset / camera.zoom.x
				camera.global_position += world_before - world_after
				_clamp_camera()
			get_viewport().set_input_as_handled()


func _exit_tree() -> void:
	if _panning:
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)


## The blocks this level gives the Toolbox, from every BlockProvider in it.
func get_blocks() -> Array[Block]:
	var result: Array[Block]
	for provider in find_children("*", "BlockProvider", true, false):
		result.append_array((provider as BlockProvider).initialize_blocks())
	return result


func get_block_data() -> Array[BlockData]:
	var result: Array[BlockData]
	for provider in find_children("*", "BlockProvider", true, false):
		result.append_array((provider as BlockProvider).get_block_data())
	return result


func fail(reason: String) -> void:
	if has_failed:
		return
	has_failed = true
	if not _room_prefix.is_empty() and not reason.begins_with(_room_prefix):
		reason = _room_prefix + reason
	Interpreter.output_log.append("LEVEL FAILED: " + reason)
	failed.emit(reason)


## Runs the program under `begin` in every room, in order. False at the first
## room that fails, an error, or a Stop.
func run_rooms(begin: CapBlock) -> bool:
	has_failed = false
	_room_prefix = ""
	var room_count := maxi(room_goals.size(), 1)

	# Every room's lists, dictionaries, files and terminals at once, and only
	# here or on Reset: after a run each keeps what the program left in it, so a
	# student can read what went wrong.
	_restore_boards()

	for room_index in range(room_count):
		current_room = room_index
		var prefix := _prefix_for(room_index, room_count)
		_room_prefix = prefix
		if room_count > 1:
			Interpreter.output_log.append(prefix.strip_edges())

		# Fail closed. With room_goals unwired no goal is ever checked, and the
		# level accepts any program, an empty one included; that is also the
		# state of a level freshly inherited from level.tscn.
		var manager: GoalManager = room_goals[room_index] if room_index < room_goals.size() else null
		if manager == null:
			push_error("Level '%s': no GoalManager for room %d. Set Level.room_goals." % [name, room_index])
			fail(prefix + "This level has no goals set up, so it can't be solved.")
			return false

		# Goals first, then entities: resetting a goal emits completion_changed, and
		# moving the robot queues area callbacks that should land against fresh goals.
		manager.reset_goals()
		if not _reset_entities(room_index):
			# A room that can't put its entities back where they start isn't one a
			# student can fairly be asked to solve.
			push_error("Level '%s': room %d is missing a Resettable snapshot." % [name, room_index + 1])
			fail(prefix + "This room isn't set up correctly, so it can't be played.")
			return false

		camera.frame()
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
			fail(prefix + (reason if not reason.is_empty() else "The room wasn't solved correctly."))
			return false

		room_completed.emit(room_index, room_count)

	completed.emit()
	return true


## The block count for three stars: star_par_override when set, otherwise the
## solid blocks in intended_solution.
func get_star_par() -> int:
	if star_par_override > 0:
		return star_par_override
	if not intended_solution.is_empty():
		return maxi(1, Serializer.count_solid_blocks(intended_solution))
	return 1


func calculate_stars(placed_block_count: int) -> int:
	var par := get_star_par()
	if placed_block_count <= par:
		return 3
	elif placed_block_count <= par + star_slack:
		return 2
	return 1


## Every room as it was before any run, for the room's Reset button: the boards
## restored, every goal unmet, and everything resettable at the first room's
## start, where a run puts it before it begins. The program isn't touched.
## False when any entity had no snapshot for the first room.
func reset_rooms() -> bool:
	has_failed = false
	current_room = 0
	_room_prefix = ""
	_restore_boards()
	for manager in room_goals:
		if manager != null:
			manager.reset_goals()
	var ok := _reset_entities(0)
	camera.frame()
	return ok


## Every room's lists, terminals, dictionaries and files back as the level has
## them.
func _restore_boards() -> void:
	for entity in get_tree().get_nodes_in_group(RoomEntity.GROUP):
		(entity as RoomEntity).restore()


## Keeps part of the level on screen (KEEP_VISIBLE), so a pan or a zoom can
## never leave the view looking at nothing. An unbaked level (no level_bounds)
## isn't clamped.
func _clamp_camera() -> void:
	var bounds := camera.level_bounds
	if not bounds.has_area():
		return
	var half := get_viewport().get_visible_rect().size / camera.zoom / 2.0
	var keep := (half * 2.0 * KEEP_VISIBLE).min(bounds.size / 2.0)
	var p := camera.global_position
	p.x = clampf(p.x, bounds.position.x - half.x + keep.x, bounds.end.x + half.x - keep.x)
	p.y = clampf(p.y, bounds.position.y - half.y + keep.y, bounds.end.y + half.y - keep.y)
	camera.global_position = p


## Puts every entity where `room_index` starts it. False when any had no
## snapshot for that room.
func _reset_entities(room_index: int) -> bool:
	var ok := true
	for node in get_tree().get_nodes_in_group(&"resettable"):
		for child in node.get_children():
			if child is Resettable and not (child as Resettable).reset(room_index):
				ok = false
	return ok


func _prefix_for(index: int, total: int) -> String:
	return "Room %d of %d — " % [index + 1, total] if total > 1 else ""
