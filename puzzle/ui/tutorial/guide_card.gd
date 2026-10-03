class_name GuideCard
extends PanelContainer

## The card a guide page is shown on: a title, a picture, a line or two of text
## and the button that moves on. TutorialOverlay fills it per page; the look is
## all in guide_card.tscn.
##
## The picture comes first and is the biggest thing on the card, because the
## words are the part most likely to be skipped.

signal next_pressed

@export var title_label: Label
@export var graphic_holder: Container
@export var body_label: Label
@export var page_label: Label
@export var next_button: Button


func _ready() -> void:
	next_button.pressed.connect(next_pressed.emit)

## `waits` is true when the page moves on by itself (a block placed, a button
## pressed), so the card says what to do instead of offering Next.
func show_page(page: Dictionary, index: int, count: int, waits: bool) -> void:
	title_label.text = page.get("title", "")
	title_label.visible = not title_label.text.is_empty()
	body_label.text = page.get("text", "")
	body_label.visible = not body_label.text.is_empty()
	page_label.text = "%d / %d" % [index + 1, count] if count > 1 else ""

	for old in graphic_holder.get_children():
		old.queue_free()
	var graphic := _graphic(page)
	graphic_holder.visible = graphic != null
	if graphic != null:
		graphic_holder.add_child(graphic)

	next_button.visible = not waits
	var last := index == count - 1
	next_button.text = page.get("button", "Done" if last else "Next")
	reset_size()
	UiMotion.fade_in(get_node(^"Margin"), 0.15)

func _graphic(page: Dictionary) -> Control:
	if page.has("block"):
		var block_data: Variant = page.block
		if block_data is String:
			block_data = load(block_data)
		var picture := BlockPicture.new()
		picture.data = block_data as BlockData
		picture.values = PackedStringArray(page.get("block_values", []))
		return picture
	var path: String = page.get("graphic", "")
	if path.is_empty():
		return null
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
