extends Button

signal contents_visibility_requested(contents: Control)

@export var associated_contents: Control

func _ready() -> void:
	pressed.connect(contents_visibility_requested.emit.bind(associated_contents))
