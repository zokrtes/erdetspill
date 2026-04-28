extends CanvasLayer

const RUSS_VOX1 := preload("res://assets/sfx/erdetlyd/vox/russ/vox1.ogg")
const RUSS_VOX4 := preload("res://assets/sfx/erdetlyd/vox/russ/vox4.ogg")
const EXPLODE5 := preload("res://assets/sfx/hl1-master/sound/weapons/explode5.wav")
const BUSTGLASS3 := preload("res://assets/sfx/hl1-master/sound/debris/bustglass3.wav")

@export var russ_sound: AudioStream
@export var glass_sound: AudioStream
@export var boom_sound: AudioStream

@onready var black_screen: ColorRect = $BlackScreen
@onready var russ_audio: AudioStreamPlayer = $RussAudio
@onready var glass_audio: AudioStreamPlayer = $GlassAudio
@onready var boom_audio: AudioStreamPlayer = $BoomAudio
@onready var hint_label: Label = $HintLabel

signal intro_finished

func _ready() -> void:
	if russ_sound:
		russ_audio.stream = russ_sound
	glass_audio.stream = glass_sound
	boom_audio.stream = boom_sound
	black_screen.modulate.a = 1.0
	hint_label.modulate.a = 0.0
	_freeze_player(true)
	_run_intro()

func _run_intro() -> void:
	# 0.0s mark -> vox1.ogg
	russ_audio.stream = RUSS_VOX1
	russ_audio.play()

	# 2.5s mark -> explode5.wav
	await get_tree().create_timer(2.5).timeout
	boom_audio.stream = EXPLODE5
	boom_audio.play()

	# 2.7s mark -> bustglass3.wav
	await get_tree().create_timer(0.2).timeout
	glass_audio.stream = BUSTGLASS3
	glass_audio.play()

	# 4.0s mark -> vox4.ogg
	await get_tree().create_timer(1.3).timeout
	russ_audio.stream = RUSS_VOX4
	russ_audio.play()

	await get_tree().create_timer(1.0).timeout

	var tween := create_tween()
	tween.tween_property(black_screen, "modulate:a", 0.0, 2.5)
	await tween.finished

	_freeze_player(false)
	intro_finished.emit()

	await get_tree().create_timer(0.5).timeout
	var hint_tween := create_tween()
	hint_tween.tween_property(hint_label, "modulate:a", 1.0, 0.5)
	await hint_tween.finished
	await get_tree().create_timer(4.0).timeout
	var fade_tween := create_tween()
	fade_tween.tween_property(hint_label, "modulate:a", 0.0, 1.0)
	await fade_tween.finished

	queue_free()

func _freeze_player(frozen: bool) -> void:
	var player := get_tree().get_first_node_in_group("PlayerCharacter")
	if player == null:
		return
	if frozen:
		player.process_mode = Node.PROCESS_MODE_DISABLED
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	else:
		player.process_mode = Node.PROCESS_MODE_INHERIT
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
