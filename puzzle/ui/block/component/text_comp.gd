class_name BlockTextComponent
extends BlockBaseComponent


func _ready() -> void:
	base.data.text_changed.connect(format)

func get_blocks() -> Array[Block]:
	var res: Array[Block]
	for line in base.text_container.get_children():
		for block in line.get_children():
			if block is Block and block.visible:
				res.append(block as Block)
	return res

func get_raw() -> String:
	var children_text: Array[String]
	for child in get_blocks():
		children_text.append(child.text.get_raw())
	return base.data.text.format(children_text, "{}")

func format() -> void:
	if base.data.text.is_empty():
		base.data.text = "ERROR, EMPTY TEXT"
	
	var present_text_blocks := base.data.text.count("{}")
	if present_text_blocks > len(base.data.text_blocks)+1:
		return push_error(
			"(%s) Not enough Blocks inside text_data! (%s, %s)" %
			[base, present_text_blocks-1, len(base.data.text_blocks)]
		)
	
	for child in base.text_container.get_children():
		base.text_container.remove_child(child)
		child.queue_free()
	
	var block_idx := 0
	for line in base.data.text.split("\\n"):
		var hbox := HBoxContainer.new()
		hbox.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		base.text_container.add_child(hbox)
		
		var plaintexts := line.split("{}")
		_add_label(plaintexts[0], hbox)
		
		for idx in range(1, len(plaintexts)):
			if block_idx < len(base.data.text_blocks):
				var block := Block.construct(base.data.text_blocks[block_idx])
				hbox.add_child(block)
				block_idx += 1
			_add_label(plaintexts[idx], hbox)

func _add_label(text: String, line: HBoxContainer) -> void:
	if not text.strip_edges().is_empty():
		var label := Label.new()
		label.theme_type_variation = &"BlockLabel"
		label.text = text.strip_edges()
		# For some reason the "04b_03" font visually centers when aligned right 
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		line.add_child(label)
