extends PanelContainer

const TYPE_COLORS: Dictionary[Puzzle.NotificationType, Color] = {
	Puzzle.NotificationType.LOG: Color("#38BDF8"),
	Puzzle.NotificationType.ERROR: Color("#FB7185"),
	Puzzle.NotificationType.SUCCESS: Color("#34D399")
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
	
	modulate.a = 0.0
	var tween_in = create_tween()
	tween_in.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween_in.tween_property(self, "modulate:a", 1.0, 0.25)
	
	await get_tree().create_timer(duration / 2.0).timeout
	
	var tween_out = create_tween()
	tween_out.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUART)
	tween_out.tween_property(self, "modulate:a", 0.0, duration / 2.0)
	
	tween_out.finished.connect(queue_free)
