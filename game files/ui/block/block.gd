class_name Block
extends Control


@export var is_infinite := false
@export var block_color := Color.WHITE:
	set(value):
		(_texture if _texture != null else find_child("NinePatchRect", true, false)).self_modulate = value
		block_color = value

## Is used in [Statement], [NestedBlock], and PuzzleCanvas.
@warning_ignore("unused_private_class_variable")
var _is_preview := false
var _original_parent: Node
var _original_idx: int

@onready var _texture := $NinePatchRect


## When using [code]DUPLICATE_USE_INSTANTIATION[/code] in [enum Node.DuplicateFlags]
## with [method Node.duplicate], programmatically added nodes (such as with
## [method Node.duplicate]) disappear, but not using that flag will make all
## children lose their [member Node.owner].[br]
## Therefore, [method Block.clone] doesn't use [code]DUPLICATE_USE_INSTANTIATION[/code],
## but also sets [member Node.owner] to all children recursively.
func clone() -> Block:
	var copy := duplicate(DUPLICATE_SCRIPTS)
	for child in Util.get_all_children(copy).slice(1):
		child.owner = copy
	return copy

#region === DRAG & DROP =======================================================
func _get_center_drag_pos() -> Vector2:
	return -0.5 * size

func _get_drag_data(_at_position: Vector2) -> Variant:
	var drag_preview_container := Control.new()
	drag_preview_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_drag_preview(drag_preview_container)
	
	
	var copy: Block = clone()
	if is_infinite:
		copy.is_infinite = false
		copy.block_color = Color.from_hsv(randf(), randf_range(0.2, 0.6), randf_range(0.9, 1.0))
	
	var dummy := copy.duplicate(0)
	drag_preview_container.add_child(dummy)
	
	dummy.position = -get_local_mouse_position()
	
	var tween := dummy.create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_ELASTIC)
	tween.tween_property(dummy, "position", _get_center_drag_pos(), 0.4)
	tween.play()
	if is_infinite:
		return copy
	
	# Store original parent in case of drag & drop failure
	_original_parent = get_parent()
	_original_idx = get_index()
	_original_parent.remove_child(self)
	return self
#endregion ====================================================================
