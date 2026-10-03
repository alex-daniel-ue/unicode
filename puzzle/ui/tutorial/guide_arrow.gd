@tool
class_name GuideArrow
extends Control

## An arrow for guide pictures, drawn from `from` to `to`, both as fractions of
## this control's rect: (0, 0.5) to (1, 0.5) points right across it. Size and
## place the control where the arrow should be.

@export var from := Vector2(0, 0.5):
	set(value):
		from = value
		queue_redraw()
@export var to := Vector2(1, 0.5):
	set(value):
		to = value
		queue_redraw()
@export var color := Color(1.0, 0.82, 0.3):
	set(value):
		color = value
		queue_redraw()
@export var width := 3.0:
	set(value):
		width = value
		queue_redraw()
@export var head := 10.0:
	set(value):
		head = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	var a := from * size
	var b := to * size
	var direction := (b - a).normalized()
	if direction == Vector2.ZERO:
		return
	var base := b - direction * head
	draw_line(a, base, color, width, true)
	var side := direction.orthogonal() * head * 0.6
	draw_colored_polygon(PackedVector2Array([b, base + side, base - side]), color)
