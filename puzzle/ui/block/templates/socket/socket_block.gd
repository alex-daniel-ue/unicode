class_name SocketBlock
extends Block


var overridden_socket: SocketBlock


func _ready() -> void:
	if function.evaluate_type() == function.Type.LAMBDA:
		function.set_func(socket_function)
	
	super()

func _get_drag_data(at_position: Vector2) -> Variant:
	if overridden_socket != null:
		overridden_socket.visible = true
	
	return super(at_position)

func _can_drop_data(_at_position: Vector2, drop: Variant) -> bool:
	var solid := get_solid_parent_block()
	return (
		not data.toolbox and
		data.socket.receptive and
		drop is SocketBlock and
		# if in a Block, Block must not be toolbox
		(solid == null or not solid.data.toolbox)
	)

func _drop_data(_at_position: Vector2, drop: Variant) -> void:
	# From the perspective of the socketed SocketBlock
	visible = false
	
	# Deffered, So that SocketDropManager knows whether it's being taken out
	drop.set_deferred(&"overridden_socket", self)
	drop.orphan()
	
	var container := get_parent()
	container.add_child(drop)
	container.move_child(drop, get_index())

func get_solid_parent_block() -> Block:
	var result := get_parent_block()
	while result != null and not result.data.top_notch:
		result = result.get_parent_block()
	return result

func typecast(string: String) -> Variant:
	## Order of typecasting:
	## Empty string, boolean, integer, float, string, identifier, invalid
	
	if string.is_empty(): return null
	if string in ["true", "false"]: return str_to_var(string)
	if string.is_valid_int(): return string.to_int()
	if string.is_valid_float(): return string.to_float()
	
	const quotes := ['"', "'"]
	var last := len(string)-1
	if string[last] in quotes and string[0] in quotes and last >= 1:
		return string.substr(1, last-1)
	
	if string.is_valid_ascii_identifier(): return StringName(string)
	
	return null

func socket_function() -> Variant:
	return typecast(text.get_raw())
