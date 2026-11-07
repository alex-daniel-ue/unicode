class_name ToolboxNewSection
extends VBoxContainer
## The top of the toolbox when a level brings in new blocks: each new block with
## one short line about what it does. The toolbox is where a student goes for
## blocks, so this is where a new one is explained, instead of in a level brief
## that, opened first thing, read as a wall of text.

const TILE := preload("res://puzzle/ui/side panel/tabs/toolbox/toolbox_tile.tscn")

@export var entries: Container
## Copied per block: a holder the block's tile goes in.
@export var entry_template: Control


func _ready() -> void:
	entry_template.visible = false


## Moves `block` (already a toolbox block, draggable as ever) into the section,
## on a tile like the rest of the toolbox's, so it reads as something to pick up
## too and not as a picture of one. Its note shows from the start here; the eye
## on the tile hides it, as it shows it everywhere else.
func add_entry(block: Block, note: String) -> void:
	var entry := entry_template.duplicate() as Control
	entries.add_child(entry)
	entry.visible = true
	var tile := TILE.instantiate() as ToolboxTile
	entry.get_node(^"Holder").add_child(tile)
	tile.hold(block, note, true)
