class_name GuidePointer
extends Control

## The arrows from a guide's card to the things its page is about. The dim alone
## wasn't enough: on a small screen, or at a first glance, a lit button among
## dimmed ones didn't read as "this one". The arrows nudge towards their ends
## and back, so they read as pointing even out of the corner of an eye.
##
## TutorialOverlay sets `arrows` every frame, in this control's space: one
## [start, end] pair an arrow. `shown` false hides them all.

const COLOR := Color(1.0, 0.82, 0.3)
const RIM := Color(0.105882354, 0.09411765, 0.13725491)
const WIDTH := 7.0
const HEAD := 22.0
## How far an arrow nudges towards its end, and how fast.
const NUDGE := 7.0
const NUDGE_SPEED := 5.0

var arrows: Array[PackedVector2Array] = []
var shown := false:
	set(value):
		if shown == value:
			return
		shown = value
		if shown:
			modulate.a = 0.0
			create_tween().tween_property(self, "modulate:a", 1.0, 0.2)
		queue_redraw()

var _time := 0.0


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	_time += delta
	if shown:
		queue_redraw()

func _draw() -> void:
	if not shown:
		return
	for pair in arrows:
		if pair.size() == 2:
			_draw_arrow(pair[0], pair[1])

func _draw_arrow(start: Vector2, end: Vector2) -> void:
	var line := end - start
	if line.length() < HEAD * 2.0:
		return
	var direction := line.normalized()
	var nudge := direction * (sin(_time * NUDGE_SPEED) * 0.5 + 0.5) * NUDGE
	var a := start + nudge
	var b := end + nudge
	var base := b - direction * HEAD
	var side := direction.orthogonal() * HEAD * 0.62
	# A dark rim first, so the arrow holds up on the dim and on bright panels.
	draw_line(a, base, RIM, WIDTH + 5.0, true)
	draw_colored_polygon(PackedVector2Array([b + direction * 4.0, base + side * 1.25 - direction * 2.0, base - side * 1.25 - direction * 2.0]), RIM)
	draw_line(a, base, COLOR, WIDTH, true)
	draw_colored_polygon(PackedVector2Array([b, base + side, base - side]), COLOR)
	draw_circle(a, WIDTH * 0.9, RIM)
	draw_circle(a, WIDTH * 0.55, COLOR)
