@tool
class_name ListSlot
extends Node2D

## One cubby of a ListEntity's shelf: the cubby, the bag in it with its value
## printed on it, and the index on the rail underneath. ListEntity instances one
## per cubby and lays them out along the shelf; the art lives in this scene.
##
## When the level checks the list with a ListGoal, a cubby also shows what it
## should end up holding: a faded bag (Target) when it's empty, or the wanted
## value in its corner (Wanted) when it holds something else.
##
## Origin is the cubby's top-left corner, and the cubby is one tile wide.

@onready var cubby: Sprite2D = $Cubby
@onready var bag: Sprite2D = $Bag
@onready var value_label: Label = $Bag/Value
@onready var target: Sprite2D = $Target
@onready var target_label: Label = $Target/Value
@onready var wanted: Label = $Wanted
@onready var index_label: Label = $Index

## Where the bag sits when nothing is happening to it. Animations start from and
## return to this, so two that overlap can't leave a bag drifted.
var bag_rest: Vector2


func _ready() -> void:
	bag_rest = bag.position
