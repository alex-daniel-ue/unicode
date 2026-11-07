class_name MenuDemo
extends PanelContainer
## The main menu's demos, in the courtyard: a short program beside a little
## classroom where it runs, each block lighting up as it runs. A few of them
## take turns, so the menu shows what the game is about in more than one way:
## a robot going round a desk, a robot checking ahead and turning around at the
## walls, a robot following the values in a list, and a list swapping two of
## its own values.
##
## Played by Tweens, not by the Interpreter: that is global, and it's what a
## level runs on. Each demo is worked out step by step when it starts, the way
## the program would run (a block lights up for a step, then acts; a beat after
## an if or a loop finishes), and replayed as one Tween that ends where it
## began, so it loops without a seam. The rooms are menus/main/demo_*.tscn,
## made by tools/menu/gen_demo_room.py.
##
## The card is a whiteboard: SAMPLE PUZZLE and the demo's name along the top,
## a dot a demo in the corner, a pointer beside the line that's running, the
## room held up by two magnets, and a tray of pens along the bottom. The frame
## is the panel's style in main_menu.tscn; the rest is drawn here.

const DEMOS: Array[Dictionary] = [
	{
		title = "while loop",
		room = "res://menus/main/demo_lap.tscn", play = &"_play_lap", cycles = 2,
		program = '[["while", ["bool", "True"], {"body": [["moven", 2], ["turn", "left"]]}]]',
	},
	{
		title = "for each loop",
		room = "res://menus/main/demo_route.tscn", play = &"_play_route", cycles = 2,
		program = '[["while", ["bool", "True"], {"body": [["each", "steps", ["list", "route"], {"body": [["moven", "steps"], ["turn", "left"]]}]]}]]',
	},
	{
		title = "if / else",
		room = "res://menus/main/demo_patrol.tscn", play = &"_play_patrol", cycles = 1,
		program = '[["while", ["bool", "True"], {"body": [["if", ["ahead", "blocked"], {"body": [["turn", "around"]]}], ["else", {"body": [["move"]]}]]}]]',
	},
	{
		title = "swapping values",
		room = "res://menus/main/demo_swap.tscn", play = &"_play_swap", cycles = 3,
		program = '[["while", ["bool", "True"], {"body": [["declare", "temp", ["index", 0, ["list", "nums"]]], ["setitem", 0, ["list", "nums"], ["index", 2, ["list", "nums"]]], ["setitem", 2, ["list", "nums"], "temp"]]}]]',
	},
]

const TILE := 32.0
## How long a block stays lit before it acts. Brisker than a level's normal
## speed (0.7 s), since nobody is reading along closely here.
const STEP := 0.45
## As robot.gd: one tile's move, and the hop of a turn.
const MOVE_TIME := 0.2
const TURN_TIME := 0.26
const HOP := 7.0
const FADE := 0.35
## The room's height at most, as a share of the window's. It's drawn at a
## whole-number scale, so its pixels stay square.
const ROOM_SHARE := 0.42
## Room kept clear between the card and the window's edge, or `avoid`.
const GAP := 32.0
const FACING_ANIMATION := {
	Vector2.RIGHT: &"idle_right", Vector2.LEFT: &"idle_left",
	Vector2.UP: &"idle_forward", Vector2.DOWN: &"idle_backward",
}

## The board's colours, as the title logo and buttons have them
## (tools/menu/gen_menu_art.py).
const INK := Color("141e33")
const GOLD := Color("ffcf4a")
const CYAN := Color("6ce1e7")
const PAPER := Color("f3f6fb")
const MUTED := Color("8ea2c6")
const DOT := Color("4c607b")
const FRAME_SHADE := Color("8493ad")
const TRAY_TOP := Color("d3dce8")
const TRAY_FRONT := Color("9cabc1")
const ERASER := Color("5f6f8a")
const ERASER_TOP := Color("94a3bb")
## The panel's border in main_menu.tscn.
const FRAME := 6.0
## How far the tray reaches past the board on each side.
const TRAY_REACH := 16.0
const FONT := preload("res://puzzle/ui/themes/fonts/Kenney Mini.ttf")

## The menu's logo and buttons: the card sits in the space to their right.
@export var avoid: Array[Control] = []

var _index := 0
var _title: Label
var _dots: HBoxContainer
## Over the card's content, for what the board draws on top of it.
var _overlay: Control
## Where the pointer beside the running line is, down the card; NAN before a
## demo's first step.
var _pointer_y := NAN
var _slide: Tween
var _row: HBoxContainer
var _picture: BlockPicture
var _room: Node2D
var _room_view: Control
var _room_size := Vector2(224, 192)
var _robot: Node2D
var _sprite: AnimatedSprite2D
var _list: ListEntity
var _player: Tween
## Where the robot is and faces while a demo's steps are worked out.
var _at := Vector2.ZERO
var _facing := Vector2.RIGHT
var _rest := Vector2.ZERO


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	var board := VBoxContainer.new()
	board.add_theme_constant_override(&"separation", 18)
	board.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(board)
	board.add_child(_header())
	_row = HBoxContainer.new()
	_row.add_theme_constant_override(&"separation", 28)
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.mouse_filter = MOUSE_FILTER_IGNORE
	board.add_child(_row)
	_overlay = Control.new()
	_overlay.mouse_filter = MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)
	board.sort_children.connect(_redraw)
	_row.sort_children.connect(_redraw)
	get_viewport().size_changed.connect(_fit)
	# The logo is sized to the window after this is, so the card fits again
	# once it has been.
	for node in avoid:
		if node != null:
			node.resized.connect(_fit)
	resized.connect(func() -> void: _place.call_deferred())
	_show(0)


## SAMPLE PUZZLE over the demo's name, with a dot a demo beside the name, the
## one showing lit.
func _header() -> Control:
	var header := VBoxContainer.new()
	header.add_theme_constant_override(&"separation", 2)
	header.mouse_filter = MOUSE_FILTER_IGNORE
	var spaced := FontVariation.new()
	spaced.base_font = FONT
	spaced.spacing_glyph = 2
	header.add_child(_label("SAMPLE PUZZLE", spaced, 16, MUTED))
	var title_row := HBoxContainer.new()
	title_row.mouse_filter = MOUSE_FILTER_IGNORE
	header.add_child(title_row)
	_title = _label("", FONT, 32, PAPER)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(_title)
	_dots = HBoxContainer.new()
	_dots.add_theme_constant_override(&"separation", 6)
	_dots.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_dots.mouse_filter = MOUSE_FILTER_IGNORE
	for i in DEMOS.size():
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(10, 10)
		dot.mouse_filter = MOUSE_FILTER_IGNORE
		_dots.add_child(dot)
	title_row.add_child(_dots)
	return header


func _label(text: String, font: Font, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override(&"font", font)
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", color)
	return label


#region Taking turns
func _show(index: int) -> void:
	if _player != null and _player.is_valid():
		_player.kill()  # it drives nodes that are about to go
	_index = index % DEMOS.size()
	var demo: Dictionary = DEMOS[_index]
	_title.text = demo.title
	for i in _dots.get_child_count():
		(_dots.get_child(i) as ColorRect).color = GOLD if i == _index else DOT
	if _slide != null and _slide.is_valid():
		_slide.kill()
	_pointer_y = NAN
	for old in _row.get_children():
		_row.remove_child(old)
		old.queue_free()

	_picture = BlockPicture.new()
	_picture.program = demo.program
	_picture.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_row.add_child(_picture)

	_room_view = Control.new()
	_room_view.mouse_filter = MOUSE_FILTER_IGNORE
	_room_view.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_row.add_child(_room_view)
	_room = (load(demo.room) as PackedScene).instantiate() as Node2D
	_room_size = _room.get_meta(&"size", Vector2(224, 192))
	_room_view.add_child(_room)
	_robot = _room.get_node_or_null(^"YSorted/Robot") as Node2D
	_sprite = _robot.get_node(^"Sprite") as AnimatedSprite2D if _robot != null else null
	_list = null
	for child in _room.get_children():
		if child is ListEntity:
			_list = child as ListEntity

	# The picture builds its blocks in their own _ready(); size and find them after.
	await get_tree().process_frame
	await get_tree().process_frame
	_fit()
	_play(demo)


func _play(demo: Dictionary) -> void:
	if _robot != null:
		_at = _robot.position
		_facing = Vector2.RIGHT
		_rest = _sprite.position
	_player = create_tween().set_loops(demo.cycles)
	call(demo.play, _player)
	_player.finished.connect(_next, CONNECT_ONE_SHOT)


## Fades this demo out and the next one in.
func _next() -> void:
	var out := create_tween()
	out.tween_property(self, "modulate:a", 0.0, FADE)
	await out.finished
	_show(_index + 1)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	create_tween().tween_property(self, "modulate:a", 1.0, FADE)
#endregion


#region Size and place
## The room at the biggest whole-number scale whose card fits: under
## ROOM_SHARE of the window's height, and between `avoid` and the right edge.
func _fit() -> void:
	if _room == null:
		return
	var window := get_viewport_rect().size
	var chrome := get_theme_stylebox(&"panel").get_minimum_size().x + 2.0 * TRAY_REACH
	var room_width := window.x - _left_limit() - GAP - _picture.size.x - 28.0 - chrome
	var k := 1
	for k_try in [3, 2]:
		if _room_size.y * k_try <= window.y * ROOM_SHARE and _room_size.x * k_try <= room_width:
			k = k_try
			break
	_room.scale = Vector2(k, k)
	_room_view.custom_minimum_size = _room_size * k
	reset_size()
	_place.call_deferred()


## Centred in the space right of `avoid`, so each demo's card, whatever its
## size, sits in the middle of it. In a window too small for the card (its room
## is at 1x by then), the whole card shrinks to fit. Set by hand: reset_size()
## grows a control from its top-left.
func _place() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var window := get_viewport_rect().size
	var space := Vector2(window.x - GAP - _left_limit(), window.y - 2.0 * GAP)
	var fit := clampf(minf(space.x / size.x, space.y / size.y), 0.25, 1.0)
	scale = Vector2(fit, fit)
	var shown := size * fit
	position = Vector2(_left_limit() + (space.x - shown.x) / 2.0, GAP + (space.y - shown.y) / 2.0).round()


## Where the free space starts, a GAP past the right edge of whatever in
## `avoid` reaches furthest. Their laid-out rects, not their drawn ones: the
## logo is still scaled while it pops in.
func _left_limit() -> float:
	var edge := 0.0
	for node in avoid:
		if node != null and node.is_visible_in_tree():
			var laid_out := (node.get_parent() as CanvasItem).get_global_transform() * (node.position + node.size)
			edge = maxf(edge, laid_out.x)
	return edge + GAP
#endregion


#region The board
func _redraw() -> void:
	queue_redraw()
	_overlay.queue_redraw()


## Under the content: an ink line round the board and the frame's shaded
## inner edge.
func _draw() -> void:
	var board := Rect2(Vector2.ZERO, size)
	_frame(self, board.grow(2.0), 2.0, INK)
	_frame(self, board.grow(-FRAME), 2.0, FRAME_SHADE)


## Over the content: the tray with its pens and eraser, the magnets holding
## the room up, and the pointer beside the running line.
func _draw_overlay() -> void:
	_overlay.draw_set_transform(-_overlay.position)
	var tray := Rect2(-TRAY_REACH, size.y + 2.0, size.x + 2.0 * TRAY_REACH, 10.0)
	_chip(_overlay, tray, TRAY_FRONT)
	_overlay.draw_rect(Rect2(tray.position, Vector2(tray.size.x, 4.0)), TRAY_TOP)
	var pen_x := roundf(size.x * 0.1)
	for color: Color in [PAPER, GOLD, CYAN]:
		_chip(_overlay, Rect2(pen_x, tray.position.y - 6.0, 26.0, 4.0), color)
		pen_x += 34.0
	var eraser := Rect2(roundf(size.x * 0.74), tray.position.y - 12.0, 54.0, 10.0)
	_chip(_overlay, eraser, ERASER)
	_overlay.draw_rect(Rect2(eraser.position, Vector2(eraser.size.x, 4.0)), ERASER_TOP)
	if _room_view != null and _room_view.size.x > 0.0:
		var room := _local_rect(_room_view)
		for magnet: Array in [[0.18, CYAN], [0.82, GOLD]]:
			var x := roundf(room.position.x + room.size.x * magnet[0]) - 11.0
			_chip(_overlay, Rect2(x, room.position.y - 7.0, 22.0, 10.0), magnet[1])
	if not is_nan(_pointer_y) and _picture != null:
		_draw_pointer(Vector2(_local_rect(_picture).position.x - 22.0, _pointer_y).round())


## A pixel triangle pointing right, from `at` to 8 px past it, in ink.
func _draw_pointer(at: Vector2) -> void:
	# Half the height of each 2 px column: the ink one round each gold one.
	var ink := [9.0, 9.0, 7.0, 5.0, 3.0, 1.0]
	var gold := [7.0, 5.0, 3.0, 1.0]
	for i in ink.size():
		_overlay.draw_rect(Rect2(at.x - 2.0 + 2.0 * i, at.y - ink[i], 2.0, 2.0 * ink[i]), INK)
	for i in gold.size():
		_overlay.draw_rect(Rect2(at.x + 2.0 * i, at.y - gold[i], 2.0, 2.0 * gold[i]), GOLD)


## Slides the pointer to `block`'s first line, the part that lights up.
func _point_at(block: Block) -> void:
	var line := block.get_node_or_null(^"UpperLip") as Control
	if line == null:
		return
	var y := _local_rect(line).get_center().y
	if _slide != null and _slide.is_valid():
		_slide.kill()
	if is_nan(_pointer_y):
		_set_pointer(y)
		return
	_slide = create_tween()
	_slide.tween_method(_set_pointer, _pointer_y, y, STEP * 0.3) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _set_pointer(y: float) -> void:
	_pointer_y = y
	_overlay.queue_redraw()


## `control`'s rect in the card's own coordinates, whatever the card's scale.
func _local_rect(control: Control) -> Rect2:
	var to_card := get_global_transform().affine_inverse() * control.get_global_transform()
	return Rect2(to_card.origin, to_card.basis_xform(control.size))


## A band `width` wide just inside `rect`'s edges.
static func _frame(on: CanvasItem, rect: Rect2, width: float, color: Color) -> void:
	on.draw_rect(Rect2(rect.position.x, rect.position.y, rect.size.x, width), color)
	on.draw_rect(Rect2(rect.position.x, rect.end.y - width, rect.size.x, width), color)
	on.draw_rect(Rect2(rect.position.x, rect.position.y, width, rect.size.y), color)
	on.draw_rect(Rect2(rect.end.x - width, rect.position.y, width, rect.size.y), color)


## `rect` filled with `color` in a 2 px ink outline.
static func _chip(on: CanvasItem, rect: Rect2, color: Color) -> void:
	on.draw_rect(rect.grow(2.0), INK)
	on.draw_rect(rect, color)
#endregion


#region Demos
## while True: step forward 2 times; turn left. Four sides of a square round
## the desk, back where it began.
func _play_lap(t: Tween) -> void:
	var loop := _block("While")
	var move := _block("Step Forward N Times")
	var turn := _block("Turn")
	for side in 4:
		_step(t, loop)
		_step(t, move)
		_move(t, 2)
		_step(t, turn)
		_turn(t, "left")


## while True: for each steps in route: step forward steps times; turn left.
## The board's cursor sits on the value in use; the four values make a
## rectangle back to the start. A beat after the for each, before the while
## asks again.
func _play_route(t: Tween) -> void:
	var loop := _block("While")
	var each := _block("For Each")
	var move := _block("Step Forward N Times")
	var turn := _block("Turn")
	_step(t, loop)
	for i in _list.values.size():
		t.tween_callback(_list.point_at.bind(i))
		_step(t, each)
		_step(t, move)
		_move(t, int(_list.values[i]))
		_step(t, turn)
		_turn(t, "left")
	t.tween_callback(_list.point_at.bind(-1))
	t.tween_interval(STEP)


## while True: if ahead is blocked: turn around, else: step forward. Along the
## hallway and back, the tile ahead lit by each check (TileScan).
func _play_patrol(t: Tween) -> void:
	var loop := _block("While")
	var check := _block("If")
	var otherwise := _block("Else")
	var move := _block("Step Forward")
	var turn := _block("Turn")
	var start := _at
	var start_facing := _facing
	var length := int(_room_size.x / TILE) - 2  # the floor, between the side walls
	var column := 0
	var turns := 0
	while turns < 2:
		var blocked := (_facing == Vector2.RIGHT and column == length - 1) or (_facing == Vector2.LEFT and column == 0)
		_step(t, loop)
		_step(t, check)
		t.tween_callback(_scan.bind(_facing, blocked))
		t.tween_interval(STEP)
		if blocked:
			_step(t, turn)
			_turn(t, "around")
			turns += 1
		else:
			_step(t, otherwise)
			_step(t, move)
			_move(t, 1)
			column += 1 if _facing == Vector2.RIGHT else -1
		t.tween_interval(STEP)  # the beat after the if and else
	assert(_at == start and _facing == start_facing)


## while True: declare temp as index 0 of nums; set index 0 of nums to index 2
## of nums; set index 2 of nums to temp. The first and last values change
## places, flying across the board, and change back on the next pass.
func _play_swap(t: Tween) -> void:
	var loop := _block("While")
	var declare := _block("Declare As")
	var set_index := _blocks("Set Index")
	var values := _list.values.duplicate()
	for pass_ in 2:
		_step(t, loop)
		t.tween_callback(_list.show_read.bind(0))
		_step(t, declare)
		var temp: Variant = values[0]
		t.tween_callback(_list.show_read.bind(2))
		_step(t, set_index[0])
		values[0] = values[2]
		t.tween_callback(_list.show_write.bind(0, values[0]))
		t.tween_interval(STEP)
		_step(t, set_index[1])
		values[2] = temp
		t.tween_callback(_list.show_write.bind(2, values[2]))
		t.tween_interval(STEP)
#endregion


#region Steps
## A block lighting up for one step, as a running block does.
func _step(t: Tween, block: Block) -> void:
	t.tween_callback(_light.bind(block))
	t.tween_interval(STEP)


func _move(t: Tween, tiles: int) -> void:
	for i in tiles:
		_at += _facing * TILE
		t.tween_property(_robot, "position", _at, MOVE_TIME)


## A turn as robot.gd turns: left is (y, -x), right is (-y, x), around is -1 x.
func _turn(t: Tween, how: String) -> void:
	match how:
		"left": _facing = Vector2(_facing.y, -_facing.x)
		"right": _facing = Vector2(-_facing.y, _facing.x)
		"around": _facing = -_facing
	t.tween_callback(_sprite.play.bind(FACING_ANIMATION[_facing]))
	t.tween_property(_sprite, "position:y", _rest.y - HOP, TURN_TIME / 2.0) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(_sprite, "position:y", _rest.y, TURN_TIME / 2.0) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


## The tile ahead lit up, as Ahead Is lights it in a level.
func _scan(facing: Vector2, found: bool) -> void:
	var scan := TileScan.new()
	scan.tile = TILE
	scan.found = found
	scan.position = facing * TILE
	scan.rotation = facing.angle()
	scan.show_behind_parent = true
	_robot.add_child(scan)
	scan.play(STEP * 0.85)


## The pictured block with this title, or null.
func _block(title: String) -> Block:
	var found := _blocks(title)
	return found[0] if not found.is_empty() else null


## Every pictured block with this title, top to bottom.
func _blocks(title: String) -> Array[Block]:
	var found: Array[Block] = []
	for node in _picture.find_children("*", "Block", true, false):
		if (node as Block).data.title == title:
			found.append(node as Block)
	return found


## Lights `block` the way a running block lights up, for one step, and points
## at it. A picture's blocks don't animate their own colours, so this sets
## them directly.
func _light(block: Block) -> void:
	if block == null:
		return
	var lit := block.visual.saturate(block.data.color)
	for part in block.visual.color_affected:
		part.self_modulate = lit
		var fade := part.create_tween()
		fade.tween_interval(STEP * 0.75)
		fade.tween_property(part, "self_modulate", block.data.color, STEP * 0.25)
	_point_at(block)
#endregion
