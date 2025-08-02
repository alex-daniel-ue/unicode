@tool
class_name SocketBlock
extends Block


var overridden_socket: SocketBlock


func _ready() -> void:
	assert(data is SocketBlockData)
	#var data := data as SocketBlockData
	
	if Engine.is_editor_hint():
		return
	
	super()
	if data.toolbox:
		data.receptive = false

func _get_drag_data(at_position: Vector2) -> Variant:
	if overridden_socket != null:
		overridden_socket.visible = true
	
	return super(at_position)

func _can_drop_data(_at_position: Vector2, drop: Variant) -> bool:
	#var data := data as SocketBlockData
	return (
		not data.toolbox and
		data.receptive and
		drop is SocketBlock
	)

func _drop_data(_at_position: Vector2, drop: Variant) -> void:
	# From the perspective of the socketed SocketBlock
	visible = false
	drop.overridden_socket = self
	
	var container := get_parent()
	container.add_child(drop)
	container.move_child(drop, get_index())

func get_text() -> String:
	return super() if visible else ""
