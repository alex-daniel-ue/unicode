extends BlockDragComponent


func _ready() -> void:
	assert(base is CapBlock)

func is_copy_valid(event: InputEvent) -> bool:
	# Explicit type conversion
	var cap := base as CapBlock
	
	return (
		not cap.is_type(NestedData.Type.BEGIN) and
		super(event)
	)
