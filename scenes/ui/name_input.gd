extends CanvasLayer

@export var bestefar_voice: AudioStream

@onready var name_input: LineEdit = $Panel/NameInput
@onready var confirm_btn: Button = $Panel/ConfirmButton
@onready var audio: AudioStreamPlayer = $Panel/BestefarstemmeAudio

func _ready() -> void:
	layer = 20
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if bestefar_voice != null:
		audio.stream = bestefar_voice
	if audio.stream:
		audio.play()
	confirm_btn.pressed.connect(_on_confirm)
	name_input.text_submitted.connect(func(_t: String) -> void: _on_confirm())
	name_input.grab_focus()


func _on_confirm() -> void:
	var player_name := name_input.text.strip_edges()
	if player_name == "":
		player_name = "Spilleren"
	GameManager.player_name = player_name
	print("Player name set: ", player_name)

	var tween := create_tween()
	var overlay := ColorRect.new()
	overlay.color = Color.BLACK
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Panel.add_child(overlay)
	overlay.modulate.a = 0.0
	tween.tween_property(overlay, "modulate:a", 1.0, 0.8)
	await tween.finished
	get_tree().change_scene_to_file("res://levels/main_demo.tscn")
