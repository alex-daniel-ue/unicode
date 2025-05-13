class_name Block
extends Control


const DRAG_PREVIEW_DUR := 0.5
const DRAG_PREVIEW_EASE := Tween.EASE_OUT
const DRAG_PREVIEW_TRANS := Tween.TRANS_ELASTIC
const DRAG_PREVIEW_SCALE_MULT := Vector2(1.1, 1.1)
const DRAG_PREVIEW_SCALE_DUR := 0.2

@export var label: String
@export var infinite := false
@export var draggable := true
@export var placeable := true

var is_drop_preview := false  # Do NOT remove this. This is needed immensely.
var origin_parent: Node
var origin_idx: int

@onready var upper_lip := $UpperLip


func _get_drag_data(_at_position: Vector2) -> Variant:
	if not draggable:
		return null
	
	var drag_preview_container := Control.new()
	drag_preview_container.name = "DragPreviewContainer"
	set_drag_preview(drag_preview_container)
	
	var copy: Block = clone()
	if infinite:
		copy.infinite = false
		#copy.block_color = Color.from_hsv(randf(), 0.8, 1.0)
	
	# flag = 0 stops instantiation, duplicating exact appearance
	var drag_preview := copy.duplicate(0)
	drag_preview.position = -get_local_mouse_position()  # Start on pointer
	drag_preview_container.add_child(drag_preview)
	
	#region Animations
	var tween := drag_preview_container.create_tween()
	tween.set_parallel()
	
	tween.set_ease(DRAG_PREVIEW_EASE)
	tween.set_trans(DRAG_PREVIEW_TRANS)
	tween.tween_property(
		drag_preview,
		"position",
		get_center(),
		DRAG_PREVIEW_DUR
	)
	
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(
		drag_preview_container,
		"scale",
		scale * DRAG_PREVIEW_SCALE_MULT,
		DRAG_PREVIEW_SCALE_DUR
	)
	#endregion
	
	if infinite:
		return copy
	else:
		origin_parent = get_parent()
		origin_idx = get_index()
		
		origin_parent.remove_child(self)
		return self


## Returns the local center position. Meant to be overridden by subclasses.
func get_center() -> Vector2:
	return -0.5 * size


# Using DUPLICATE_USE_INSTANTIATION with Node.duplicate() makes programmatically
# added nodes disappear, while omitting it causes all children to lose their
# owner. Therefore, Block.clone() doesn't use this flag and instead recursively
# sets the owner for all children.
func clone(flags: int = DUPLICATE_SCRIPTS | DUPLICATE_SIGNALS) -> Block:
	var copy := duplicate(flags)
	
	# .slice(1) to avoid setting root node's owner to itself
	for child in Util.get_all_children(copy).slice(1):
		child.owner = copy
	return copy


func parse_label() -> void:
	# TODO:
	pass
