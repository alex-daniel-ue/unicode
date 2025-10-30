extends Node


@export var pool_size := 16
var volume := 0.0:
	set(value):
		volume = value
		for player in pool:
			player.volume_linear = volume
var pool: Array[AudioStreamPlayer]


func _ready() -> void:
	for i in range(pool_size):
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		pool.append(player)


func play(sfx: AudioStream, pitch := 1.) -> void:
	if not sfx: return
	
	for player in pool:
		if not player.playing:
			player.stream = sfx
			player.pitch_scale = pitch
			player.play()
