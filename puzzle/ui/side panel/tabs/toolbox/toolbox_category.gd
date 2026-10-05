class_name ToolboxCategory
extends VBoxContainer

## One category of the toolbox: its name, then a grid of tiles, one block on each.

## The pointer is on one of this category's blocks.
signal pointed_at

const TILE := preload("res://puzzle/ui/side panel/tabs/toolbox/toolbox_tile.tscn")

@export var container: Container
@export var heading: Label

## The BlockData category this holds ("Iterative"); `title` is the friendlier
## Toolbox.DISPLAY name, shown on its tab and its heading.
var category_name := ""
var title := "":
	set(value):
		title = value
		if heading != null:
			heading.text = value


func _ready() -> void:
	heading.text = title

func add_block(block: Block) -> void:
	var tile := TILE.instantiate() as ToolboxTile
	container.add_child(tile)
	tile.hold(block)
	block.mouse_entered.connect(pointed_at.emit)

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
