extends CanvasLayer

@export var ending_sound: AudioStream

@onready var overlay: ColorRect = $BlackOverlay
@onready var bestefar_line: Label = $BestefarLine
@onready var title_label: Label = $TitleLabel
@onready var ending_audio: AudioStreamPlayer = $EndingAudio

func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	if ending_sound != null:
		ending_audio.stream = ending_sound
	overlay.modulate.a = 0.0
	bestefar_line.modulate.a = 0.0
	title_label.modulate.a = 0.0
	_run_ending()


func _run_ending() -> void:
	var player := get_tree().get_first_node_in_group("PlayerCharacter")
	if player:
		player.process_mode = Node.PROCESS_MODE_DISABLED

	await get_tree().create_timer(2.0).timeout

	if ending_audio.stream:
		ending_audio.play()

	var tween := create_tween()
	tween.tween_property(overlay, "modulate:a", 1.0, 2.0)
	await tween.finished

	await get_tree().create_timer(0.5).timeout
	var t2 := create_tween()
	t2.tween_property(bestefar_line, "modulate:a", 1.0, 1.0)
	await t2.finished

	await get_tree().create_timer(1.8).timeout
	bestefar_line.text = "Mormor ville også satt pris på det."
	await get_tree().create_timer(2.3).timeout

	var t3 := create_tween()
	t3.tween_property(title_label, "modulate:a", 1.0, 1.5)
	await t3.finished

	await get_tree().create_timer(3.0).timeout
	get_tree().change_scene_to_file("res://scenes/ui/title_screen.tscn")
