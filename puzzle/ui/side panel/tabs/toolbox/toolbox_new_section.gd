class_name ToolboxNewSection
extends VBoxContainer

## The top of the toolbox when a level brings in new blocks: each new block with
## one short line about what it does. The toolbox is where a student goes for
## blocks, so this is where a new one is explained, instead of in a level brief
## that, opened first thing, read as a wall of text.

## Keeps Toolbox.sort_categories() happy; this section always sorts first.
var category_name := ""

@export var entries: Container
## Copied per block: a holder the block moves into, and the note under it.
@export var entry_template: Control


func _ready() -> void:
	entry_template.visible = false

## Moves `block` (already a toolbox block, draggable as ever) into the section.
func add_entry(block: Block, note: String) -> void:
	var entry := entry_template.duplicate() as Control
	entries.add_child(entry)
	entry.visible = true
	block.reparent(entry.get_node(^"Holder"))
	var note_label := entry.get_node(^"Note") as Label
	note_label.text = note
	note_label.visible = not note.is_empty()
