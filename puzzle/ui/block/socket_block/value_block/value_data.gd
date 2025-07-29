class_name ValueBlockData
extends SocketBlockData


signal enum_flag_changed(to: bool)

@export_group("Value")
@export var is_enum := false:
	set(value):
		is_enum = value
		enum_flag_changed.emit()
@export var enum_values: PackedStringArray
