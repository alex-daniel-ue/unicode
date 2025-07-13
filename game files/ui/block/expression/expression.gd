class_name ExpressionBlock
extends Block


@export var socketed := true

var overridden_socket: ExpressionBlock


func _ready() -> void:
	if socketed:
		draggable = false
	
	# VERY WEIRD BUG! FIXME: with lines 15-17, socketed is by default turned to false,
	# without anything touching it???? what???
	#var block := get_parent().owner
	#if block is Block:
		#infinite = block.infinite
	
	if infinite:
		socketed = false

func _get_drag_data(at_position: Vector2) -> Variant:
	# Can't pick up sockets
	if socketed:
		return null
	
	if overridden_socket != null:
		overridden_socket.visible = true
	
	return super(at_position)

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return bool(
		not self.infinite and
		self.socketed and
		data is ExpressionBlock
	)

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	visible = false
	data.overridden_socket = self
	
	var container := get_parent()
	container.add_child(data)
	container.move_child(data, get_index())
