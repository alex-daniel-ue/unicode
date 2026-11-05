class_name ToolboxTile
extends PanelContainer
## The tile one toolbox block sits on, so the toolbox reads as a grid of things
## to pick up rather than a column of text. Lights up under the pointer.
##
## A small eye in its corner shows the block's note under it: what the block
## does, in a sentence, for a block whose guide page was levels ago.

const HOVER := Color(1.35, 1.35, 1.45)
const FADE := 0.12
## The eye, dim while the note is hidden and lit while it shows.
const EYE_SHUT := Color(1, 1, 1, 0.4)
const EYE_OPEN := Color(1.0, 0.82, 0.3)

@export var holder: Container
@export var eye: TextureButton
@export var note: Label

var _tween: Tween


func _ready() -> void:
	eye.toggled.connect(_show_note)
	_show_note(eye.button_pressed)


## Puts `block` on this tile; one already somewhere else (on another tile) moves.
## `text` is the note under it, the block's own note when empty; `open` shows
## it from the start.
func hold(block: Block, text := "", open := false) -> void:
	if block.get_parent() != null:
		block.reparent(holder)
	else:
		holder.add_child(block)
	block.mouse_entered.connect(_light.bind(true))
	block.mouse_exited.connect(_light.bind(false))
	note.text = text if not text.is_empty() else block.data.note
	eye.visible = not note.text.is_empty()
	eye.set_pressed_no_signal(open and eye.visible)
	_show_note(eye.button_pressed)


func block() -> Block:
	for child in holder.get_children():
		if child is Block:
			return child as Block
	return null


func _show_note(open: bool) -> void:
	note.visible = open and not note.text.is_empty()
	eye.self_modulate = EYE_OPEN if open else EYE_SHUT
	eye.tooltip_text = "Hide what this block does." if open else "Show what this block does."


func _light(on: bool) -> void:
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "self_modulate", HOVER if on else Color.WHITE, FADE)
