class_name ToolboxFit
extends Container
## Draws a toolbox tile's block smaller when the tile would be wider than the
## toolbox, so one long block can't stretch the toolbox past its panel on a
## small window. Only the toolbox's picture of it shrinks: the scale is on the
## child holding the block, not on the block, so a block dragged out (packed and
## copied, BlockDragComponent.copy()) comes out full size.

## How much smaller the block is drawn, 1 for full size. Set by ToolboxTile.fit_to().
var fit := 1.0:
	set(value):
		if is_equal_approx(value, fit):
			return
		fit = value
		update_minimum_size()
		queue_sort()


func _get_minimum_size() -> Vector2:
	var most := Vector2.ZERO
	for child in get_children():
		if child is Control and (child as Control).visible:
			most = most.max((child as Control).get_combined_minimum_size())
	return most * fit


func _notification(what: int) -> void:
	if what != NOTIFICATION_SORT_CHILDREN:
		return
	for child in get_children():
		if child is Control:
			var control := child as Control
			# Laid out at full size, then drawn smaller from its top-left corner.
			fit_child_in_rect(control, Rect2(Vector2.ZERO, control.get_combined_minimum_size()))
			control.scale = Vector2(fit, fit)
