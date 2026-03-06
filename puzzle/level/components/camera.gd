@tool
class_name LevelCamera
extends Camera2D


@warning_ignore("unused_private_class_variable")
@export_tool_button("Update bounds") var _update_bounds := update_bounds

@export var padding := Vector2(32, 32)
@export var level_bounds: Rect2


func _ready() -> void:
	if Engine.is_editor_hint():
		update_bounds()
	else:
		frame()
		get_viewport().size_changed.connect(frame)

func update_bounds() -> void:
	var bounds := Rect2()
	var first := true
	
	var root := owner if owner else get_parent()
	var nodes_to_check: Array[Node] = [root]
	
	while not nodes_to_check.is_empty():
		var current = nodes_to_check.pop_back()
		nodes_to_check.append_array(current.get_children())
		
		var rect := Rect2()
		var valid := false
		
		if current is TileMapLayer:
			var map := current as TileMapLayer
			if map.tile_set:
				var used := map.get_used_rect()
				var t_size := map.tile_set.tile_size
				
				rect = Rect2(Vector2(used.position) * Vector2(t_size), Vector2(used.size) * Vector2(t_size))
				rect = map.get_global_transform() * rect
				valid = true
		
		elif current is Sprite2D:
			rect = current.get_global_transform() * current.get_rect()
			valid = true
		
		if valid:
			if first:
				bounds = rect
				first = false
			else:
				bounds = bounds.merge(rect)
	
	level_bounds = bounds
	notify_property_list_changed()
	print("(%s) Level bounds calculated: " % [root.name], level_bounds)

func frame(pad := padding) -> void:
	if level_bounds.size.is_zero_approx():
		return
	
	var vp_size := get_viewport_rect().size
	var target_size := level_bounds.size + (pad * 2.0)
	
	global_position = level_bounds.get_center()
	
	var zoom_factor := minf(vp_size.x / target_size.x, vp_size.y / target_size.y)
	zoom = Vector2(zoom_factor, zoom_factor)
