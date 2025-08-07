class_name ValueBlockData
extends SocketBlockData


@warning_ignore("unused_signal")
signal editable_changed(to: bool)
signal enum_flag_changed(to: bool)

@export_group("Value")
@export var editable := true
@export var is_enum := false:
	set(value):
		is_enum = value
		if is_enum:
			receptive = false
		enum_flag_changed.emit()
@export var enum_values: PackedStringArray
