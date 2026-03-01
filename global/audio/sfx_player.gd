extends Node


@export var pool_size := 16
var volume := 0.8:
	set(value):
		volume = value
		for player in pool:
			if player:
				player.volume_db = linear_to_db(volume)
var pool: Array[AudioStreamPlayer]


func _ready() -> void:
	for i in range(pool_size):
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		player.volume_db = linear_to_db(volume)
		add_child(player)
		pool.append(player)


func play(sfx: AudioStream, pitch := 1.) -> void:
	if not sfx:
		return
	
	for player in pool:
		if not player.playing:
			player.stream = sfx
			player.pitch_scale = pitch
			player.play()
			break
