extends CanvasLayer

signal signed
signal cancelled

const SIGNATURE_LINE_WIDTH := 2.0

@onready var _panel: Panel = $Panel
@onready var _sign_button: Button = $Panel/Margin/VBox/Buttons/SignButton
@onready var _clear_button: Button = $Panel/Margin/VBox/Buttons/ClearButton
@onready var _signature_canvas: Control = $Panel/Margin/VBox/SignatureCanvas
@onready var _error_label: Label = $Panel/Margin/VBox/ErrorLabel

var _has_signature: bool = false
var _signature_points: Array[Vector2] = []
var _signature_break_indices: Array[int] = []
var _is_drawing: bool = false
var _accepted: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	visible = true
	_error_label.text = ""
	_sign_button.pressed.connect(_on_sign_pressed)
	_clear_button.pressed.connect(_on_clear_pressed)
	_signature_canvas.gui_input.connect(_on_signature_gui_input)
	_signature_canvas.draw.connect(_on_signature_draw)
	_signature_canvas.mouse_exited.connect(_on_signature_mouse_exited)
	_set_player_frozen(true)
	if GameManager and GameManager.has_method("start_minigame"):
		GameManager.start_minigame("iver_petisjon")


func _exit_tree() -> void:
	if not _accepted:
		_set_player_frozen(false)
	if GameManager and str(GameManager.active_minigame_id) == "iver_petisjon" and GameManager.has_method("end_minigame"):
		GameManager.end_minigame("iver_petisjon", 0)


func _set_player_frozen(frozen: bool) -> void:
	var player := get_tree().get_first_node_in_group("PlayerCharacter")
	if player and player.has_method("freeze_for_dialogue"):
		player.freeze_for_dialogue(frozen)
	if player and player.has_method("set_weapon_active"):
		player.set_weapon_active(not frozen)
	if frozen:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	elif player and player.has_method("should_use_fps_mouse_capture") and player.should_use_fps_mouse_capture():
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _on_sign_pressed() -> void:
	if not _has_signature:
		_error_label.text = "Du må signere"
		return
	_error_label.text = ""
	_accepted = true
	signed.emit()
	queue_free()


func _on_clear_pressed() -> void:
	_signature_points.clear()
	_signature_break_indices.clear()
	_has_signature = false
	_is_drawing = false
	_error_label.text = ""
	_signature_canvas.queue_redraw()


func _on_signature_gui_input(event: InputEvent) -> void:
	var local_rect := Rect2(Vector2.ZERO, _signature_canvas.size)
	if event is InputEventMouseButton and \
			event.button_index == MOUSE_BUTTON_LEFT:
		_is_drawing = event.pressed
		if _is_drawing:
			if not _signature_points.is_empty():
				_signature_break_indices.append(_signature_points.size())
			var p: Vector2 = event.position
			if local_rect.has_point(p):
				_signature_points.append(p)
				_has_signature = true
		_signature_canvas.queue_redraw()
		return
	if event is InputEventMouseMotion and _is_drawing:
		var p2: Vector2 = event.position
		if local_rect.has_point(p2):
			_signature_points.append(p2)
			_has_signature = true
		_signature_canvas.queue_redraw()


func _on_signature_mouse_exited() -> void:
	_is_drawing = false


func _on_signature_draw() -> void:
	_signature_canvas.draw_rect(Rect2(Vector2.ZERO, _signature_canvas.size), Color.WHITE, true)
	_signature_canvas.draw_rect(Rect2(Vector2.ZERO, _signature_canvas.size), Color.BLACK, false, 1.0)
	if _signature_points.size() < 2:
		return
	for i in range(1, _signature_points.size()):
		if _signature_break_indices.has(i):
			continue
		_signature_canvas.draw_line(
			_signature_points[i - 1],
			_signature_points[i],
			Color.BLACK,
			SIGNATURE_LINE_WIDTH
		)
