extends ColorRect


var _current_drag_data: Variant
var _current_preview: Control
var _current_preview_container: Control
var _current_preview_idx: int

var _this_container: Control
var _this_idx: int


func _process(_delta: float) -> void:
	if get_viewport().gui_is_dragging():
		_this_container = _get_preview_container()
		
		if _this_container != null:
			_this_idx = _get_preview_idx(_this_container)
			
			if _this_container != _current_preview_container:
				if _current_preview_container != null:
					_current_preview_container.remove_child(_current_preview)
				
				_this_container.insert_child(_this_idx, _current_preview)
				
				_current_preview_container = _this_container
				_current_preview_idx = _this_idx
			
			elif _this_idx != _current_preview_idx:
				_current_preview_container.move_child(_current_preview, _this_idx)
				_current_preview_idx = _this_idx
		
		elif _current_preview_container != null:
			print("Hovering over nothing, remove recent preview from %s" % _current_preview_container)
			_current_preview_container.remove_child(_current_preview)
			_current_preview_container = null

func _get_preview_container() -> Node:
	var control := get_viewport().gui_get_hovered_control()
	if control == null:
		return null
	
	var block := control.owner
	if not block is Block:
		return null
	
	var container := block.get_parent()
	var parent_block := container.owner
	
	if parent_block is NestedBlock:
		if block is Statement:
			return container
		if parent_block is NestedBlock:
			var center_y := control.global_position.y + control.size.y * 0.5
			var is_above := get_global_mouse_position().y < center_y
			
			if control.name == ("UpperLip" if is_above else "LowerLip"):
				return parent_block._mouth
	
	if block is NestedBlock and block._can_drop_data(Vector2.ZERO, Block.new()):
		if block._is_preview:
			return _current_preview_container
		return block._mouth
	
	return null

func _get_preview_idx(container: Control) -> int:
	var mouse_y := get_global_mouse_position().y
	var top := container.global_position.y
	var height := container.size.y
	var bottom := top + height
	
	if mouse_y > top and mouse_y < bottom:
		var child_bottom_ex := top
		for idx in range(container.get_child_count()):
			var child: Control = container.get_child(idx)
			if child._is_preview:
				continue
			
			child_bottom_ex += child.size.y
			var child_top := child.global_position.y
			var child_bottom := child_top + child.size.y
			
			if mouse_y < child_bottom_ex:
				var child_center_y: float = child_bottom_ex - child.size.y * 0.5
				prints(mouse_y, child_center_y, idx, mouse_y > child_center_y)
				return idx + (1 if mouse_y > child_center_y else 0)
	
	if mouse_y < top + height * 0.5:
		return 0
	return -1

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_DRAG_BEGIN:
			_current_drag_data = get_viewport().gui_get_drag_data()
			_current_preview = _current_drag_data.clone()
			_current_preview._is_preview = true
			_current_preview.modulate.a = 0.4
		NOTIFICATION_DRAG_END:
			_current_preview.queue_free()
			_current_preview = null
			_current_preview_container = null
			
			# On drag & drop failure
			if not get_viewport().gui_is_drag_successful() and _current_drag_data is Block:
				# If block came from block drawer
				if _current_drag_data._original_parent == null:
					_current_drag_data.queue_free()
				else:
					# Return block to where it was
					_current_drag_data._original_parent.add_child(_current_drag_data)
					_current_drag_data._original_parent.move_child(_current_drag_data, _current_drag_data._original_idx)

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Block

func _drop_data(at_position: Vector2, data: Variant) -> void:
	data.position = at_position + data._get_center_drag_pos()
	add_child(data)
