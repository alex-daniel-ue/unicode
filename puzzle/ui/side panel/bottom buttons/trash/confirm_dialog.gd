extends PopupPanel


signal confirmed

func _ready() -> void:
	set_deferred("size", Vector2.ZERO)

func _on_ok_button_pressed() -> void:
	confirmed.emit()
	hide()
