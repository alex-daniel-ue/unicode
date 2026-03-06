extends PopupPanel


signal confirmed


func _on_ok_button_pressed() -> void:
	confirmed.emit()
	hide()
