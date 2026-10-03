class_name ListGraphic
extends Control

## A guide picture built around a real list board, so the picture looks exactly
## like the boards in the rooms. Sets the board up from these when it's shown:
## a goal to show on it, positions the "program" has written, and a box to
## outline.

@export var list: ListEntity
@export var target: Array = []
## Positions shown as written by the program, so they're marked right or wrong.
@export var written: Array = []
@export var highlight := -1


func _ready() -> void:
	if list == null:
		return
	if not target.is_empty() or not written.is_empty():
		list.show_example(list.values, target, written)
	if highlight >= 0:
		list.point_at(highlight)
