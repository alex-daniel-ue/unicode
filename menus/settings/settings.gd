extends PopupPanel

const MUSIC_BUS_NAME := "Music"
const SFX_BUS_NAME := "SFX"

var music_enabled := true
var last_volume := 1.0 # Default to full volume

@onready var enable_button := $MarginContainer/VBoxContainer/MusicEnableRow/EnableButton as Button
@onready var music_slider := $MarginContainer/VBoxContainer/MusicVolumeRow/MusicVolumeSlider as HSlider
@onready var sfx_slider := $MarginContainer/VBoxContainer/SFXVolumeRow/SFXVolumeSlider as HSlider


func _ready() -> void:
	# Initialize last_volume with the slider's starting value from the scene
	last_volume = music_slider.value
	_update_ui()


func set_music_enabled(is_enabled: bool) -> void:
	if music_enabled == is_enabled:
		return
	
	music_enabled = is_enabled
	
	if not music_enabled:
		# If we are disabling the music, save the current volume if it's not already 0.
		if music_slider.value > music_slider.min_value:
			last_volume = music_slider.value
	
	_update_ui()


func _update_ui() -> void:
	var music_bus_idx := AudioServer.get_bus_index(MUSIC_BUS_NAME)
	
	enable_button.text = "Disable" if music_enabled else "Enable"
	
	# Disconnect the signal to prevent it from firing while we programmatically set the value.
	music_slider.value_changed.disconnect(_on_music_volume_slider_value_changed)
	
	if music_enabled:
		music_slider.value = last_volume
		AudioServer.set_bus_mute(music_bus_idx, false)
		AudioServer.set_bus_volume_linear(music_bus_idx, last_volume)
	else:
		music_slider.value = music_slider.min_value
		AudioServer.set_bus_mute(music_bus_idx, true)
		# When muted, we don't need to change the bus volume. Muting is sufficient.
	
	# Reconnect the signal.
	music_slider.value_changed.connect(_on_music_volume_slider_value_changed)


func _on_enable_button_pressed() -> void:
	set_music_enabled(not music_enabled)


func _on_music_volume_slider_value_changed(value: float) -> void:
	if value > music_slider.min_value:
		last_volume = value
		if not music_enabled:
			# If the user moves the slider up from a muted state, re-enable the music.
			set_music_enabled(true)
		else:
			# Otherwise, just apply the new volume directly.
			AudioServer.set_bus_volume_linear(AudioServer.get_bus_index(MUSIC_BUS_NAME), value)
	elif music_enabled:
		# If the user drags the slider all the way to the minimum, disable the music.
		set_music_enabled(false)


func _on_sfx_volume_slider_value_changed(value: float) -> void:
	AudioServer.set_bus_volume_linear(AudioServer.get_bus_index(SFX_BUS_NAME), value)
