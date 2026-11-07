extends BlockDragComponent
## The cap block's drag: a Begin block can't be copied.


func _ready() -> void:
	assert(base is CapBlock)


func can_copy(event: InputEvent) -> bool:
	return not (base as CapBlock).is_type(NestedData.Type.BEGIN) and super(event)
