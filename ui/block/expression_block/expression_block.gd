@tool
class_name ExpressionBlock
extends Block


@export var socketed := true

var overridden_socket: ExpressionBlock


func _ready() -> void:
	if toolbox:
		socketed = false
	if socketed:
		draggable = false

func _get_drag_data(at_position: Vector2) -> Variant:
	if socketed:
		return null
	
	if overridden_socket != null:
		overridden_socket.visible = true
	
	return super(at_position)

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return (
		not self.toolbox and
		self.socketed and
		data is ExpressionBlock
	)

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	# From the perspective of the socketed ExpressionBlock
	visible = false
	data.overridden_socket = self
	
	var container := get_parent()
	container.add_child(data)
	container.move_child(data, get_index())
