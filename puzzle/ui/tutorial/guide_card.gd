class_name GuideCard
extends PanelContainer

## The card a guide page is shown on: a title, a picture, a line or two of text
## and the buttons that move between pages. TutorialOverlay fills it per page;
## the look is all in guide_card.tscn.
##
## The picture comes first and is the biggest thing on the card, because the
## words are the part most likely to be skipped.

signal next_pressed
signal back_pressed

const VIDEO_SIZE := Vector2(336, 184)
const VIDEO_FRAME := Color(0.3, 0.33, 0.45)

@export var title_label: Label
@export var graphic_holder: Container
@export var body_label: Label
@export var page_label: Label
@export var next_button: Button
@export var back_button: Button


func _ready() -> void:
	next_button.pressed.connect(next_pressed.emit)
	back_button.pressed.connect(back_pressed.emit)

## `waits` is true when the page moves on by itself (a block placed, a button
## pressed), so the card says what to do instead of offering Next. `can_go_back`
## shows Back, to look at the pages before this one again.
func show_page(page: Dictionary, index: int, count: int, waits: bool, can_go_back := false) -> void:
	title_label.text = page.get("title", "")
	title_label.visible = not title_label.text.is_empty()
	body_label.text = page.get("text", "")
	body_label.visible = not body_label.text.is_empty()
	page_label.text = "%d / %d" % [index + 1, count] if count > 1 else ""

	for old in graphic_holder.get_children():
		graphic_holder.remove_child(old)
		old.queue_free()
	var graphics := _graphics(page)
	graphic_holder.visible = not graphics.is_empty()
	for graphic in graphics:
		graphic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		graphic_holder.add_child(graphic)

	next_button.visible = not waits
	back_button.visible = can_go_back
	var last := index == count - 1
	next_button.text = page.get("button", "Done" if last else "Next")
	reset_size()
	UiMotion.fade_in(get_node(^"Margin"), 0.15)

## What the page shows above its words, top to bottom: a picture of what a block
## does, a video, an image or scene, a small program, and last the block itself.
func _graphics(page: Dictionary) -> Array[Control]:
	var shown: Array[Control] = []
	if page.has("picture"):
		var picture := GuideGraphics.build(page.picture)
		if picture != null:
			shown.append(picture)
	if page.has("video"):
		shown.append(_video(page.video))
	var path: String = page.get("graphic", "")
	if not path.is_empty():
		var graphic := _loaded_graphic(page, path)
		if graphic != null:
			shown.append(graphic)
	if page.has("program"):
		var program := BlockPicture.new()
		program.program = page.program
		shown.append(program)
	if page.has("block"):
		var block_data: Variant = page.block
		if block_data is String:
			block_data = load(block_data)
		var picture := BlockPicture.new()
		picture.data = block_data as BlockData
		picture.values = PackedStringArray(page.get("block_values", []))
		shown.append(picture)
	return shown

func _loaded_graphic(page: Dictionary, path: String) -> Control:
	var resource := load(path)
	if resource is PackedScene:
		return _zoomed((resource as PackedScene).instantiate() as Control)
	if resource is Texture2D:
		var image := TextureRect.new()
		image.texture = resource
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		return image
	push_warning("Guide page '%s': graphic '%s' is neither a scene nor an image." % [page.get("title", ""), path])
	return null

## A short silent clip that loops, in a thin frame.
func _video(path: String) -> Control:
	var frame := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0, 0, 0, 0)
	box.border_color = VIDEO_FRAME
	box.set_border_width_all(2)
	box.set_corner_radius_all(4)
	box.set_content_margin_all(2)
	frame.add_theme_stylebox_override(&"panel", box)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var player := VideoStreamPlayer.new()
	player.stream = load(path) as VideoStream
	player.custom_minimum_size = VIDEO_SIZE
	player.expand = true
	player.loop = true
	player.autoplay = true
	player.volume_db = -80.0
	player.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(player)
	return frame

## A picture drawn small (a board at the size it is in the room) can ask to be
## shown bigger with a "scale" metadata entry on its root: 2 doubles it. Whole
## numbers keep the pixel fonts crisp.
func _zoomed(graphic: Control) -> Control:
	var k: float = graphic.get_meta(&"scale", 1.0)
	if is_equal_approx(k, 1.0):
		return graphic
	var frame := Control.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.custom_minimum_size = graphic.custom_minimum_size * k
	graphic.scale = Vector2(k, k)
	frame.add_child(graphic)
	return frame
