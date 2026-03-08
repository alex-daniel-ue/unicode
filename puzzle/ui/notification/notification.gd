class_name Notification
extends PanelContainer


enum Type {
	LOG,
	ERROR,
	SUCCESS
}

const _COLORS: Dictionary[Type, Color] = {
	Type.LOG: Color("#38BDF8"),
	Type.ERROR: Color("#FB7185"),
	Type.SUCCESS: Color("#34D399")
}

@export var label: Label

var type: Type


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	# Duplicate default stylebox and change to appropriate color
	var stylebox := (get_theme_stylebox("panel") as StyleBoxFlat).duplicate(true)
	stylebox.border_color = _COLORS[type]
	add_theme_stylebox_override("panel", stylebox)
	
	modulate.a = 0.0
	
	var tween_in := create_tween()
	tween_in.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween_in.tween_property(self, "modulate:a", 1.0, 0.25)
	
	var duration := calculate_duration(label.text)
	await get_tree().create_timer(duration / 2.0).timeout
	
	var tween_out := create_tween()
	tween_out.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUART)
	tween_out.tween_property(self, "modulate:a", 0.0, duration / 2.0)
	
	tween_out.finished.connect(queue_free)

func with(_type: Type) -> Notification:
	type = _type
	return self

func calculate_duration(text: String) -> float:
	const BASE_TIME := 1.2
	const CHARS_PER_SEC := 20.0 # ~250 WPM
	
	var read_time := text.length() / CHARS_PER_SEC
	var final_duration := BASE_TIME + read_time
	
	return clampf(final_duration, 2.0, 8.0)
