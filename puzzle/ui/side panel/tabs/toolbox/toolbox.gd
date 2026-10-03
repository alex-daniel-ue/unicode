class_name Toolbox
extends MarginContainer

## The blocks a level gives the student: the ones it introduces in a section of
## their own at the top, always in view, and the rest in tabs by category, each
## a grid of tiles. One category shows its grid without a tab bar.
##
## Tabs rather than collapsible headings: a heading reading "v Lists" read as
## the word "Vlists", and nothing about it said it opened or closed.

const NEW_SECTION := preload("res://puzzle/ui/side panel/tabs/toolbox/toolbox_new_section.tscn")
## What each BlockData category is called on its tab. Short, because the tabs
## share one row in a narrow panel.
const DISPLAY := {
	"Robot": "Robot",
	"Lists": "Lists",
	"Iterative": "Loops",
	"Selection": "If",
	"Boolean": "Logic",
	"Value": "Math",
	"Generic": "Basics",
}
const SWITCH_FADE := 0.15

@export var _internal_category_order: PackedStringArray
@export var category_scene: PackedScene
@export var new_holder: Container
@export var tabs: TabContainer
@export var hint: Label

var _categories: Dictionary[String, ToolboxCategory] = {}


func _ready() -> void:
	tabs.tab_changed.connect(_on_tab_changed)
	_refresh_tabs()

func add_block(block: Block) -> void:
	var name_of := block.data.category
	var category: ToolboxCategory = _categories.get(name_of)
	if category == null:
		category = category_scene.instantiate() as ToolboxCategory
		category.category_name = name_of
		category.name = DISPLAY.get(name_of, name_of)
		_categories[name_of] = category
		tabs.add_child(category)
		_sort_tabs()
	category.add_block(block)
	_refresh_tabs()

## Moves the blocks this level introduces into a section above the tabs, each
## with its note. A tab left with nothing in it goes away.
func mark_new(new_blocks: Array[BlockData], notes: PackedStringArray) -> void:
	var section: ToolboxNewSection = null
	for i in new_blocks.size():
		var wanted := new_blocks[i]
		if wanted == null:
			continue
		for category: ToolboxCategory in _categories.values():
			var found: Block = null
			for block in category.get_blocks():
				if block.data.name == wanted.name:
					found = block
					break
			if found == null:
				continue
			if section == null:
				section = NEW_SECTION.instantiate() as ToolboxNewSection
				new_holder.add_child(section)
			var tile := category.tile_of(found)
			section.add_entry(found, notes[i] if i < notes.size() else "")
			if tile != null:
				tile.queue_free()
			break

	for key: String in _categories.keys():
		var category := _categories[key]
		if category.is_empty():
			_categories.erase(key)
			tabs.remove_child(category)
			category.queue_free()
	_refresh_tabs()
	# The first tab in the order (the robot's, when there is a robot), not
	# whichever category happened to arrive first.
	if tabs.get_tab_count() > 0:
		tabs.current_tab = 0

## Opens the tab holding `block`, so something pointing at it (a guide page)
## finds it on screen. Does nothing for a block in the new section.
func reveal(block: Block) -> void:
	for category: ToolboxCategory in _categories.values():
		if category.is_ancestor_of(block) and tabs.current_tab != category.get_index():
			tabs.current_tab = category.get_index()
			return

func _sort_tabs() -> void:
	var order := func(a: ToolboxCategory, b: ToolboxCategory) -> bool:
		var a_idx := _internal_category_order.find(a.category_name)
		var b_idx := _internal_category_order.find(b.category_name)
		if a_idx == -1: a_idx = 99999
		if b_idx == -1: b_idx = 99999
		if a_idx == b_idx:
			return a.category_name < b.category_name
		return a_idx < b_idx
	var sorted: Array = _categories.values()
	sorted.sort_custom(order)
	for i in sorted.size():
		tabs.move_child(sorted[i], i)

func _refresh_tabs() -> void:
	tabs.tabs_visible = _categories.size() > 1
	tabs.visible = not _categories.is_empty()
	hint.visible = not _categories.is_empty() or new_holder.get_child_count() > 0

func _on_tab_changed(index: int) -> void:
	var page := tabs.get_tab_control(index)
	if page == null:
		return
	page.modulate.a = 0.0
	create_tween().tween_property(page, "modulate:a", 1.0, SWITCH_FADE)
