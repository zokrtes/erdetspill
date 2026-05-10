extends AudioStreamPlayer

## World ambience; add to group AmbiencePlayer — stopped when an NPC dies.
## Volume follows LightingCycle.time_of_day (Norwegian summer day / evening / night).

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
	_update_volume_for_time_of_day()


func _process(_delta: float) -> void:
	_update_volume_for_time_of_day()


func _update_volume_for_time_of_day() -> void:
	var lighting := get_tree().get_first_node_in_group("LightingCycle")
	if lighting == null or not ("time_of_day" in lighting):
		return
	var t: float = clampf(float(lighting.time_of_day), 0.0, 1.0)
	var db: float
	if t >= 0.25 and t < 0.75:
		db = -12.0
	elif t >= 0.75 and t < 0.9:
		db = -16.0
	else:
		db = -20.0
	if not is_equal_approx(volume_db, db):
		volume_db = db


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
	if stream != null:
		play()
