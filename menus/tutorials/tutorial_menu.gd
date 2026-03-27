extends PopupPanel


@export var topic_list: VBoxContainer
@export var topic_title: Label
@export var image_rect: TextureRect
@export var back_button: Button
@export var next_button: Button
@export var page_label: Label
@export var description_label: Label
@export var close_button: Button
@export var tutorial_database: Array[TutorialTopic]

var current_topic: TutorialTopic
var current_page := 0


func _ready() -> void:
	_populate_topic_list()

func _populate_topic_list() -> void:
	# Clear existing children if any
	for child in topic_list.get_children():
		child.queue_free()
		
	# Create a button for every topic in our database
	for topic in tutorial_database:
		var btn := Button.new()
		btn.text = topic.title
		btn.theme_type_variation = &"MainMenuButton" # Reusing your existing theme
		btn.pressed.connect(load_topic.bind(topic))
		topic_list.add_child(btn)
		
	# Automatically load the first topic if it exists
	if tutorial_database.size() > 0:
		load_topic(tutorial_database[0])

func load_topic(topic: TutorialTopic) -> void:
	current_topic = topic
	current_page = 0
	topic_title.text = topic.title
	_update_display()

func _update_display() -> void:
	if current_topic == null or current_topic.slides.is_empty():
		return
	
	var slide: TutorialSlide = current_topic.slides[current_page]
	
	image_rect.texture = slide.image
	description_label.text = slide.text
	page_label.text = "%d / %d" %[current_page + 1, current_topic.slides.size()]
	
	# Disable buttons if at the start or end of the slideshow
	back_button.disabled = (current_page == 0)
	next_button.disabled = (current_page == current_topic.slides.size() - 1)

func _on_prev_pressed() -> void:
	if current_page > 0:
		current_page -= 1
		_update_display()

func _on_next_pressed() -> void:
	if current_page < current_topic.slides.size() - 1:
		current_page += 1
		_update_display()
