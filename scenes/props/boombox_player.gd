extends RigidBody3D

@export var playlist: Array[AudioStream] = []
@export var randomize_playlist: bool = true
@export var start_playing_on_ready: bool = true

@onready var audio_player: AudioStreamPlayer3D = $AudioStreamPlayer3D

var _playlist_index: int = 0


func _ready() -> void:
	if not is_in_group("Carriable"):
		add_to_group("Carriable")
	CarriablePickup.register(self)
	audio_player.max_distance = 75.0
	audio_player.finished.connect(_on_track_finished)
	if start_playing_on_ready:
		_play_next_track()


func _on_track_finished() -> void:
	_play_next_track()


func _play_next_track() -> void:
	if playlist.is_empty():
		if audio_player.stream:
			audio_player.play()
		return

	var available: Array[AudioStream] = []
	for stream in playlist:
		if stream != null:
			available.append(stream)
	if available.is_empty():
		return

	if randomize_playlist:
		audio_player.stream = available[randi() % available.size()]
	else:
		var idx := _playlist_index % available.size()
		audio_player.stream = available[idx]
		_playlist_index += 1
	audio_player.play()
