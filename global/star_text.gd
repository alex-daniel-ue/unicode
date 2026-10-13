class_name StarText
extends RefCounted

## Stars, drawn in the one font that has them. Neither game font has ★ or ☆, and
## Noto can't be a fallback on them: a fallback's taller line height spread to
## every label in the game. So a star is always its own Label, or its own span
## of rich text, set in Noto on purpose.
##
## Earned stars are yellow; the rest are black, with no outline. A yellow ☆ with
## a dark outline round it read as filled, so a level with one star looked like
## it had three.

const FONT := preload("res://puzzle/ui/themes/fonts/NotoSansSymbols2-Regular.ttf")
const FONT_PATH := "res://puzzle/ui/themes/fonts/NotoSansSymbols2-Regular.ttf"
const COLOR := Color(1.0, 0.82, 0.3)
const EMPTY_COLOR := Color(0.0, 0.0, 0.0)
const FILLED := "★"
const EMPTY := "☆"


## "★★☆" for 2 of 3.
static func of(stars: int, out_of := 3) -> String:
	return FILLED.repeat(stars) + EMPTY.repeat(maxi(out_of - stars, 0))

## A span of stars inside a RichTextLabel's BBCode.
static func bbcode(stars: String) -> String:
	return "[font=%s][color=#%s]%s[/color][/font]" % [FONT_PATH, COLOR.to_html(false), stars]

## Makes `label` a star label: Noto, yellow, at `size`.
static func style(label: Label, size: int) -> Label:
	label.add_theme_font_override(&"font", FONT)
	label.add_theme_font_size_override(&"font_size", size)
	label.add_theme_color_override(&"font_color", COLOR)
	label.add_theme_color_override(&"font_disabled_color", COLOR)
	return label

## A row of `out_of` stars, `stars` of them earned: see fill().
static func row(stars: int, size: int, rim := Color.TRANSPARENT, rim_size := 0, out_of := 3) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override(&"separation", 0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill(box, stars, size, rim, rim_size, out_of)
	return box

## Puts the stars into `box`: the earned ones yellow, with a `rim` outline when
## one is given, then the rest black and plain. Two labels, since a Label has
## one colour.
static func fill(box: HBoxContainer, stars: int, size: int, rim := Color.TRANSPARENT, rim_size := 0, out_of := 3) -> void:
	for old in box.get_children():
		box.remove_child(old)
		old.queue_free()
	stars = clampi(stars, 0, out_of)
	if stars > 0:
		var earned := style(Label.new(), size)
		earned.text = FILLED.repeat(stars)
		if rim_size > 0:
			earned.add_theme_color_override(&"font_outline_color", rim)
			earned.add_theme_constant_override(&"outline_size", rim_size)
		earned.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(earned)
	if stars < out_of:
		var missing := style(Label.new(), size)
		missing.text = FILLED.repeat(out_of - stars)
		missing.add_theme_color_override(&"font_color", EMPTY_COLOR)
		missing.add_theme_color_override(&"font_disabled_color", EMPTY_COLOR)
		missing.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(missing)
