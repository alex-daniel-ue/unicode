@tool
class_name ListSlot
extends Node2D

## One box of a list's board: the box, the value card in it, and the index
## under it. ListEntity instances one per box and lays them out in a row; the
## look lives in this scene.
##
## When a ListGoal checks the list, a box also shows what it should end up
## holding, as a small green badge in its corner (Wanted), whether the box is
## empty or holds something else. The badge reaches over the next box, so it
## draws above the boxes (z_index 1). A faded value in an empty box used to show
## it, and read as a value already there that couldn't be changed.
##
## Origin is the box's top-left corner; the box is one tile wide.

@onready var cell: Panel = $Cell
@onready var card: Panel = $Card
@onready var value_label: Label = $Card/Value
@onready var wanted: Panel = $Wanted
@onready var wanted_label: Label = $Wanted/Value
@onready var index_label: Label = $Index

## Where the card sits when nothing is happening to it. Animations start from and
## return to this, so two that overlap can't leave a card drifted.
var card_rest: Vector2


func _ready() -> void:
	card_rest = card.position
	card.pivot_offset = card.size / 2.0
