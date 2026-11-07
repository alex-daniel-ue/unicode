@tool
class_name Resettable
extends Node
## Puts its parent (`base`) back where each room starts it: one snapshot of
## `tracked_properties` per room, saved in the editor with the tool button.
## The robot moves between rooms this way.

@warning_ignore("unused_private_class_variable")
@export_tool_button("Save snapshot for room above") var _save_button := save_snapshot
@export var base: Node
@export var editing_room := 0
@export var tracked_properties: PackedStringArray
@export var room_snapshots: Array[Dictionary]


## Arrays and dictionaries are shared by reference. Stored or restored as-is, a
## list written during one run would be written into the snapshot itself, and
## every retry would start from the previous run's contents.
static func _detached(value: Variant) -> Variant:
	if value is Array or value is Dictionary:
		return value.duplicate(true)
	return value


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
			snap[prop] = _detached(base.get(prop))
		else:
			push_warning("Base has no property '%s', cannot save." % prop)

	room_snapshots[editing_room] = snap
	notify_property_list_changed()
	if Engine.is_editor_hint():
		print("(%s) Snapshot for room %d saved." % [base.name, editing_room])


## Puts base back as room `room_index` starts it. False when there is no
## snapshot for that room: left where the room before ended, the entity would
## make the room silently unsolvable or silently solved, so the caller fails it.
func reset(room_index: int) -> bool:
	if room_index >= room_snapshots.size():
		push_error("(%s) No snapshot saved for room %d." % [str(base.name) if base != null else "?", room_index])
		return false

	var snap: Dictionary = room_snapshots[room_index]
	for prop in snap:
		if prop in base:
			base.set(prop, _detached(snap[prop]))
		elif not Engine.is_editor_hint():
			push_warning("Base has no property '%s', cannot reset." % prop)
	return true
