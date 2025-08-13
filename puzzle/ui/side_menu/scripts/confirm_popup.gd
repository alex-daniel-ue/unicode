extends PopupPanel


signal confirmed

@onready var label := $MarginContainer/VBoxContainer/Label

func _ready() -> void:
	set_deferred("size", Vector2.ZERO)

func set_text(text: String) -> void:
	label.text = text

func _on_yes_button_pressed() -> void:
	confirmed.emit()
	hide()
