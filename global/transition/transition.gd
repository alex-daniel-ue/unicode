extends CanvasLayer


@export var transition_time := 0.4

@onready var top_left := $TopLeft as Polygon2D
@onready var bottom_right := $BottomRight as Polygon2D

var screen_size: Vector2
var current_tween: Tween


func _ready() -> void:
	get_viewport().size_changed.connect(_update_screen_size)
	_update_screen_size()

func _update_screen_size() -> void:
	screen_size = get_viewport().get_visible_rect().size
	_setup_polygons()

func _setup_polygons() -> void:
	top_left.polygon = PackedVector2Array([
		Vector2.ZERO,
		Vector2(screen_size.x, 0),
		Vector2(0, screen_size.y)
	])
	
	bottom_right.polygon = PackedVector2Array([
		Vector2(screen_size.x, 0),
		screen_size,
		Vector2(0, screen_size.y)
	])

func _set_visible(to: bool) -> void:
	top_left.visible = to
	bottom_right.visible = to

func cover() -> void:
	_set_visible(true)
	
	current_tween = create_tween()
	current_tween.set_parallel()
	
	current_tween.tween_property(top_left, "position", Vector2.ZERO, transition_time)\
		.from(-screen_size / 2.).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	current_tween.tween_property(bottom_right, "position", Vector2.ZERO, transition_time)\
		.from(screen_size / 2.).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func reveal() -> void:
	current_tween = create_tween()
	current_tween.set_parallel()
	
	current_tween.tween_property(top_left, "position", -screen_size / 2., transition_time)\
		.from(Vector2.ZERO).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	current_tween.tween_property(bottom_right, "position", screen_size / 2., transition_time)\
		.from(Vector2.ZERO).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	
	await current_tween.finished
	_set_visible(false)
