class_name Block
extends Control


const DRAG_PREVIEW_DURATION := 0.5
const DRAG_PREVIEW_EASE := Tween.EASE_OUT
const DRAG_PREVIEW_TRANSITION := Tween.TRANS_ELASTIC

@export var is_infinite := false
@export var block_color := Color.WHITE:
	set(value):
		if _texture:
			_texture.self_modulate = value
		else:
			find_child("NinePatchRect", true, false).self_modulate = value
		block_color = value

## Is used in [Statement], [NestedBlock], and PuzzleCanvas.
@warning_ignore("unused_private_class_variable")
var _is_drop_preview := false
var _original_parent: Node
var _original_idx: int

@onready var _texture := $NinePatchRect
@onready var _upper_lip := $UpperLip


func _on_label_size_changed() -> void:
	custom_minimum_size.x = _upper_lip.size.x


#region DRAG & DROP ==========================================================
## When using [code]DUPLICATE_USE_INSTANTIATION[/code] in [enum Node.DuplicateFlags]
## with [method Node.duplicate], programmatically added nodes (such as with
## [method Node.duplicate]) disappear, but not using that flag will make all
## children lose their [member Node.owner].[br]
## Therefore, [method Block.clone] doesn't use [code]DUPLICATE_USE_INSTANTIATION[/code],
## but also sets [member Node.owner] to all children recursively.
func clone() -> Block:
	var copy := duplicate(DUPLICATE_SCRIPTS)
	# .slice(1) to avoid setting root node's owner to itself
	for child in Util.get_all_children(copy).slice(1):
		child.owner = copy
	return copy

func _get_center_drag_pos() -> Vector2:
	return -0.5 * size

func _get_drag_data(_at_position: Vector2) -> Variant:
	var drag_preview_container := Control.new()
	drag_preview_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_drag_preview(drag_preview_container)
	
	
	var clone: Block = clone()
	if is_infinite:
		clone.is_infinite = false
		clone.block_color = Color.from_hsv(randf(), 0.8, 1.0)
	
	# Duplicates clone to inherit random color
	# WARNING: Should be replaced to duplicate(0) only soon
	var drag_preview_dummy := clone.duplicate(0)
	drag_preview_container.add_child(drag_preview_dummy)
	
	var tween := drag_preview_container.create_tween()
	tween.set_parallel()
	tween.set_ease(DRAG_PREVIEW_EASE)
	tween.set_trans(DRAG_PREVIEW_TRANSITION)
	
	# Start where the mouse points
	drag_preview_dummy.position = -get_local_mouse_position()
	# End at the center
	tween.tween_property(drag_preview_dummy, "position", _get_center_drag_pos(), DRAG_PREVIEW_DURATION)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(drag_preview_container, "scale", scale + Vector2(0.1,0.1), 0.2)
	
	if is_infinite:
		return clone
	
	# Store original parent in case of drag & drop failure
	_original_parent = get_parent()
	_original_idx = get_index()
	_original_parent.remove_child(self)
	return self
#endregion ====================================================================
