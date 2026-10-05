class_name StarText
extends RefCounted

## Stars, drawn in the one font that has them. Neither game font has ★ or ☆, and
## Noto can't be a fallback on them: a fallback's taller line height spread to
## every label in the game. So a star is always its own Label, or its own span
## of rich text, set in Noto on purpose.
##
## Always yellow, the empty ones too. Grey outlines next to yellow ones read as
## "mostly empty" to anyone who hadn't seen an empty set yet.

const FONT := preload("res://puzzle/ui/themes/fonts/NotoSansSymbols2-Regular.ttf")
const FONT_PATH := "res://puzzle/ui/themes/fonts/NotoSansSymbols2-Regular.ttf"
const COLOR := Color(1.0, 0.82, 0.3)
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
