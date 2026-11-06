class_name TileStrip
extends Control
## A row of room tiles for guide pictures, drawn with the rooms' own sprites at
## twice their size: floor, the robot, and what can stand on a tile. Everything
## is set before it enters the tree; GuideGraphics builds these.
##
## `cells`, one character a tile:
##   .  floor      P  puddle (the wet floor sign)     F  green flag (the destination)
##   B  battery    D  desk (blocked)                 W  wall (blocked)
## The robot, a faded "where it ends up" robot, an arrow, a box around the tile
## being looked at, and small numbers on tiles all go on top.

const SCALE := 2
const TILE := 32 * SCALE
## The robot and desks are taller than a tile; this much room is kept above.
const OVERHANG := 16 * SCALE

const FLOOR := preload("res://world/assets/tilesets/school_floor.png")
const FLOOR_REGION := Rect2(32, 32, 32, 32)
const PUDDLE := preload("res://level/objects/danger.png")
const FLAG := preload("res://level/objects/green_flag.png")
const BATTERY := preload("res://world/assets/objects/battery.png")
const DESK := preload("res://world/assets/objects/chairs.png")
const DESK_REGION := Rect2(0, 0, 32, 48)
const WALLS := preload("res://world/assets/tilesets/school_walls.png")
## The rooms' wall face, top edge to blue baseboard: two tiles tall, as the
## rooms draw it.
const WALL_REGION := Rect2(32, 0, 32, 64)
const ROBOT_FRAMES := preload("res://level/objects/entities/robot/sprite_frames.tres")
const MARK_FONT := preload("res://puzzle/ui/themes/fonts/Kenney Mini.ttf")
const ACCENT := Color(1.0, 0.82, 0.3)
const INK := Color(0.105882354, 0.09411765, 0.13725491)

var cells := "."
var robot := -1
var facing := Vector2.RIGHT
var ghost := -1
var ghost_facing := Vector2.RIGHT
var arrow_from := -1
var arrow_to := -1
var looked_at := -1
## Tile index -> a short text drawn on that tile ("1", "2").
var marks := {}


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(cells.length() * TILE, TILE + _overhang())


func _draw() -> void:
	for i in cells.length():
		var tile := _tile_rect(i)
		draw_texture_rect_region(FLOOR, tile, FLOOR_REGION)
	for i in cells.length():
		_draw_thing(cells[i], _tile_rect(i))
	if looked_at >= 0:
		draw_rect(_tile_rect(looked_at).grow(-3), ACCENT, false, 4.0)
	for i: int in marks:
		var at := _tile_rect(i).get_center() + Vector2(0, TILE * 0.3)
		_draw_centered_text(str(marks[i]), at, 16)
	if ghost >= 0:
		_draw_robot(ghost, ghost_facing, Color(1, 1, 1, 0.4))
	if robot >= 0:
		_draw_robot(robot, facing, Color.WHITE)
	if arrow_from >= 0 and arrow_to >= 0 and arrow_from != arrow_to:
		_draw_arrow(arrow_from, arrow_to)


## A wall is a whole tile taller than anything else drawn here.
func _overhang() -> float:
	return TILE if cells.contains("W") else OVERHANG


func _tile_rect(i: int) -> Rect2:
	return Rect2(i * TILE, _overhang(), TILE, TILE)


func _draw_thing(code: String, tile: Rect2) -> void:
	match code:
		"P":
			draw_texture_rect(PUDDLE, tile, false)
		"F":
			draw_texture_rect(FLAG, tile, false)
		"B":
			draw_texture_rect(BATTERY, tile, false)
		"D":
			var size := DESK_REGION.size * SCALE
			draw_texture_rect_region(DESK, Rect2(Vector2(tile.position.x, tile.end.y - size.y), size), DESK_REGION)
		"W":
			var size := WALL_REGION.size * SCALE
			draw_texture_rect_region(WALLS, Rect2(Vector2(tile.position.x, tile.end.y - size.y), size), WALL_REGION)


func _draw_robot(i: int, direction: Vector2, tint: Color) -> void:
	var animation := &"idle_right"
	match direction:
		Vector2.LEFT: animation = &"idle_left"
		Vector2.UP: animation = &"idle_forward"
		Vector2.DOWN: animation = &"idle_backward"
	var texture := ROBOT_FRAMES.get_frame_texture(animation, 0)
	if texture == null:
		return
	var size := texture.get_size() * SCALE
	var tile := _tile_rect(i)
	var spot := Rect2(Vector2(tile.get_center().x - size.x / 2.0, tile.end.y - size.y - 4), size)
	draw_texture_rect(texture, spot, false, tint)


## Along the bottom of the tiles, under the robot's feet.
func _draw_arrow(from: int, to: int) -> void:
	var y := _overhang() + TILE - 10.0
	var a := Vector2(_tile_rect(from).get_center().x, y)
	var b := Vector2(_tile_rect(to).get_center().x, y)
	var direction := (b - a).normalized()
	var head := 12.0
	var base := b - direction * head
	draw_line(a, base, INK, 9.0, true)
	draw_line(a, base, ACCENT, 5.0, true)
	var side := direction.orthogonal() * head * 0.7
	var outline := PackedVector2Array([b + direction * 3.0, base + side * 1.3, base - side * 1.3])
	draw_colored_polygon(outline, INK)
	draw_colored_polygon(PackedVector2Array([b, base + side, base - side]), ACCENT)


func _draw_centered_text(text: String, at: Vector2, size: int) -> void:
	var width := MARK_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var spot := at + Vector2(-width / 2.0, size * 0.35)
	draw_string_outline(MARK_FONT, spot, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, INK)
	draw_string(MARK_FONT, spot, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, ACCENT)
