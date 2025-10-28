extends PanelContainer


const TYPE_COLORS: Dictionary[Puzzle.NotificationType, Color] = {
	Puzzle.NotificationType.LOG: Color.GOLDENROD,
	Puzzle.NotificationType.ERROR: Color.TOMATO,
	Puzzle.NotificationType.SUCCESS: Color.LIGHT_GREEN
}


@export var label: Label
var duration: float
var type: Puzzle.NotificationType


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	var stylebox := (get_theme_stylebox("panel") as StyleBoxFlat).duplicate(true)
	stylebox.border_color = TYPE_COLORS[type]
	add_theme_stylebox_override("panel", stylebox)
	
	await get_tree().create_timer(duration / 2.).timeout
	
	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUART)
	tween.tween_property(self, "modulate", Color("#FFF", 0), duration / 2.)
	
	get_tree().create_timer(duration / 2.).timeout.connect(queue_free)
