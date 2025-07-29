class_name SocketBlockData
extends BlockData


signal receptivity_changed(to: bool)

@export_group("Socket")
@export var receptive := true:
	set(value):
		receptive = value
		receptivity_changed.emit(value)
