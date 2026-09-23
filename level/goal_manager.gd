@tool
class_name GoalManager
extends Node


@warning_ignore("unused_private_class_variable")
@export_tool_button("Bake camera bounds") var _bake_btn := bake_bounds

@export var bounds: Rect2

@export var focus_markers: Array[Node2D] = []
## Superseded by focus_markers, and ignored when that has anything in it. Kept so
## older scenes still bake; clear it when you next touch a room.
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
	collect_goals()

	var sources: Array[Node] = []
	for marker in focus_markers:
		if marker != null:
			sources.append(marker)
	for goal in goals:
		if goal.camera_focus != null:
			sources.append(goal.camera_focus)
	if focus_markers.is_empty() and focus_marker != null and not (focus_marker in sources):
		sources.append(focus_marker)
	
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
	
	var index := level.room_goals.find(self) if level else -1
	if index >= 0:
		for node in level.find_children("*", "", true, false):
			if node is Resettable and index < node.room_snapshots.size():
				var t: Transform2D = node.room_snapshots[index].get(&"transform", Transform2D())
				rect = rect.merge(Rect2(t.origin - Vector2(16, 16), Vector2(32, 32)))
	
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
