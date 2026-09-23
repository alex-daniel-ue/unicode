class_name TutorialMask
extends Control

## A full-screen dim with holes cut in it. There is no CSG for Controls, so the
## cut is done twice: _draw() paints the dim everywhere except the holes, and
## _has_point() answers "not here" inside them, which sends the click to whatever
## is underneath.
##
## No shader. The dim is drawn as plain rectangles: the screen is cut into a grid
## along every hole edge and each cell outside all holes is filled. Up to eight
## holes is at most 17 x 17 cells, which is nothing to draw, and draw_rect()
## renders the same on every renderer and driver. The previous shader version
## drew correctly in the editor and as a flat dim with no holes in the lab
## export; this one has no way to differ between the two.

const MAX_HOLES := 8

## Breathing room around each target, in pixels. Applies to the drawn hole and
## to the clickable area alike, so what looks clickable is clickable.
@export var padding := 6.0
@export var dim_color := Color(0.02, 0.02, 0.08, 0.62)

## Holes in this control's local space, before padding.
var holes: Array[Rect2] = []

## Every click is swallowed, holes included.
var block_all := false

## False draws nothing while still blocking, for "just watch" screens.
var dimmed := true:
	set(value):
		if dimmed == value:
			return
		dimmed = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)
	queue_redraw()


func set_holes(rects: Array[Rect2]) -> void:
	if rects == holes:
		return
	holes = rects
	queue_redraw()


func _has_point(point: Vector2) -> bool:
	if block_all:
		return true
	for rect in holes:
		if rect.grow(padding).has_point(point):
			return false
	return true


func _draw() -> void:
	if not dimmed:
		return
	var bounds := Rect2(Vector2.ZERO, size)
	var cut: Array[Rect2] = []
	for i in mini(holes.size(), MAX_HOLES):
		var r := holes[i].grow(padding).intersection(bounds)
		# Whole pixels, so neighbouring cells share exact edges: no seams, no overlap.
		r = Rect2(r.position.round(), r.end.round() - r.position.round())
		if r.has_area():
			cut.append(r)
	if cut.is_empty():
		draw_rect(bounds, dim_color)
		return

	var xs := [0.0, size.x]
	var ys := [0.0, size.y]
	for r in cut:
		xs.append_array([r.position.x, r.end.x])
		ys.append_array([r.position.y, r.end.y])
	xs = _unique_sorted(xs)
	ys = _unique_sorted(ys)

	for yi in ys.size() - 1:
		for xi in xs.size() - 1:
			var cell := Rect2(xs[xi], ys[yi], xs[xi + 1] - xs[xi], ys[yi + 1] - ys[yi])
			if not cell.has_area():
				continue
			var centre := cell.get_center()
			var inside := false
			for r in cut:
				if r.has_point(centre):
					inside = true
					break
			if not inside:
				draw_rect(cell, dim_color)


static func _unique_sorted(values: Array) -> Array:
	values.sort()
	var out := []
	for v in values:
		if out.is_empty() or not is_equal_approx(v, out[-1]):
			out.append(v)
	return out
