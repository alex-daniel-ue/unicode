class_name NestedBlock
extends Block


@onready var body := $Body:
	get():
		if not body:
			body = find_child("Body", false, false)
		return body


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Block and block_type == BlockType.REGULAR
