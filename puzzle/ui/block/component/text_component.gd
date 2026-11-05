class_name BlockTextComponent
extends BlockBaseComponent
## A block's words and slots, built from its data: `text` with "{}" for each
## slot, "\n" between lines, and `text_blocks` for the slots themselves.

const LINE_HBOX_SCENE := preload("res://puzzle/ui/block/templates/line_hbox.tscn")


func _ready() -> void:
	base.data.text_changed.connect(format)


## The blocks in its slots, as they are now: a slot with a block dropped in
## reports that block, since the slot itself is hidden behind it.
func get_blocks() -> Array[Block]:
	var blocks: Array[Block]
	for line in base.text_container.get_children():
		for block in line.get_children():
			if block is Block and block.visible:
				blocks.append(block as Block)
	return blocks


## The block's text on one line, with each slot's own raw text in its place.
func get_raw() -> String:
	var children_text: Array[String]
	for child in get_blocks():
		children_text.append(child.text.get_raw())
	return base.data.text.format(children_text, "{}").replace("\\n", " ")


## Builds the lines and slots from the data, again whenever the text changes.
func format() -> void:
	# Park any already-plugged-in fill back outside the container, or the teardown
	# below frees it. format() runs more than once (construct(), _ready(), and
	# every data.text_changed), so this has to be idempotent.
	_return_fills()

	if base.data.text.is_empty():
		base.data.text = "ERROR, EMPTY TEXT"

	var present_text_blocks := base.data.text.count("{}")
	if present_text_blocks > len(base.data.text_blocks) + 1:
		return push_error(
			"(%s) Not enough Blocks inside text_data! (%s, %s)" %
			[base, present_text_blocks - 1, len(base.data.text_blocks)]
		)

	for child in base.text_container.get_children():
		base.text_container.remove_child(child)
		child.queue_free()

	var block_idx := 0
	for line in base.data.text.split("\\n"):
		var hbox := LINE_HBOX_SCENE.instantiate()
		base.text_container.add_child(hbox)

		var plaintexts := line.split("{}")
		_add_label(plaintexts[0], hbox)

		for idx in range(1, len(plaintexts)):
			if block_idx < len(base.data.text_blocks):
				var block := Block.construct(base.data.text_blocks[block_idx])
				if block is ValueBlock and block_idx < base.data.text_hints.size():
					(block as ValueBlock).hint = base.data.text_hints[block_idx]
				hbox.add_child(block)
				block_idx += 1
			_add_label(plaintexts[idx], hbox)

	_adopt_fills()


## Plugs base.preset_fills' Block children into the slots just rebuilt, in child
## order, one per receptive slot.
##
## The same move socket_drop_manager makes when a student drops a block into a
## slot: the fill is added as a sibling at the slot's index, the slot is hidden
## rather than freed, and the fill remembers it as its overridden_socket. A preset
## socket and a student-filled socket are then the same shape, and get_blocks()
## reports only visible children, so the serializer, the interpreter and
## get_preset() agree without any of them having to know what a preset is.
func _adopt_fills() -> void:
	if base.preset_fills == null:
		return

	var slots: Array[Block] = []
	for block in get_blocks():
		if block is SocketBlock and block.data.socket != null and block.data.socket.receptive:
			slots.append(block)

	var index := 0
	for fill in base.preset_fills.get_children():
		if not (fill is Block):
			continue
		if index >= slots.size():
			push_error(
				"(%s) has more fills than slots that take one (%d slot(s))."
				% [base.name, slots.size()]
			)
			return

		var slot := slots[index] as SocketBlock
		var container := slot.get_parent()
		var at := slot.get_index()
		slot.visible = false
		(fill as Block).orphan()
		container.add_child(fill)
		container.move_child(fill, at)
		(fill as SocketBlock).overridden_socket = slot
		(fill as Block).visible = true
		index += 1


## The reverse, so format() can rebuild without taking the fills with it.
func _return_fills() -> void:
	if base.preset_fills == null:
		return
	for fill in _fills_in_place():
		fill.overridden_socket = null
		fill.orphan()
		base.preset_fills.add_child(fill)


func _fills_in_place() -> Array[SocketBlock]:
	var placed: Array[SocketBlock] = []
	for line in base.text_container.get_children():
		for child in line.get_children():
			if child is SocketBlock and (child as SocketBlock).has_overridden():
				placed.append(child as SocketBlock)
	return placed


func _add_label(text: String, line: HBoxContainer) -> void:
	if text.strip_edges().is_empty():
		return
	var label := Label.new()
	label.theme_type_variation = &"BlockLabel"
	label.text = text.strip_edges()
	# The block font sits centred in its line when right-aligned.
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	line.add_child(label)
