extends CanvasLayer

signal sign_finished(texture: ImageTexture)

const CANVAS_SIZE := Vector2i(768, 384)
const BRUSH_WIDTH := 4.0

@onready var draw_canvas: Control = $Panel/CenterContainer/VBoxContainer/DrawViewportContainer/DrawViewport/DrawCanvas
@onready var draw_viewport: SubViewport = $Panel/CenterContainer/VBoxContainer/DrawViewportContainer/DrawViewport

var _points: Array[Dictionary] = []
var _drawing: bool = false
var _current_color: Color = Color.BLACK

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_set_player_ui_mode(true)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _exit_tree() -> void:
	_set_player_ui_mode(false)

func _on_draw_canvas_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_drawing = event.pressed
		if _drawing:
			_add_point(event.position)
		else:
			_add_gap()
		return
	if event is InputEventMouseMotion and _drawing:
		_add_point(event.position)

func _on_draw_canvas_draw() -> void:
	draw_canvas.draw_rect(Rect2(Vector2.ZERO, CANVAS_SIZE), Color.WHITE, true)
	draw_canvas.draw_rect(Rect2(Vector2.ZERO, CANVAS_SIZE), Color(0.1, 0.1, 0.1), false, 2.0)
	for i in range(1, _points.size()):
		var prev: Dictionary = _points[i - 1]
		var curr: Dictionary = _points[i]
		if bool(prev.get("gap", false)) or bool(curr.get("gap", false)):
			continue
		draw_canvas.draw_line(
			prev.get("pos", Vector2.ZERO),
			curr.get("pos", Vector2.ZERO),
			curr.get("color", Color.BLACK),
			BRUSH_WIDTH,
			true
		)

func _add_point(point: Vector2) -> void:
	var clamped := Vector2(
		clampf(point.x, 0.0, CANVAS_SIZE.x),
		clampf(point.y, 0.0, CANVAS_SIZE.y)
	)
	if _points.is_empty() or bool(_points[_points.size() - 1].get("gap", false)):
		_points.append({"pos": clamped, "color": _current_color, "gap": false})
	else:
		_points.append({"pos": clamped, "color": _current_color, "gap": false})
	draw_canvas.queue_redraw()

func _on_draw_canvas_mouse_exited() -> void:
	if _drawing:
		_drawing = false
		_add_gap()

func _on_color_button_pressed(color: Color) -> void:
	_current_color = color
	_add_gap()

func _on_clear_button_pressed() -> void:
	_points.clear()
	draw_canvas.queue_redraw()

func _add_gap() -> void:
	if _points.is_empty():
		return
	if bool(_points[_points.size() - 1].get("gap", false)):
		return
	_points.append({"gap": true})

func _on_done_button_pressed() -> void:
	await get_tree().process_frame
	var img := draw_viewport.get_texture().get_image()
	if img == null:
		queue_free()
		return
	img.flip_y()
	var texture := ImageTexture.create_from_image(img)
	sign_finished.emit(texture)
	queue_free()

func _set_player_ui_mode(enabled: bool) -> void:
	var player := get_tree().get_first_node_in_group("PlayerCharacter")
	if player and player.has_method("freeze_for_dialogue"):
		player.freeze_for_dialogue(enabled)
	if player and player.has_method("set_weapon_active"):
		player.set_weapon_active(not enabled)
