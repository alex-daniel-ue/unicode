class_name ProgressDialog
extends PopupPanel

## Everything about progress codes in one place: showing the current one,
## copying it, and typing one in. Level select used to carry all of this in its
## footer, which put three controls about save data next to ten about levels.

@export var code_label: Label
@export var copy_button: Button
@export var import_edit: LineEdit
@export var feedback: Label

func _ready() -> void:
	about_to_popup.connect(_refresh)

func _refresh() -> void:
	code_label.text = Progress.get_code()
	copy_button.text = "Copy"
	copy_button.disabled = Progress.total_stars() == 0
	feedback.text = ""
	import_edit.clear()
	import_edit.grab_focus()

func _on_copy_pressed() -> void:
	DisplayServer.clipboard_set(Progress.get_code())
	copy_button.text = "Copied"

## Says so when a code is rejected. Doing nothing silently is the worst outcome
## for someone who has just typed ten characters off a piece of paper.
func _on_import_pressed() -> void:
	var code := import_edit.text.strip_edges()
	if code.is_empty():
		feedback.text = "Type your code first."
		return
	if not Progress.apply_code(code):
		feedback.text = "That code isn't readable. Check for a mistyped character."
		return
	feedback.text = "Imported. Your stars are up to date."
	import_edit.clear()
	code_label.text = Progress.get_code()
