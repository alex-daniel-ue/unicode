class_name RunPointer
extends Control

## The pointer beside the line that's running, as on the main menu's demo
## (menu_demo.gd): a gold arrow left of the program the line is in, sliding
## from line to line as each block lights up. On the canvas, so it pans and
## zooms with the blocks, and hidden while nothing runs.

const INK := Color("141e33")
const GOLD := Color("ffcf4a")
## Between the arrow's tip and the program's left edge.
const GAP := 10.0
const SLIDE := 0.15

var _slide: Tween


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	size = Vector2(12, 18)
	z_index = 1
	visible = false
	Interpreter.block_highlighted.connect(_on_block_highlighted)
	Interpreter.running_changed.connect(_on_running_changed)

func _on_running_changed() -> void:
	if Interpreter.is_running:
		return
	if _slide != null and _slide.is_valid():
		_slide.kill()
	visible = false

## To the first line of `block`, the part that lights up. A value in a slot
## lights up while its block works it out, so for one the arrow goes to the
## line of the block the slot is in.
func _on_block_highlighted(block: Block) -> void:
	var canvas := get_parent() as Control
	if not Interpreter.is_running or canvas == null or not canvas.is_ancestor_of(block):
		return
	var owner_block: Node = block
	while owner_block != null and (not owner_block is Block or owner_block is SocketBlock):
		owner_block = owner_block.get_parent()
	if owner_block == null:
		return
	var line := owner_block.get_node_or_null(^"UpperLip") as Control
	if line == null:
		return
	# The program the line is in: begin's, or a function's define block.
	var program: Node = owner_block
	while program.get_parent() != canvas:
		program = program.get_parent()
	var to_canvas := canvas.get_global_transform().affine_inverse() * line.get_global_transform()
	var at := Vector2(
		(program as Control).position.x - size.x - GAP,
		(to_canvas * (line.size / 2.0)).y - size.y / 2.0).round()
	if _slide != null and _slide.is_valid():
		_slide.kill()
	if not visible:
		position = at
		visible = true
		return
	_slide = create_tween()
	_slide.tween_property(self, "position", at, minf(SLIDE, Interpreter.current_delay * 0.5)) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

## A pixel triangle pointing right, drawn as the demo's is: a column every 2 px,
## the ink one round each gold one.
func _draw() -> void:
	var mid := size.y / 2.0
	var ink := [9.0, 9.0, 7.0, 5.0, 3.0, 1.0]
	var gold := [7.0, 5.0, 3.0, 1.0]
	for i in ink.size():
		draw_rect(Rect2(2.0 * i, mid - ink[i], 2.0, 2.0 * ink[i]), INK)
	for i in gold.size():
		draw_rect(Rect2(2.0 + 2.0 * i, mid - gold[i], 2.0, 2.0 * gold[i]), GOLD)
