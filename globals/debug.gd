extends Node


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		pass

func log(message: Variant = "", separator := ' ') -> void:
	if message is Array[Variant]:
		for index in range(len(message)):
			if message[index] is float:
				message[index] = "%.03f" % message[index]
		message = separator.join(message)
	elif message is float:
		message = "%.03f" % message
	print_rich("%.03f: %s" % [Time.get_ticks_msec() / 1000., str(message)])

func get_all_toolbox_categories() -> PackedStringArray:
	var toolbox_cats: PackedStringArray
	var all_block_data := _get_all_block_data()
	for block_data in all_block_data:
		if block_data.toolbox_category not in toolbox_cats:
			toolbox_cats.append(block_data.toolbox_category)
	return toolbox_cats

func _get_all_block_data(dir := DirAccess.open("res://puzzle/"), result: Array[BlockData] = []) -> Array[BlockData]:
	for file in dir.get_files():
		if file.ends_with(".tres"):
			var rsrc := load(dir.get_current_dir().path_join(file))
			if rsrc is BlockData:
				result.append(rsrc)
	
	for subdir in dir.get_directories():
		subdir = dir.get_current_dir().path_join(subdir)
		result = _get_all_block_data(DirAccess.open(subdir), result)
	
	return result
