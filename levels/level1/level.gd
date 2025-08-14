extends BaseLevel


@export var litter_layer: TileMapLayer


func _ready() -> void:
	for litter in litter_layer.get_children():
		litter.picked_up.connect(func() -> void:
			goal_checker.collected += 1
		)
