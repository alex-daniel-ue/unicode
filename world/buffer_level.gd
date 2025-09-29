extends Interactable


@export var scene: PackedScene


func interact() -> void:
	Game.pending_level = scene
	Game.start_puzzle()
