@tool
class_name SocketBlock
extends Block


var overridden_socket: SocketBlock


func _ready() -> void:
	assert(data is SocketBlockData)
	if Engine.is_editor_hint():
		return
	
	match preview_type:
		PreviewType.DROP: return
		PreviewType.DRAG:
			super()
			return
	
	if Utils.is_func_type(Utils.FunctionType.LAMBDA, data):
		function = func() -> Utils.Result:
			return Utils.Result.success(Utils.typecast_string(get_raw_text()))
	
	super()

func _get_drag_data(at_position: Vector2) -> Variant:
	if overridden_socket != null:
		overridden_socket.visible = true
	
	return super(at_position)

func _can_drop_data(_at_position: Vector2, drop: Variant) -> bool:
	var solid := get_solid_parent_block()
	Debug.log([not data.toolbox, data.receptive, drop is SocketBlock, (solid == null or not solid.data.toolbox)])
	return (
		not data.toolbox and
		data.receptive and
		drop is SocketBlock and
		# if in a Block, Block must not be toolbox
		(solid == null or not solid.data.toolbox)
	)

func _drop_data(_at_position: Vector2, drop: Variant) -> void:
	# From the perspective of the socketed SocketBlock
	visible = false
	drop.overridden_socket = self
	
	var container := get_parent()
	container.add_child(drop)
	container.move_child(drop, get_index())

func get_solid_parent_block() -> Block:
	var result := get_parent_block()
	while result != null and not result.data.top_notch:
		result = result.get_parent_block()
	return result
