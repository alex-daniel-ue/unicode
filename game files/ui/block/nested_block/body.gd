@tool
extends NinePatchRect


@export_custom(PROPERTY_HINT_NONE, "suffix:px") var minimum_height := 0.0

@onready var padding := patch_margin_top + patch_margin_bottom
@onready var mouth := $Mouth:
	get():
		if not mouth:
			mouth = find_child("Mouth", false, false)
		return mouth


func _ready() -> void:
	name = "Body"
	$LowerLip.custom_minimum_size.y = patch_margin_bottom
	mouth.position = Vector2(patch_margin_left, patch_margin_top)
	_on_mouth_resized()

func get_mouth_size() -> Vector2:
	return size - Vector2(patch_margin_left, patch_margin_bottom)

func _on_mouth_resized() -> void:
	custom_minimum_size.y = maxf(minimum_height, mouth.size.y) + padding
