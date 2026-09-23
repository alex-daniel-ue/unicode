class_name TutorialMask
extends ColorRect

## A full-screen dim with holes cut in it. There is no CSG for Controls, so the
## cut is done twice: the shader draws the holes, and _has_point() answers "not
## here" inside them, which sends the click to whatever is underneath. Verified
## in 4.5.1: a button under a hole gets pressed, the same button with the hole
## closed does not, and the pause menu (an embedded window) and the keyboard
## still work under a full blocker.

const MAX_HOLES := 8

## Breathing room around each target, in pixels. Applies to the drawn hole and
## to the clickable area alike, so what looks clickable is clickable.
@export var padding := 6.0

## Holes in this control's local space.
var holes: Array[Rect2] = []

## Every click is swallowed, holes included.
var block_all := false

## False draws nothing while still blocking, for "just watch" screens.
var dimmed := true:
	set(value):
		dimmed = value
		_push()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(_push)
	_push()


func set_holes(rects: Array[Rect2]) -> void:
	if rects == holes:
		return
	holes = rects
	_push()


func _has_point(point: Vector2) -> bool:
	if block_all:
		return true
	for rect in holes:
		if rect.grow(padding).has_point(point):
			return false
	return true


func _push() -> void:
	var mat := material as ShaderMaterial
	if mat == null:
		return
	# One vec4 per hole, not one array: see tutorial_mask.gdshader for why an
	# array uniform is the thing that broke the highlights in exported builds.
	for i in MAX_HOLES:
		var packed := Vector4.ZERO
		if i < holes.size():
			var r := holes[i].grow(padding)
			packed = Vector4(r.position.x, r.position.y, r.size.x, r.size.y)
		mat.set_shader_parameter("hole_%d" % i, packed)
	mat.set_shader_parameter("hole_count", mini(holes.size(), MAX_HOLES))
	mat.set_shader_parameter("rect_size", size)
	mat.set_shader_parameter("dim_strength", 1.0 if dimmed else 0.0)
