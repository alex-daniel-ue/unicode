@tool
class_name Resettable
extends Node


@warning_ignore("unused_private_class_variable")
@export_tool_button("Save initial state") var _save_initial_btn := save_initial

@export var base: Node
@export var initial_properties: Dictionary[StringName, Variant]:
	set(value):
		initial_properties = value
		if Engine.is_editor_hint():
			update_configuration_warnings()


func _ready() -> void:
	base = get_parent()
	save_initial()

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray

	for prop in initial_properties:
		if not prop in base:
			warnings.append("Base has no property named '%s'." % prop)
			continue
		
		var base_type := Core.get_type_string(base.get(prop))
		var val_type := Core.get_type_string(initial_properties[prop])
		if base_type != val_type:
			warnings.append("Property '%s' type mismatch, must be %s (%s)." % [prop, base_type, val_type])
	
	return warnings


func save_initial() -> void:
	for prop in initial_properties:
		if prop in base:
			initial_properties[prop] = base.get(prop)
		else:
			push_warning("Base has no property '%s', Cannot save." % prop)
	
	notify_property_list_changed()
	if Engine.is_editor_hint():
		print("(%s) Initial state saved." % base.name)

func reset() -> void:
	for prop in initial_properties:
		if prop in base:
			base.set(prop, initial_properties[prop])
		elif not Engine.is_editor_hint():
			push_warning("Base has no property '%s', cannot reset." % prop)
