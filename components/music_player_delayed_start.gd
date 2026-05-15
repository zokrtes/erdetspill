extends AudioStreamPlayer

const DELAY_BEFORE_PLAY_SEC := 60.0


func _ready() -> void:
	stop()
	await get_tree().create_timer(DELAY_BEFORE_PLAY_SEC).timeout
	if is_inside_tree():
		play()
