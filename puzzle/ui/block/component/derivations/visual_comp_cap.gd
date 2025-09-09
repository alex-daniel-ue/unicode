extends BlockVisualComponent


@export var lower_lip: Control

var _default_lip_height: float


func _ready() -> void:
	super()
	if lower_lip:
		_default_lip_height = lower_lip.custom_minimum_size.y

func start_drag_feedback(dragged_block: Block) -> void:
	if lower_lip and is_instance_valid(dragged_block):
		lower_lip.custom_minimum_size.y = dragged_block.size.y / 2.0

func stop_drag_feedback() -> void:
	if lower_lip:
		lower_lip.custom_minimum_size.y = _default_lip_height
