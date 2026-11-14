class_name GuidePointer
extends Control
## The arrows from a guide's card to the things its page is about. The dim alone
## isn't enough: on a small screen, or at a first glance, a lit button among
## dimmed ones doesn't read as "this one". The arrows nudge towards their ends
## and back, so they read as pointing even out of the corner of an eye.
##
## TutorialOverlay sets `arrows` every frame, in this control's space: one
## [start, end] pair an arrow. `shown` false hides them all.
##
## On a page that waits for a click, a mouse cursor also sits on the button and
## clicks it, again and again, with a ring at each click: what to do, shown
## rather than only said.

const COLOR := Color(1.0, 0.82, 0.3)
const RIM := Color(0.105882354, 0.09411765, 0.13725491)
const WIDTH := 7.0
const HEAD := 22.0
## How far an arrow nudges towards its end, and how fast.
const NUDGE := 7.0
const NUDGE_SPEED := 5.0
## A mouse cursor, its tip at (0, 0).
const CURSOR := [
	Vector2(0.0, 0.0), Vector2(0.0, 17.0), Vector2(4.5, 13.0), Vector2(7.5, 19.5),
	Vector2(10.5, 18.2), Vector2(7.5, 12.0), Vector2(13.0, 12.0),
]
const CURSOR_SCALE := 1.8
## Seconds from one click to the next.
const CLICK_PERIOD := 1.4
## How far the cursor backs off between clicks, towards the bottom right.
const CURSOR_TRAVEL := 16.0
const RING_RADIUS := 30.0

var arrows: Array[PackedVector2Array] = []
## The button to click, in this control's space. An empty rect for none.
var click_target := Rect2()
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
	if click_target.has_area():
		_draw_cursor(click_target.get_center())


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


## The cursor glides in to `tip`, presses (it shrinks a little), and backs off,
## and each press sends out a ring that fades.
func _draw_cursor(tip: Vector2) -> void:
	var phase := fmod(_time, CLICK_PERIOD) / CLICK_PERIOD
	# On the button at the half, furthest off at the start and end.
	var away := (1.0 + cos(TAU * phase)) / 2.0
	var at := tip + Vector2.ONE.normalized() * CURSOR_TRAVEL * away
	if phase >= 0.5:
		var grown := (phase - 0.5) / 0.5
		var fade := 1.0 - grown
		var radius := lerpf(6.0, RING_RADIUS, grown)
		draw_arc(tip, radius, 0.0, TAU, 40, Color(RIM, fade * 0.8), 7.0, true)
		draw_arc(tip, radius, 0.0, TAU, 40, Color(COLOR, fade), 4.0, true)
	var pressed := phase > 0.44 and phase < 0.6
	var size_now := CURSOR_SCALE * (0.85 if pressed else 1.0)
	var shape := PackedVector2Array(CURSOR)
	var outline := PackedVector2Array(CURSOR)
	outline.append(CURSOR[0])
	draw_set_transform(at, 0.0, Vector2(size_now, size_now))
	draw_colored_polygon(shape, Color.WHITE)
	draw_polyline(outline, RIM, 1.6, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
