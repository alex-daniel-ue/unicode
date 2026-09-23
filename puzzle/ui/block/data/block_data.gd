@tool
class_name BlockData
extends Resource


signal text_changed

enum Type {
	STATEMENT,
	NESTED,
	SOCKET, VALUE
}

enum FuncType {
	STANDARD,
	ENTITY,
	LAMBDA
}

const DATA_CLASSES: Dictionary[String, StringName] = {
	nested = &"NestedData",
	socket = &"SocketData",
	value = &"ValueData",
}

const GROUPS := {
	FUNC = "Function/",
	TYPE = "Type/"
}

@export var name := "Block"
@export var color := Color.WHITE
@export_file("*.tscn") var base_path: String

@export_group("Type")
@export var type := Type.STATEMENT:
	set(new_type):
		if type != new_type:
			type = new_type
			notify_property_list_changed()
@export_storage var nested: NestedData
@export_storage var socket: SocketData
@export_storage var value: ValueData

@export_group("Block")
@export var toolbox := true
@export var category := "Uncategorized"
@export var syntax := ""
@export_multiline var description := ""
@export var draggable := true
@export var placeable := true
@export var top_notch := true
@export var trashable := true
@export var copyable := true

@export_group("Text", "text_")
@export var text: String:
	set(value):
		text = value
		text_changed.emit()
@export var text_blocks: Array[BlockData]

var func_script: GDScript
var func_entity_script: GDScript
## Which entity in the level this block talks to, by node name: "RobotCharacter",
## "Lockers", "Shelf". Honour system, and deliberately so -- a name is the one
## handle an author can see in the scene dock without opening anything. Empty
## falls back to the script match, which is only right while a level holds
## exactly one node of that script.
var func_entity_name: StringName
var func_method: StringName
var func_type: FuncType:
	get = get_func_type


#region Editor shenanigans
func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary]
	var exceptions: PackedStringArray
	
	var handle_data_type := func(data_name: String) -> void:
		if get(data_name) == null:
			set(data_name, _create_data_from_str(DATA_CLASSES[data_name]))
		properties.append(_form_data_property(data_name))
		exceptions.append(data_name)
	
	match type:
		Type.NESTED:
			handle_data_type.call("nested")
		Type.SOCKET:
			handle_data_type.call("socket")
		Type.VALUE:
			handle_data_type.call("value")
			handle_data_type.call("socket")
			if value and socket:
				value._socket_ref = socket
	
	for data_name in DATA_CLASSES.keys():
		if not data_name in exceptions:
			set(data_name, null)
	
	properties.append({
		"name": GROUPS.FUNC + "script",
		"type": TYPE_OBJECT,
		"usage": (PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_NEVER_DUPLICATE),
		"hint": PROPERTY_HINT_RESOURCE_TYPE,
		"hint_string": &"GDScript",
	})
	
	properties.append({
		"name": GROUPS.FUNC + "entity_script",
		"type": TYPE_OBJECT,
		"usage": (PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_NEVER_DUPLICATE),
		"hint": PROPERTY_HINT_RESOURCE_TYPE,
		"hint_string": &"GDScript",
	})
	
	properties.append({
		"name": GROUPS.FUNC + "entity_name",
		"type": TYPE_STRING_NAME,
		"usage": PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_EDITOR,
	})
	
	var script_for_methods := func_script
	if script_for_methods == null:
		script_for_methods = func_entity_script 
	
	properties.append({
		"name": GROUPS.FUNC + "method",
		"type": TYPE_STRING,
		"usage": PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_EDITOR,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": ','.join(_get_method_names(script_for_methods))
	})
	
	return properties

func _get(property: StringName) -> Variant:
	if property == GROUPS.FUNC + "script":
		return func_script
	if property == GROUPS.FUNC + "method":
		return func_method
	if property == GROUPS.FUNC + "entity_script":
		return func_entity_script
	if property == GROUPS.FUNC + "entity_name":
		return func_entity_name
	
	if property.begins_with(GROUPS.TYPE):
		return get(property.trim_prefix(GROUPS.TYPE))
	
	return null

func _set(property: StringName, val: Variant) -> bool:
	if property == GROUPS.FUNC + "script":
		func_script = val
		notify_property_list_changed()
		return true
	if property == GROUPS.FUNC + "method":
		func_method = val
		notify_property_list_changed()
		return true
	if property == GROUPS.FUNC + "entity_script":
		func_entity_script = val
		notify_property_list_changed()
		return true
	if property == GROUPS.FUNC + "entity_name":
		func_entity_name = val
		return true
	
	if property.begins_with(GROUPS.TYPE):
		set(property.trim_prefix(GROUPS.TYPE), val)
		notify_property_list_changed()
		return true
	
	return false

func _form_data_property(p_name: StringName) -> Dictionary:
	assert(p_name in DATA_CLASSES, "Data class name not found.")
	return {
		"name": GROUPS.TYPE + str(p_name),
		"type": TYPE_OBJECT,
		"hint": PROPERTY_HINT_RESOURCE_TYPE,
		"hint_string": DATA_CLASSES[p_name]
	}

func _create_data_from_str(_class_name: StringName) -> Resource:
	for class_data in ProjectSettings.get_global_class_list():
		if class_data.class == _class_name:
			var script := load(class_data.path) as Script
			if script:
				return script.new()
	return null

func _get_method_names(script: Script) -> PackedStringArray:
	if script == null:
		return []
	
	# Get all script methods, including inherited, excluding those named "__*"
	var script_methods := script.get_script_method_list().map(
		func(method: Dictionary) -> String:
			return method.name
	).filter(
		func(method_name: String) -> bool:
			return not method_name.begins_with("__")
	)
	
	# Get only inherited methods
	var base_methods := ClassDB.class_get_method_list(script.get_instance_base_type()).map(
		func(method: Dictionary) -> String:
			return method.name
	)
	
	# Exclude inherited methods from script methods
	var custom_methods: PackedStringArray
	for method in script_methods:
		if not method in base_methods:
			custom_methods.append(method)
	
	return custom_methods
#endregion


func get_func_type() -> FuncType:
	if not func_method.is_empty():
		if func_script != null:
			return FuncType.STANDARD
		return FuncType.ENTITY
	return FuncType.LAMBDA

func has_text_blocks() -> bool:
	return text.contains("{}")

## A duplicate that actually copies the nested parameter blocks.
##
## Resource.duplicate(true) does not copy a sub-resource that came from a file.
## Verified in 4.5.1 against if.tres: `nested` comes back as a new object,
## because it is an inline SubResource, but every entry in `text_blocks` is
## still the very same on-disk BlockData as the original. Writing a flag onto
## one of those entries edits the shared .tres for the rest of the session, and
## even a fresh load() then returns the mutated copy.
##
## Using this in Block.construct() as well as in BlockDragComponent.copy() is
## what makes the whole class of bug unreachable, because after that no live
## Block holds a reference to a file-backed BlockData at all.
func deep_copy() -> BlockData:
	var copy: BlockData = duplicate(true)

	var copied: Array[BlockData] = []
	for child: BlockData in text_blocks:
		if child != null:
			copied.append(child.deep_copy())
	copy.text_blocks = copied

	return copy
