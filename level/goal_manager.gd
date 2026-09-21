@tool
class_name GoalManager
extends Node


@warning_ignore("unused_private_class_variable")
@export_tool_button("Bake camera bounds") var _bake_btn := bake_bounds

@export var bounds: Rect2
@export var focus_marker: Node2D

var goals: Array[Goal]

@onready var level := (get_parent() as RoomGoals).level


func _ready() -> void:
	collect_goals()
	
	if Engine.is_editor_hint():
		return
	
	for goal in goals:
		if not goal.completion_changed.is_connected(_goal_completion_changed):
			goal.completion_changed.connect(_goal_completion_changed)

func _get_configuration_warnings() -> PackedStringArray:
	if not bounds.has_area():
		return ["Camera bounds haven't been baked for this room."]
	return []

func bake_bounds() -> void:
	# Collect fresh rather than trusting _ready — in the editor it won't have run
	# since the last goal was added.
	collect_goals()
	
	var sources: Array[Node] = []
	if focus_marker != null:
		sources.append(focus_marker)
	for goal in goals:
		if goal.camera_focus != null:
			sources.append(goal.camera_focus)
	
	var rect := Rect2()
	var found := false
	
	for source in sources:
		# A Goal is a plain Node with no rect of its own, so what actually gets
		# measured is whatever its camera_focus points at — the same walk the camera
		# uses for whole-level bounds.
		var source_rect := LevelCamera.node_bounds(source)
		if not source_rect.has_area():
			continue
		rect = source_rect if not found else rect.merge(source_rect)
		found = true
	
	var robot := get_tree().get_first_node_in_group(&"robot")
	if robot:
		rect = rect.merge(robot.collision_shape.shape.get_rect())
	
	bounds = rect
	update_configuration_warnings()
	print("(%s) Room bounds baked: " % [name], bounds)

func reset_goals() -> void:
	for goal in goals:
		goal.reset()

func find_failing_goal() -> Goal:
	for goal in goals:
		if not goal.active or goal.must_maintain:
			continue
		if not goal.check_condition():
			return goal
	return null

func collect_goals() -> void:
	goals.clear()
	for node in get_children():
		if node is Goal:
			goals.append(node as Goal)

func _goal_completion_changed(goal: Goal) -> void:
	if goal.must_maintain and not goal.is_complete:
		level.fail(goal.fail_message)
