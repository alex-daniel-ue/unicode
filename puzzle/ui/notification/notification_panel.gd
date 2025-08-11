extends PanelContainer


@export var label: Label
var duration: float


func _ready() -> void:
	await get_tree().create_timer(duration / 2.).timeout
	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUART)
	tween.tween_property(self, "modulate", Color("#FFF", 0), duration / 2.)
	get_tree().create_timer(duration / 2.).timeout.connect(queue_free)

func set_text(text: String) -> void:
	label.text = '\n' + text
