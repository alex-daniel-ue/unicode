class_name ProgressDialog
extends PopupPanel

## Everything about progress codes in one place: showing the current one,
## copying it, and typing one in. Opened from the main menu's Progress button.
##
## Every signal is connected in progress_dialog.tscn. The scene root must stay
## `visible = false`: a Window saved visible pops up the moment its parent scene
## enters the tree, which put this dialog over the main menu at every launch.

@export var code_label: Label
@export var copy_button: Button
@export var import_edit: LineEdit
@export var import_button: Button
@export var feedback: Label

func _ready() -> void:
	about_to_popup.connect(_refresh)

func _refresh() -> void:
	code_label.text = Progress.get_code()
	var has_stars := Progress.total_stars() > 0
	copy_button.text = "Copy"
	copy_button.disabled = not has_stars
	copy_button.tooltip_text = "" if has_stars else "Finish a level first; there's nothing to copy yet."
	feedback.text = ""
	import_edit.clear()
	# The popup isn't visible yet while about_to_popup runs.
	import_edit.call_deferred(&"grab_focus")

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
	_refresh_code()

func _refresh_code() -> void:
	code_label.text = Progress.get_code()
	copy_button.disabled = Progress.total_stars() == 0
	copy_button.text = "Copy"
