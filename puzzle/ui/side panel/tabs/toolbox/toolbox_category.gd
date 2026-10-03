class_name ToolboxCategory
extends ScrollContainer

## One tab of the toolbox: a grid of tiles, one block on each.

const TILE := preload("res://puzzle/ui/side panel/tabs/toolbox/toolbox_tile.tscn")

@export var container: Container

## The BlockData category this tab holds ("Iterative"); the tab's title is the
## friendlier Toolbox.DISPLAY name for it.
var category_name := ""


func add_block(block: Block) -> void:
	var tile := TILE.instantiate() as ToolboxTile
	container.add_child(tile)
	tile.hold(block)

func get_blocks() -> Array[Block]:
	var blocks: Array[Block] = []
	for tile in container.get_children():
		if tile is ToolboxTile and (tile as ToolboxTile).block() != null:
			blocks.append((tile as ToolboxTile).block())
	return blocks

## The tile `block` sits on, so it can be dropped once the block has moved on
## (to the new blocks section).
func tile_of(block: Block) -> ToolboxTile:
	for tile in container.get_children():
		if tile is ToolboxTile and (tile as ToolboxTile).block() == block:
			return tile as ToolboxTile
	return null

func is_empty() -> bool:
	return get_blocks().is_empty()
