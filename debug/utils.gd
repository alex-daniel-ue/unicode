class_name Utils
extends Object


const EMPTY_TEXT := "O[6>,t%6?s$o>lwqOn*^R-50G-dyVq{sW}TiS?=X@iw[h$Xc+-Uyu=CI2S5h8qNh"

## Currently primarily used in changing drop preview scale for when canvas is
## zoomed out.
static var drag_preview_container: Control


## Returns itself & its children, grandchildren, and so on.
static func get_children(node: Node, result: Array[Node] = []) -> Array[Node]:
	result.push_back(node)
	for child: Node in node.get_children():
		result = get_children(child, result)
	return result

static func get_block(of_node: Node) -> Block:
	if of_node == null: return null
	
	if not of_node.is_inside_tree():
		push_error('Node "%s" isn\'t in SceneTree.' % of_node)
		return null
	
	# Iterate through self + parents and find first Block node
	while of_node != null:
		# FIXME: Somewhat out of scope, checking if not SocketBlock
		# should be part of drop_manager.gd logic
		if of_node is Block and not of_node is SocketBlock:
			return of_node
		of_node = of_node.get_parent()
	
	# No Block parent anywhere in lineage
	return null

static func construct_block(data: BlockData) -> Block:
	var scene := load(data.base_block_path) as PackedScene
	var block := scene.instantiate() as Block
	
	block.data = data
	block.name = block.data.block_name
	block.format_text()
	
	return block

#static func get_class_ancestry(obj: Object) -> PackedStringArray:
	#var result: PackedStringArray
	#var script := obj.get_script() as Script
	#while script != null:
		#result.append(script.get_global_name())
		#script = script.get_base_script()
	#return result

#static func random_name() -> String:
	#const alphabet := "abcdefghijklmnopqrstuvwxyz"
	#
	#var result := ""
	#for i in range(randi_range(6, 15)):
		#result += alphabet[randi_range(0, len(alphabet)-1)]
	#return result
