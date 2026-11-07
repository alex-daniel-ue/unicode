@tool
class_name LevelCamera
extends Camera2D
## The camera that shows the level in the room panel. It frames the whole
## level, from bounds baked in the editor (level_bounds), whenever the panel
## changes size or a run starts.

const PADDING := Vector2(8, 8)

@warning_ignore("unused_private_class_variable")
@export_tool_button("Update bounds") var _update_bounds_button := update_bounds
@warning_ignore("unused_private_class_variable")
@export_tool_button("Frame") var _frame_button := frame
@export var level_bounds: Rect2


## The rectangle everything visible under `root` covers, in global coordinates.
static func node_bounds(root: Node) -> Rect2:
	var bounds := Rect2()
	var found := false
	var nodes_to_check: Array[Node] = [root]

	while not nodes_to_check.is_empty():
		var current: Node = nodes_to_check.pop_back()
		if current is CanvasItem and not (current as CanvasItem).visible:
			continue

		# Boards, files and terminals are laid out or drawn in their own _ready()
		# and _draw(), which can come after this walk (the editor measures from
		# the camera's own _ready()). Each knows its size from its contents.
		if current is RoomEntity:
			var drawn := (current as RoomEntity).get_global_bounds()
			bounds = drawn if not found else bounds.merge(drawn)
			found = true
			continue

		nodes_to_check.append_array(current.get_children())

		var rect := Rect2()
		var valid := false
		if current is TileMapLayer:
			var map := current as TileMapLayer
			if map.tile_set:
				var used := map.get_used_rect()
				var tile_size := map.tile_set.tile_size
				rect = Rect2(Vector2(used.position) * Vector2(tile_size), Vector2(used.size) * Vector2(tile_size))
				rect = map.get_global_transform() * rect
				valid = true
		elif current is Sprite2D:
			var sprite := current as Sprite2D
			rect = sprite.get_global_transform() * sprite.get_rect()
			valid = true
		elif current is CollisionShape2D:
			var shape := current as CollisionShape2D
			if shape.shape != null:
				rect = shape.get_global_transform() * shape.shape.get_rect()
				valid = true

		if valid:
			bounds = rect if not found else bounds.merge(rect)
			found = true

	return bounds


func _ready() -> void:
	if Engine.is_editor_hint():
		# Deferred: the camera is readied before the level's later siblings
		# (Visuals), so measuring now would miss anything laid out in their
		# _ready(), and a level saved with those bounds framed its lists off-screen.
		update_bounds.call_deferred()
	else:
		frame()
		get_viewport().size_changed.connect(frame)


func update_bounds() -> void:
	var root := owner if owner else get_parent()
	level_bounds = node_bounds(root)
	notify_property_list_changed()
	print("(%s) Level bounds calculated: " % [root.name], level_bounds)


## Centres the view on the level and zooms it to fit.
func frame() -> void:
	if not level_bounds.has_area():
		return
	var view_size := get_viewport_rect().size
	var target_size := level_bounds.size + PADDING * 2.0
	global_position = level_bounds.get_center()
	var zoom_factor := minf(view_size.x / target_size.x, view_size.y / target_size.y)
	zoom = Vector2(zoom_factor, zoom_factor)
