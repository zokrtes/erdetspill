extends AudioStreamPlayer

## World ambience; add to group AmbiencePlayer — stopped when an NPC dies.

@export var ambience_stream: AudioStream


func _ready() -> void:
	add_to_group("AmbiencePlayer")
	if ambience_stream != null:
		stream = ambience_stream
	_ensure_looping_stream()
	if not finished.is_connected(_on_stream_finished):
		finished.connect(_on_stream_finished)
	if stream != null and not is_playing():
		play()


func _ensure_looping_stream() -> void:
	if stream == null:
		return
	if stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true


func _on_stream_finished() -> void:
	# Fallback loop if import settings or runtime stream type still ends playback.
	if stream != null:
		play()
