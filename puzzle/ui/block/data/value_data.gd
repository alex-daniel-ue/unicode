class_name ValueData
extends Resource
## A value slot's data: whether it is typed into or picked from, and what it shows.

## Shows the value's type (int, string, var) on the slot.
@export var show_type := true
## Grey hint shown in an empty slot in place of "...": "list" on a slot that only
## takes a list's name block. Empty keeps the default.
@export var placeholder := ""

@export_group("Editable", "editable_")
@export var editable := true
@export var editable_shown := true

@export_group("Enum", "enum_")
## A dropdown of enum_values instead of a field to type in.
@export var enum_flag := false:
	set = set_enum
## Gives the choice as text rather than as the value it reads as.
@export var enum_as_string := false
@export var enum_values: PackedStringArray

## The SocketData beside this one on the same block, set by BlockData's
## inspector: a dropdown takes no block dropped into it.
@export_storage var _socket_ref: SocketData


func set_enum(to: bool) -> void:
	enum_flag = to
	if Engine.is_editor_hint() and to:
		_socket_ref.receptive = false
