class_name LevelDescription
extends Node

## The level's instructions, shown in the Information tab and sent to the
## assistant as the level text.
##
## Two ways to author it:
##
## 1. The brief (preferred). Fill the "Brief" fields in the inspector and the
##    panel is built from them in one consistent style: a mission card, one row
##    per room, the twist, a card per new block, a tip, and the star target
##    computed from par, so it can never drift. Nothing to lay out per level.
## 2. Controls. Any Labels, TextureRects, inert Blocks or containers added as
##    children are shown too, after the brief. Use this for pictures.

const ACCENT := Color(1.0, 0.82, 0.3)       # the tutorial ring colour: "this matters"
const TWIST := Color(1.0, 0.5, 0.38)
const MUTED := Color(0.78, 0.8, 0.88)
const CARD_BG := Color(1, 1, 1, 0.06)
const BLOCK_BG := Color(0, 0, 0, 0.28)
const BODY_SIZE := 20
const CAPTION_SIZE := 16
const EXAMPLE_TOOLTIP := "This is a picture of the block.\nDrag the real one from the Toolbox."

@export_group("Brief")
@export var title := ""
## What the player is trying to do here, in one or two sentences. Say how many
## rooms the program runs in.
@export_multiline var mission := ""
## One line per room, shown as numbered rows. Leave empty for one-room levels.
@export var rooms: PackedStringArray = []
## The constraint that makes this level this level: "But there's no else block."
@export_multiline var twist := ""
## Blocks introduced here, each shown as an inert picture on its own card.
@export var blocks: Array[BlockData] = []
## One note per entry in `blocks`: a sentence about the block in this level, then
## one about what it does in general.
@export var block_notes: PackedStringArray = []
## Optional, one per entry in `blocks`: what the picture's slots show, comma
## separated ("puddle" makes it read "ahead is puddle"). Empty keeps the default.
@export var block_values: PackedStringArray = []
@export_multiline var tip := ""
## Off for worked examples, where the preset is the whole program.
@export var show_stars := true

## Populated by take_content(). Puzzle reparents these into the side panel, so
## after that point this node is childless and get_raw() has to walk the handed-
## over Controls instead of get_children().
var content: Array[Control]


func _enter_tree() -> void:
	_prepare(self, false)

func has_brief() -> bool:
	return not (title.is_empty() and mission.is_empty() and twist.is_empty() and blocks.is_empty())

func take_content() -> Array[Control]:
	content.clear()
	
	if has_brief():
		content.append(_build_brief())
	
	for child in get_children():
		if child is Control:
			_prepare(child, true)
			child.visible = true
			content.append(child as Control)
	
	return content

func get_raw() -> String:
	var lines: PackedStringArray
	var roots := _roots()
	if roots.is_empty() and has_brief():
		return _brief_text()
	for node in roots:
		lines.append_array(_collect_raw(node))
	return "\n".join(lines)

## Mirrors _prepare()'s walk. Without the recursion, wrapping instruction copy in
## a VBox or HBox for layout silently removes it from the assistant's context.
func _collect_raw(node: Node) -> PackedStringArray:
	var lines: PackedStringArray
	
	if node is CanvasItem and not (node as CanvasItem).visible:
		return lines
	
	# Leaves. A Block renders its own parameter blocks into its raw text, so
	# don't descend into one.
	if node is Block:
		lines.append((node as Block).text.get_raw())
		return lines
	if node is Label:
		lines.append((node as Label).text)
		return lines
	if node is RichTextLabel:
		lines.append((node as RichTextLabel).get_parsed_text())
		return lines
	
	for child in node.get_children():
		lines.append_array(_collect_raw(child))
	return lines

func _roots() -> Array[Node]:
	var roots: Array[Node]
	for node in content:
		if is_instance_valid(node):
			roots.append(node)
	return roots if not roots.is_empty() else get_children()

func _prepare(node: Node, sanitize: bool) -> void:
	if node is Block:
		var block := node as Block
		block.display = true
		if sanitize:
			block.mouse_filter = Control.MOUSE_FILTER_IGNORE
			block.focus_mode = Control.FOCUS_NONE
	
	for child in node.get_children():
		_prepare(child, sanitize)

#region The brief
## The same text the panel shows, for the assistant and the lint, before any
## Controls exist.
func _brief_text() -> String:
	var lines: PackedStringArray = []
	if not title.is_empty(): lines.append(title)
	if not mission.is_empty(): lines.append("Mission: " + mission)
	for i in rooms.size():
		lines.append("Room %d: %s" % [i + 1, rooms[i]])
	if not twist.is_empty(): lines.append("Twist: " + twist)
	for i in blocks.size():
		if blocks[i] != null:
			lines.append("%s: %s" % [blocks[i].text.replace("{}", "...").replace("\\n", " "), _note(i)])
	if not tip.is_empty(): lines.append(tip)
	var stars := _star_line()
	if not stars.is_empty(): lines.append(stars)
	return "\n".join(lines)

func _build_brief() -> Control:
	var root := VBoxContainer.new()
	root.name = "Brief"
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override(&"separation", 14)
	
	if not title.is_empty():
		var heading := Label.new()
		heading.theme_type_variation = &"HeaderMedium"
		heading.text = title
		heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		root.add_child(heading)
	
	if not mission.is_empty():
		var card := _card(CARD_BG, ACCENT)
		var stack := _stack(card)
		stack.add_child(_caption("YOUR MISSION", ACCENT))
		stack.add_child(_body(mission))
		root.add_child(card)
	
	if not rooms.is_empty():
		var list := VBoxContainer.new()
		list.add_theme_constant_override(&"separation", 6)
		for i in rooms.size():
			list.add_child(_room_row(i + 1, rooms[i]))
		root.add_child(list)
	
	if not twist.is_empty():
		var card := _card(Color(TWIST, 0.1), TWIST)
		var stack := _stack(card)
		stack.add_child(_caption("THE TWIST", TWIST))
		stack.add_child(_body(twist))
		root.add_child(card)
	
	var shown := blocks.filter(func(b: BlockData) -> bool: return b != null)
	if not shown.is_empty():
		root.add_child(_caption("NEW BLOCKS" if shown.size() > 1 else "NEW BLOCK", MUTED))
		for i in blocks.size():
			if blocks[i] != null:
				root.add_child(_block_card(blocks[i], _note(i), i))
	
	if not tip.is_empty():
		var tip_label := _body(tip)
		tip_label.modulate = MUTED
		root.add_child(tip_label)
	
	var stars := _star_line()
	if not stars.is_empty():
		var badge := _card(Color(ACCENT, 0.12), Color(ACCENT, 0.0))
		var label := _body(stars)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_color_override(&"font_color", ACCENT)
		badge.add_child(label)
		root.add_child(badge)
	
	return root

func _note(index: int) -> String:
	return block_notes[index] if index < block_notes.size() else ""

func _star_line() -> String:
	var level := get_parent() as Level
	if not show_stars or level == null or Engine.is_editor_hint():
		return ""
	var par := level.get_star_par()
	return "★★★  %d block%s or fewer" % [par, "" if par == 1 else "s"]

func _card(bg: Color, border: Color) -> PanelContainer:
	var card := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.border_width_left = 4 if border.a > 0.0 else 0
	box.set_corner_radius_all(8)
	box.content_margin_left = 14
	box.content_margin_right = 12
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	card.add_theme_stylebox_override(&"panel", box)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return card

func _stack(card: PanelContainer) -> VBoxContainer:
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override(&"separation", 4)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(stack)
	return stack

func _caption(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = &"BlockLabel"   # Kenney Mini
	label.add_theme_font_size_override(&"font_size", CAPTION_SIZE)
	label.add_theme_color_override(&"font_color", color)
	return label

func _body(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = &"LegibleLabel"
	label.add_theme_font_size_override(&"font_size", BODY_SIZE)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _room_row(number: int, text: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 10)
	var badge := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(ACCENT, 0.9)
	box.set_corner_radius_all(6)
	box.content_margin_left = 8
	box.content_margin_right = 8
	box.content_margin_top = 2
	box.content_margin_bottom = 2
	badge.add_theme_stylebox_override(&"panel", box)
	badge.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var num := Label.new()
	num.text = "Room %d" % number
	num.theme_type_variation = &"BlockLabel"
	num.add_theme_font_size_override(&"font_size", CAPTION_SIZE)
	badge.add_child(num)
	row.add_child(badge)
	row.add_child(_body(text))
	return row

## An inert block on a card that looks like a specimen rather than a palette:
## the Toolbox is where blocks are dragged from, so the card answers a drag
## attempt with the "not allowed" cursor and a tooltip saying where to go.
func _block_card(data: BlockData, note: String, index: int) -> Control:
	var card := _card(BLOCK_BG, Color(1, 1, 1, 0.0))
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN
	card.tooltip_text = EXAMPLE_TOOLTIP
	var stack := _stack(card)
	stack.add_theme_constant_override(&"separation", 8)
	
	var shown := data
	var values := block_values[index].split(",", false) if index < block_values.size() else PackedStringArray()
	if not values.is_empty():
		shown = data.deep_copy()
		for i in mini(values.size(), shown.text_blocks.size()):
			shown.text_blocks[i].text = values[i].strip_edges()
	var block := Block.construct(shown)
	block.display = true
	block.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	stack.add_child(block)
	if not note.is_empty():
		stack.add_child(_body(note))
	
	# format() rebuilds a block's sockets in its own _ready(), so the controls to
	# silence only exist once the card is ready.
	card.ready.connect(_silence.bind(card), CONNECT_ONE_SHOT)
	return card

func _silence(card: Control) -> void:
	for node in card.find_children("*", "Control", true, false):
		var control := node as Control
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE
		control.focus_mode = Control.FOCUS_NONE
#endregion
