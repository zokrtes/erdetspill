extends Node3D

@onready var swivel: Node3D = $Swivel
@onready var alarm_light: OmniLight3D = $Swivel/AlarmLight
@onready var alarm_audio: AudioStreamPlayer = $AlarmAudio
@onready var fire_audio: AudioStreamPlayer = $FireAudio

@export var alarm_sound: AudioStream
@export var fire_sound: AudioStream
## How fast the turret swivels toward the player (higher = snappier).
@export var track_smoothing: float = 12.0
## Aim at this height above player feet (chest / camera height).
@export var aim_height_offset: float = 1.35

const ALARM_DURATION: float = 0.1
var _alarm_active: bool = false
var _alarm_timer: float = 0.0


func _ready() -> void:
	if alarm_light:
		alarm_light.visible = false
	if fire_audio:
		fire_audio.process_mode = Node.PROCESS_MODE_ALWAYS
	if alarm_audio:
		alarm_audio.process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	_track_player(delta)
	if not _alarm_active:
		return
	_alarm_timer += delta
	if _alarm_timer >= ALARM_DURATION:
		_alarm_active = false
		_alarm_timer = 0.0
		_fire()


func on_alarm_triggered() -> void:
	if _alarm_active:
		return
	_alarm_active = true
	_alarm_timer = 0.0
	alarm_light.visible = true
	alarm_light.light_color = Color.RED
	if alarm_audio and alarm_sound:
		alarm_audio.stream = alarm_sound
		alarm_audio.play()


func on_alarm_cancelled() -> void:
	_alarm_active = false
	_alarm_timer = 0.0
	alarm_light.visible = false
	if alarm_audio:
		alarm_audio.stop()


func on_turret_fired() -> void:
	pass


func _track_player(delta: float) -> void:
	if swivel == null:
		return
	var player := get_tree().get_first_node_in_group("PlayerCharacter") as Node3D
	if player == null:
		return
	var aim_point := player.global_position + Vector3.UP * aim_height_offset
	var forward := swivel.global_position.direction_to(aim_point)
	if forward.length_squared() < 1e-8:
		return
	# Avoid unstable basis when looking almost straight up/down.
	if absf(forward.y) > 0.998:
		forward.y = sign(forward.y) * 0.998
		forward = forward.normalized()
	var target_basis := Basis.looking_at(forward, Vector3.UP)
	var w := clampf(track_smoothing * delta, 0.0, 1.0)
	var blended := swivel.global_transform.basis.slerp(target_basis, w)
	swivel.global_transform = Transform3D(blended, swivel.global_position)


func _fire() -> void:
	alarm_light.visible = false
	if alarm_audio:
		alarm_audio.stop()
	if fire_audio and fire_sound:
		fire_audio.stream = fire_sound
		fire_audio.play()
	# Let the shot start before death screen pauses the tree (otherwise only alarm is heard).
	await get_tree().create_timer(0.4, true).timeout
	var player := get_tree().get_first_node_in_group("PlayerCharacter")
	if player == null:
		return
	var health := player.get_node_or_null("HealthComponent")
	if health and health.has_method("take_damage"):
		health.take_damage(9999.0)
