extends PopupPanel
## Trash all's "are you sure?". Confirmed, it empties the canvas
## (connected to PuzzleCanvas.clear() in puzzle.tscn).

signal confirmed


func _on_ok_button_pressed() -> void:
	confirmed.emit()
	hide()
