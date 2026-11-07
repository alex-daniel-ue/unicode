@tool
class_name BlockData
extends Resource
## What a block is, as data: one .tres per block in puzzle/blocks/ (and the
## robot's in its blocks/ folder). Block.construct() builds a block from it.
##
## Its function (what it does when it runs) is set in the inspector's Function
## group: a script and a method on it (STANDARD), a method on an entity in the
## level (ENTITY), or neither (LAMBDA). The Type group holds the extra data its
## type needs (NestedData, SocketData, ValueData).

signal text_changed

## Stored as an integer in every .tres, so only ever append.
enum Type {
	STATEMENT,  ## Does something: Step Forward, Set.
	NESTED,  ## Has a mouth for blocks: While, If.
	SOCKET,  ## Gives True or False, in a slot: Ahead Is, Not.
	VALUE,  ## Gives a value, in a slot: a number, Index Of.
}

enum FuncType {
	STANDARD,
	ENTITY,
	LAMBDA,
}

const DATA_CLASSES: Dictionary[String, StringName] = {
	nested = &"NestedData",
	socket = &"SocketData",
	value = &"ValueData",
}

## Inspector groups for the properties made in _get_property_list().
const GROUPS := {
	FUNC = "Function/",
	TYPE = "Type/",
}

## An internal id, unique per block: "ItemOfBlock". The serializer and the
## assistant's block doc go by it.
@export var name := "Block"
## What students call the block: "Ahead Is", "Index Of", "Begin". Guide pages and
## messages use it; empty falls back to the block's text (display_name()).
@export var title := ""
@export var color := Color.WHITE
## The block scene this data is drawn with (statement, nested, cap, expression,
## value).
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
## The block's short tutorial text, for students: what it does, in a sentence
## or two of plain English ("This block adds 1 to a variable."). The toolbox's
## eye shows it, and a guide page uses it when the level gives no note of its
## own. `description` is the precise version, for the assistant.
@export_multiline var note := ""
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
## One per slot, in order: a word shown greyed in the slot while it's empty, for
## what goes there ("var", "index", "value"). It names the slot instead of the
## block text doing it ("for {}" with "var" rather than "for var {}"). Empty
## leaves that slot's own placeholder.
@export var text_hints: PackedStringArray = []

var func_script: GDScript
var func_entity_script: GDScript
## Which entity in the level this block talks to, by node name: "RobotCharacter",
## "Lockers", "Shelf". A name is the one handle an author can see in the scene
## dock without opening anything. Empty falls back to the script match, which is
## only right while a level holds exactly one node of that script.
var func_entity_name: StringName
var func_method: StringName
var func_type: FuncType:
	get = get_func_type


#region Inspector
## The Type and Function groups: the type's own data, made when the type is
## picked, and the function's script, entity and method, with the method picked
## from the script's own methods.
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
		"hint_string": ",".join(_get_method_names(script_for_methods)),
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
#endregion


func get_func_type() -> FuncType:
	if not func_method.is_empty():
		if func_script != null:
			return FuncType.STANDARD
		return FuncType.ENTITY
	return FuncType.LAMBDA


func has_text_blocks() -> bool:
	return text.contains("{}")


## What to call this block: its title, or else its text on one line, with "..." for
## each slot ("ahead is ...", "step forward ... times", "begin code"). A block
## that starts with a slot ("{} in {}", "{} {} {}") would be all dots that way,
## so its slots are named instead, as the block shows them: "value in list",
## "number + number".
func display_name() -> String:
	if not title.is_empty():
		return title
	var line := text.replace("\\n", " ").strip_edges()
	var parts := line.split("{}")
	var shown := parts[0]
	for i in range(1, parts.size()):
		shown += (_slot_word(i - 1) if line.begins_with("{}") else "...") + parts[i]
	shown = shown.strip_edges()
	return shown if not shown.is_empty() else name


## A duplicate that also copies the slot blocks' data.
##
## Resource.duplicate(true) doesn't copy a sub-resource that came from a file:
## `nested` comes back as a new object, being an inline SubResource, but every
## entry in `text_blocks` is the same on-disk BlockData as the original's.
## Writing a flag onto one of those edits the shared .tres for the rest of the
## session, and even a fresh load() returns the changed copy. Block.construct()
## and BlockDragComponent.copy() both use this, so no live Block holds a
## file-backed BlockData.
func deep_copy() -> BlockData:
	var copy: BlockData = duplicate(true)
	var copied: Array[BlockData] = []
	for child: BlockData in text_blocks:
		if child != null:
			copied.append(child.deep_copy())
	copy.text_blocks = copied
	return copy


## The word a slot shows while it's empty: its hint, its placeholder, or its
## first choice.
func _slot_word(index: int) -> String:
	if index < text_hints.size() and not text_hints[index].is_empty():
		return text_hints[index]
	var slot: BlockData = text_blocks[index] if index < text_blocks.size() else null
	if slot != null and slot.value != null:
		if not slot.value.placeholder.is_empty():
			return slot.value.placeholder
		if not slot.value.enum_values.is_empty():
			return slot.value.enum_values[0]
	if slot != null and (slot.name.begins_with("List") or slot.text == "list"):
		return "list"
	return "..."


func _form_data_property(p_name: StringName) -> Dictionary:
	assert(p_name in DATA_CLASSES, "Data class name not found.")
	return {
		"name": GROUPS.TYPE + str(p_name),
		"type": TYPE_OBJECT,
		"hint": PROPERTY_HINT_RESOURCE_TYPE,
		"hint_string": DATA_CLASSES[p_name],
	}


func _create_data_from_str(data_class: StringName) -> Resource:
	for class_data in ProjectSettings.get_global_class_list():
		if class_data.class == data_class:
			var script := load(class_data.path) as Script
			if script:
				return script.new()
	return null


## The methods `script` declares itself, for the inspector's method list. Those
## starting with "__" are a function script's helpers, not a block's function.
func _get_method_names(script: Script) -> PackedStringArray:
	if script == null:
		return []
	var script_methods := script.get_script_method_list().map(
		func(method: Dictionary) -> String: return method.name
	).filter(
		func(method_name: String) -> bool: return not method_name.begins_with("__")
	)
	var base_methods := ClassDB.class_get_method_list(script.get_instance_base_type()).map(
		func(method: Dictionary) -> String: return method.name
	)
	var custom_methods: PackedStringArray
	for method in script_methods:
		if not method in base_methods:
			custom_methods.append(method)
	return custom_methods
