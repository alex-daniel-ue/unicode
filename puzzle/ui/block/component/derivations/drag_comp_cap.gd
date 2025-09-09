extends BlockDragComponent


func _ready() -> void:
	assert(base is CapBlock)

func is_copy_valid(event: InputEvent) -> bool:
	#region Explicit type conversion hack
	@warning_ignore("confusable_local_usage", "shadowed_variable_base_class")
	var base := base as CapBlock
	#endregion
	
	return (
		not base.is_type(NestedData.Type.BEGIN) and
		super(event)
	)
