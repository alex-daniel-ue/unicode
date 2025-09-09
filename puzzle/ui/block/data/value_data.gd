class_name ValueData
extends Resource


@export var show_type := true
@export_group("Editable", "editable_")
@export var editable := true
@export var editable_shown := true
@export_group("Enum", "enum_")
@export var enum_flag := false:
	set = set_enum
@export var enum_as_string := false
@export var enum_values: PackedStringArray

@export_storage var _socket_ref: SocketData


func set_enum(to: bool) -> void:
		enum_flag = to
		if Engine.is_editor_hint() and to:
			_socket_ref.receptive = false
