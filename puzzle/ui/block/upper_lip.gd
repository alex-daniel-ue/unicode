@tool
extends Control
##
## To preserve parity with NestedBlocks (which have UpperLip and Body),
## custom_minimum_size must be set on UpperLips and not on the root node.
## That also implies that root nodes must extend Container.
##
## pinagsasabi neto di ko na ren alam
##


@export var contents: Control


# Resize UpperLip according to Label's size
func _on_contents_resized() -> void:
	custom_minimum_size = contents.size
