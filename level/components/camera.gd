@tool
class_name LevelCamera
extends Camera2D


@warning_ignore("unused_private_class_variable")
@export_tool_button("Update bounds") var _update_bounds := update_bounds
@warning_ignore("unused_private_class_variable")
@export_tool_button("Frame") var __001 := frame

@export var level_bounds: Rect2

var padding := Vector2(8, 8)
var room_padding := Vector2(48, 48)


static func node_bounds(root: Node) -> Rect2:
	var bounds := Rect2()
	var found := false
	var nodes_to_check: Array[Node] = [root]
	
	while not nodes_to_check.is_empty():
		var current: Node = nodes_to_check.pop_back()
		if current is CanvasItem and not (current as CanvasItem).visible:
			continue
		
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
			var sprite := current as Sprite2D
			rect = sprite.get_global_transform() * sprite.get_rect()
			valid = true
		
		elif current is CollisionShape2D:
			var col := current as CollisionShape2D
			if col.shape != null:
				rect = col.get_global_transform() * col.shape.get_rect()
				valid = true
		
		if valid:
			bounds = rect if not found else bounds.merge(rect)
			found = true
	
	return bounds


func _ready() -> void:
	if Engine.is_editor_hint():
		update_bounds()
	else:
		frame()
		get_viewport().size_changed.connect(frame)

func update_bounds() -> void:
	var root := owner if owner else get_parent()
	level_bounds = node_bounds(root)
	notify_property_list_changed()
	print("(%s) Level bounds calculated: " % [root.name], level_bounds)

func frame(pad := padding) -> void:
	frame_rect(level_bounds, pad)

func frame_rect(rect: Rect2, pad := room_padding) -> void:
	if not rect.has_area():
		if rect != level_bounds:
			frame()
		return
	
	var vp_size := get_viewport_rect().size
	var target_size := rect.size + (pad * 2.0)
	
	global_position = rect.get_center()
	
	var zoom_factor := minf(vp_size.x / target_size.x, vp_size.y / target_size.y)
	zoom = Vector2(zoom_factor, zoom_factor)
