class_name TileScan
extends Node2D
## The robot looking at the tile in front of it, for Ahead Is: a yellow frame
## on the tile and a band of light sweeping across it, away from the robot, the
## way a list's board lights the box a block reads. Then the frame takes the
## answer's colour, green for True and pink for False (the value tags' colours),
## and fades. Without it, a check that comes out False looks like nothing
## happened at all.
##
## Made and freed by Robot.ahead_is(); one tile, centred on this node, with the
## sweep running along +x (the robot rotates it to face the way it looks).

const ACCENT := Color(1.0, 0.82, 0.3)
const TRUE_COLOR := Color("#7dd3a0")
const FALSE_COLOR := Color("#fb7185")
const FRAME := 2.0

var tile := 32.0
var found := false
## 0 to 1 across the tile, then held.
var sweep := 0.0:
	set(value):
		sweep = value
		queue_redraw()
## From the accent to the answer's colour.
var settle := 0.0:
	set(value):
		settle = value
		queue_redraw()


func _draw() -> void:
	var half := tile / 2.0
	var box := Rect2(-half, -half, tile, tile).grow(-1.0)
	var answer := TRUE_COLOR if found else FALSE_COLOR
	var color := ACCENT.lerp(answer, settle)
	# The light that has swept across so far, brightest at its leading edge.
	var reach := box.size.x * sweep
	draw_rect(Rect2(box.position, Vector2(reach, box.size.y)), Color(color, 0.35 * (1.0 - settle)))
	var edge := box.position.x + reach
	draw_rect(Rect2(Vector2(edge - 3.0, box.position.y), Vector2(3.0, box.size.y)), Color(color, 0.9 * (1.0 - settle)))
	draw_rect(box, Color(color, 0.25 * settle))
	draw_rect(box.grow(-FRAME / 2.0), color, false, FRAME)


## Shows the scan over `time` seconds, then frees itself.
func play(time: float) -> void:
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, time * 0.1)
	tween.parallel().tween_property(self, "sweep", 1.0, time * 0.45) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "settle", 1.0, time * 0.15)
	tween.tween_interval(time * 0.15)
	tween.tween_property(self, "modulate:a", 0.0, time * 0.25)
	tween.tween_callback(queue_free)
