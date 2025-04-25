class_name NestedBlock
extends Block


var preview_node: Block
var initial_min_size: Vector2

@onready var _texture := $NinePatchRect
@onready var _statement_container: VBoxContainer = $StatementContainer


func _ready() -> void:
	initial_min_size = custom_minimum_size
	_update_height_inside()
	_statement_container.minimum_size_changed.connect(_update_height_inside)

func _update_height_inside() -> void:
	custom_minimum_size.y = _statement_container.size.y + _texture.custom_minimum_size.y
	custom_minimum_size.y = max(custom_minimum_size.y, initial_min_size.y)
	
	size.y = custom_minimum_size.y



## Overrides [method Block._get_center_drag_position].
func _get_center_drag_position() -> Vector2:
	return -0.5 * Vector2(size.x, _texture.patch_margin_top)


## Adds a preview of any potential data ([Statement]s, [NestedBlock]s, etc.)
func _preview_drop_data():
	pass
func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	# TODO: Add preview functionality, where the to-be-dropped data is previewed
	# right before it's dropped. If it's not, then remove the preview
	return data is Block
func _drop_data(_at_position: Vector2, data: Variant) -> void:
	_statement_container.add_child(data)
