extends MarginContainer


@export var _internal_category_order: PackedStringArray
@export var category_container: VBoxContainer

var category_scene := preload("res://puzzle/ui/side panel/tabs/toolbox/category.tscn")
var existing_categories: PackedStringArray


static func find_resources_in_folder(folder_path: String) -> Array[Resource]:
	var resources: Array[Resource]
	_deep_search(folder_path, resources)
	return resources

static func _deep_search(path: String, resources: Array[Resource]) -> void:
	var dir := DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if dir.current_is_dir():
				if file_name != "." and file_name != "..":
					_deep_search(path.path_join(file_name), resources)
			else:
				if file_name.ends_with(".tres"):
					var resource := ResourceLoader.load(path.path_join(file_name))
					if resource:
						resources.append(resource)
			file_name = dir.get_next()
	else:
		printerr("An error occurred when trying to access the path: ", path)


func _ready() -> void:
	for data in find_resources_in_folder("res://puzzle/blocks/"):
		add_block(Block.construct(data))

func add_block(block: Block) -> void:
	if block.data.category in existing_categories:
		for child in category_container.get_children():
			if child is Label:
				continue
			
			if child.category_name == block.data.category:
				child.add_block(block)
				return
	
	var category := add_category(block.data.category)
	category_container.add_child(category)
	category.add_block(block)
	
	sort_categories()

func add_category(category_name: String) -> VBoxContainer:
	existing_categories.append(category_name)
	
	var new_category := category_scene.instantiate() as VBoxContainer
	new_category.category_name = category_name
	
	return new_category

func sort_categories() -> void:
	var children: Array[Node] = category_container.get_children()
	
	var custom_sort_logic := func(a: Node, b: Node):
		# Label floats to top
		if a is Label: return true
		if b is Label: return false
		
		var a_idx: int = _internal_category_order.find(a.category_name)
		var b_idx: int = _internal_category_order.find(b.category_name)
		
		# -1 becomes very last
		if a_idx == -1: a_idx = 99999
		if b_idx == -1: b_idx = 99999
		
		# Sort alphabetically as fallback
		if a_idx == b_idx:
			return String(a.category_name) < String(b.category_name)
		
		return a_idx < b_idx
	
	children.sort_custom(custom_sort_logic)
	
	for i in range(children.size()):
		category_container.move_child(children[i], i)
