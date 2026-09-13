@tool
class_name Resettable
extends Node


@export_tool_button("Save snapshot for room above") var _save_btn := save_snapshot

@export var base: Node
@export var editing_room := 0
@export var tracked_properties: PackedStringArray
@export var room_snapshots: Array[Dictionary]


func _ready() -> void:
	if Engine.is_editor_hint():
		base = get_parent()

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray
	for prop in tracked_properties:
		if not prop in base:
			warnings.append("Base has no property named '%s'." % prop)
	return warnings

func save_snapshot() -> void:
	while room_snapshots.size() <= editing_room:
		room_snapshots.append({})
	
	var snap: Dictionary[StringName, Variant] = {}
	for prop in tracked_properties:
		if prop in base:
			snap[prop] = base.get(prop)
		else:
			push_warning("Base has no property '%s', cannot save." % prop)
	
	room_snapshots[editing_room] = snap
	notify_property_list_changed()
	if Engine.is_editor_hint():
		print("(%s) Snapshot for room %d saved." % [base.name, editing_room])

func reset(room_index: int) -> void:
	if room_index >= room_snapshots.size():
		push_warning("(%s) No snapshot saved for room %d." % [base.name, room_index])
		return
	
	var snap: Dictionary = room_snapshots[room_index]
	for prop in snap:
		if prop in base:
			base.set(prop, snap[prop])
		elif not Engine.is_editor_hint():
			push_warning("Base has no property '%s', cannot reset." % prop)
