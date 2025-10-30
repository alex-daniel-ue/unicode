extends Node

@onready var audio_player := $AudioStreamPlayer as AudioStreamPlayer
var current_track: AudioStream

func play_track(new_track: AudioStream, duration := 1.) -> void:
	if new_track == current_track and audio_player.playing:
		return
	current_track = new_track
	
	var tween := create_tween().set_trans(Tween.TRANS_SINE)
	if audio_player.playing:
		tween.tween_property(audio_player, "volume_linear", 0, duration)
	tween.tween_callback(fade_in.bind(duration))

func fade_in(duration: float):
	audio_player.stream = current_track
	audio_player.volume_linear = 0
	audio_player.play()
	
	create_tween().set_trans(Tween.TRANS_SINE)\
		.tween_property(audio_player, "volume_linear", 1.0, duration)

func stop(duration := 1.0):
	var tween = create_tween().set_trans(Tween.TRANS_SINE)\
		.tween_property(audio_player, "volume_linear", 0, duration)
	await tween.finished
	
	audio_player.stop()
	current_track = null
