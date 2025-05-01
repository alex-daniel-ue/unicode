class_name NestedBlock
extends Block


var initial_min_size: Vector2

@onready var lower_lip := $LowerLip
@onready var mouth: VBoxContainer = $Mouth:
	get():
		if not mouth:
			mouth = find_child("Mouth", true, false)
		return mouth


func _init() -> void:
	mouth = find_child("Mouth", true, false)

func _ready() -> void:
	initial_min_size = custom_minimum_size
	lower_lip.custom_minimum_size.y = texture.patch_margin_bottom
	mouth.position = Vector2(texture.patch_margin_left, texture.patch_margin_top)
	
	update_height()
	# Sometmies VBoxContainer.size doesn't reset to zero when it has no children
	mouth.size = Vector2.ZERO
	# minimum_size_changed must be connected AFTER setting size to Vector2.ZERO
	mouth.minimum_size_changed.connect(update_height)

func update_height() -> void:
	custom_minimum_size.y = max(mouth.size.y + texture.custom_minimum_size.y, initial_min_size.y)
	size.y = custom_minimum_size.y

func _on_child_entered_mouth(child: Node) -> void:
	Util.log("%s entered %s" % [child, self])
	child.size_flags_horizontal = SIZE_SHRINK_BEGIN

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Block and not is_infinite
