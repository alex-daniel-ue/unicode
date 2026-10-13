class_name Toolbox
extends MarginContainer

## The blocks a level gives the student, all in one scroll: the ones it
## introduces first, in a section of their own, then every category as a heading
## and a grid of tiles. A tab bar above the scroll names the categories.
##
## Tabs and scroll follow each other. Pressing a tab scrolls to its category;
## scrolling makes the category in view the selected tab. The selected category
## is lit and the rest are dimmed, so the eye has a place to start while every
## block stays in view to brainstorm with. Pointing at a block lights its
## category too.
##
## One scroll for everything, because on a short window the new blocks section
## used to push the tabs off the bottom, where they couldn't be reached.

const NEW_SECTION := preload("res://puzzle/ui/side panel/tabs/toolbox/toolbox_new_section.tscn")
## What each BlockData category is called on its tab. Short, because the tabs
## share one row in a narrow panel.
const DISPLAY := {
	"Robot": "Robot",
	"Lists": "Lists",
	"Iterative": "Loops",
	"Selection": "Selection",
	"Boolean": "Logic",
	"Value": "Math",
	"Generic": "Basics",
}
## How lit a category is when it isn't the selected one.
const DIMMED := 0.45
const DIM_TIME := 0.15
const SCROLL_TIME := 0.3
## A category counts as the one in view once its heading is this close to the
## top of the scroll.
const SPY_OFFSET := 48.0

@export var _internal_category_order: PackedStringArray
@export var category_scene: PackedScene
@export var new_holder: Container
@export var tabs: TabBar
@export var scroll: ScrollContainer
@export var sections: Container
@export var hint: Label

var _categories: Dictionary[String, ToolboxCategory] = {}
## The categories in tab order.
var _order: Array[ToolboxCategory] = []
var _current := -1
var _scroll_tween: Tween
var _scroll_target := -1
## Set while a tab press is scrolling, so the scroll doesn't pick a different tab
## on the way there, or when the last category is too short to reach the top.
var _pinned := false


func _ready() -> void:
	tabs.tab_clicked.connect(_on_tab_clicked)
	scroll.get_v_scroll_bar().value_changed.connect(_on_scrolled)
	_refresh_tabs()

func add_block(block: Block) -> void:
	var name_of := block.data.category
	var category: ToolboxCategory = _categories.get(name_of)
	if category == null:
		category = category_scene.instantiate() as ToolboxCategory
		category.category_name = name_of
		category.name = DISPLAY.get(name_of, name_of)
		category.title = category.name
		_categories[name_of] = category
		sections.add_child(category)
		category.pointed_at.connect(_on_category_pointed_at.bind(category))
	category.add_block(block)
	_sort()
	_refresh_tabs()

## Moves the blocks this level introduces into a section above the categories,
## each with its note. A category left with nothing in it goes away.
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
			sections.remove_child(category)
			category.queue_free()
	_sort()
	_refresh_tabs()

## Scrolls `block` into view and lights its category, so something pointing at
## it (a guide page) finds it on screen. Smooth, and safe to call every frame.
func reveal(block: Block) -> void:
	if not is_ancestor_of(block):
		return
	var top := _content_y(block)
	var bottom := top + block.size.y
	var view := scroll.size.y
	var at := float(scroll.scroll_vertical)
	if top >= at and bottom <= at + view:
		return
	var target := top - 16.0 if top < at else bottom - view + 16.0
	_scroll_to(int(target))
	for i in _order.size():
		if _order[i].is_ancestor_of(block):
			_pinned = true
			_select(i)

## The part of the screen the scroll shows: blocks outside it are scrolled away.
func visible_rect() -> Rect2:
	return scroll.get_global_rect()

#region Tabs and scrolling
func _sort() -> void:
	var order := func(a: ToolboxCategory, b: ToolboxCategory) -> bool:
		var a_idx := _internal_category_order.find(a.category_name)
		var b_idx := _internal_category_order.find(b.category_name)
		if a_idx == -1: a_idx = 99999
		if b_idx == -1: b_idx = 99999
		if a_idx == b_idx:
			return a.category_name < b.category_name
		return a_idx < b_idx
	_order.assign(_categories.values())
	_order.sort_custom(order)
	for i in _order.size():
		sections.move_child(_order[i], i)

func _refresh_tabs() -> void:
	tabs.clear_tabs()
	for category in _order:
		tabs.add_tab(category.title)
	tabs.visible = _order.size() > 1
	hint.visible = not _order.is_empty() or new_holder.get_child_count() > 0
	_current = -1
	if not _order.is_empty():
		_select(0)

## Selects tab `index` and lights its category, without scrolling.
func _select(index: int) -> void:
	index = clampi(index, 0, _order.size() - 1)
	if index == _current:
		return
	_current = index
	tabs.current_tab = index
	tabs.ensure_tab_visible(index)
	var dim := _order.size() > 1
	for i in _order.size():
		var lit := i == index or not dim
		_order[i].create_tween().tween_property(_order[i], "modulate:a", 1.0 if lit else DIMMED, DIM_TIME)

func _on_tab_clicked(index: int) -> void:
	if index < 0 or index >= _order.size():
		return
	_pinned = true
	_select(index)
	_scroll_to(int(_content_y(_order[index]) - 8.0))

func _on_category_pointed_at(category: ToolboxCategory) -> void:
	var index := _order.find(category)
	if index >= 0:
		_pinned = true  # until the next scroll by hand
		_select(index)

func _scroll_to(target: int) -> void:
	target = clampi(target, 0, maxi(int(scroll.get_v_scroll_bar().max_value - scroll.size.y), 0))
	if target == scroll.scroll_vertical or (_scroll_tween != null and _scroll_tween.is_running() and target == _scroll_target):
		return
	if _scroll_tween != null:
		_scroll_tween.kill()
	_scroll_target = target
	_scroll_tween = create_tween()
	_scroll_tween.tween_property(scroll, "scroll_vertical", target, SCROLL_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

## The scroll moved. By hand, the category now in view becomes the tab; while a
## tab press is scrolling, the pressed tab stays.
func _on_scrolled(_value: float) -> void:
	var scripted := _scroll_tween != null and _scroll_tween.is_running()
	if scripted and _pinned:
		return
	if not scripted:
		_pinned = false
	if _pinned or _order.is_empty():
		return
	var at := float(scroll.scroll_vertical)
	var view := scroll.size.y
	var most := maxf(scroll.get_v_scroll_bar().max_value - view, 1.0)
	# The line a category has to cross to be "the one in view" starts near the
	# top of the view and moves down it as the scroll nears its end. When the
	# list is short, the last categories never reach the top; this way each one
	# still gets its turn, and the very bottom is always the last one.
	var line := at + SPY_OFFSET + (view - SPY_OFFSET) * clampf(at / most, 0.0, 1.0)
	var index := 0
	for i in _order.size():
		if _content_y(_order[i]) <= line:
			index = i
	_select(index)

## Where `control` sits in the scroll's content, from its top.
func _content_y(control: Control) -> float:
	var content := scroll.get_child(0) as Control
	return control.get_global_rect().position.y - content.get_global_rect().position.y
#endregion
