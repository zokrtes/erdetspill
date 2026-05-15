extends Node3D

@onready var title_text: Node3D = $TitleText
@onready var subtitle_text: Label3D = $TitleText/SubtitleText/Label3D
@onready var menu_ui: CanvasLayer = $MenuUI
@onready var music_player: AudioStreamPlayer = $MusicPlayer
@onready var play_btn: Button = $MenuUI/VBoxContainer/PlayButton
@onready var exit_btn: Button = $MenuUI/VBoxContainer/ExitButton
@onready var settings_btn: Button = $MenuUI/VBoxContainer/SettingsButton
@onready var credits_btn: Button = $MenuUI/VBoxContainer/CreditsButton

const DROP_TIME_SECONDS: float = 10.0
const FLY_IN_DURATION: float = DROP_TIME_SECONDS
const HOVER_DISTANCE: float = 0.3
const HOVER_SPEED: float = 0.5

var _hover_time: float = 0.0
var _title_done: bool = false
var _title_rest_pos: Vector3 = Vector3(0, 1, 0)

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	menu_ui.visible = false
	title_text.position = Vector3(0, -8, -20)
	title_text.rotation_degrees.x = 35.0
	title_text.scale = Vector3(0.1, 0.1, 0.1)
	subtitle_text.position = Vector3(0, 0.2, 0.8)
	subtitle_text.modulate.a = 0.0

	play_btn.pressed.connect(_on_play)
	exit_btn.pressed.connect(get_tree().quit)
	settings_btn.visible = false
	credits_btn.visible = false

	_start_theme_song()
	_animate_title_in()

func _start_theme_song() -> void:
	if music_player == null or music_player.stream == null:
		return
	var stream_copy := music_player.stream.duplicate()
	if stream_copy != null and "loop" in stream_copy:
		stream_copy.loop = true
		music_player.stream = stream_copy
	music_player.play()

func _animate_title_in() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(title_text, "position", _title_rest_pos, FLY_IN_DURATION).set_ease(Tween.EASE_OUT)
	tween.tween_property(title_text, "rotation_degrees:x", 0.0, FLY_IN_DURATION).set_ease(Tween.EASE_OUT)
	tween.tween_property(title_text, "scale", Vector3.ONE, FLY_IN_DURATION).set_ease(Tween.EASE_OUT)
	await tween.finished
	_title_done = true

	var fade := create_tween()
	fade.set_parallel(true)
	fade.tween_property(subtitle_text, "modulate:a", 1.0, 1.0)
	await get_tree().create_timer(0.5).timeout
	menu_ui.visible = true

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not _title_done:
		return
	_hover_time += delta * HOVER_SPEED
	title_text.position.y = _title_rest_pos.y + sin(_hover_time) * HOVER_DISTANCE

func _on_play() -> void:
	if GameManager and GameManager.has_method("reset_game"):
		GameManager.reset_game()
	var canvas := CanvasLayer.new()
	canvas.layer = 99
	add_child(canvas)

	var overlay := ColorRect.new()
	overlay.color = Color.BLACK
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.modulate.a = 0.0
	canvas.add_child(overlay)

	var tween := create_tween()
	tween.tween_property(overlay, "modulate:a", 1.0, 1.0)
	await tween.finished
	get_tree().change_scene_to_file("res://scenes/ui/name_input.tscn")

func _on_settings() -> void:
	pass

func _on_credits() -> void:
	pass
