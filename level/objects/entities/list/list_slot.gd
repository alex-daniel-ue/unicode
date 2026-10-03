@tool
class_name ListSlot
extends Node2D

## One box of a list's board: the box, the value card in it, and the index
## under it. ListEntity instances one per box and lays them out in a row; the
## look lives in this scene.
##
## When a ListGoal checks the list, a box also shows what it should end up
## holding: the value faded (Target) while the box is empty, or a small green
## badge in its corner (Wanted) while it holds something else.
##
## Origin is the box's top-left corner; the box is one tile wide.

@onready var cell: Panel = $Cell
@onready var card: Panel = $Card
@onready var value_label: Label = $Card/Value
@onready var target_label: Label = $Target
@onready var wanted: Panel = $Wanted
@onready var wanted_label: Label = $Wanted/Value
@onready var index_label: Label = $Index

## Where the card sits when nothing is happening to it. Animations start from and
## return to this, so two that overlap can't leave a card drifted.
var card_rest: Vector2


func _ready() -> void:
	card_rest = card.position
	card.pivot_offset = card.size / 2.0
