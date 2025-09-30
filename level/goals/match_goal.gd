extends Goal


@export var match_var: Variant


func _on_matching_var_changed(value: Variant) -> void:
	is_complete = value == match_var
