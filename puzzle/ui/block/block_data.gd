class_name BlockData
extends Resource


signal text_changed

@export var block_name := "Block"
@export_file("*.tscn") var base_block_path: String

@export_group("Block")
@export var toolbox := true
@export var draggable := true
@export var placeable := true
@export var top_notch := true
@export var bottom_notch := true

@export_group("Text")
@export var text := "":
	set(value):
		text = value
		text_changed.emit()
## See [method Block.format_text].
@export var text_data: Array[BlockData]
