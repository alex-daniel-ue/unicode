class_name ToolboxTile
extends PanelContainer

## The tile one toolbox block sits on, so the toolbox reads as a grid of things
## to pick up rather than a column of text. Lights up under the pointer.

const HOVER := Color(1.35, 1.35, 1.45)
const FADE := 0.12

@export var holder: Container

var _tween: Tween


func hold(block: Block) -> void:
	holder.add_child(block)
	block.mouse_entered.connect(_light.bind(true))
	block.mouse_exited.connect(_light.bind(false))

func block() -> Block:
	for child in holder.get_children():
		if child is Block:
			return child as Block
	return null

func _light(on: bool) -> void:
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "self_modulate", HOVER if on else Color.WHITE, FADE)
