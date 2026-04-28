extends CanvasLayer

## Pause overlay: Escape toggles pause. PROCESS_MODE_ALWAYS so UI works when tree is paused.

var _paused: bool = false

@onready var _panel: PanelContainer = $Center/PanelContainer
@onready var _resume_btn: Button = $Center/PanelContainer/VBox/ResumeButton
@onready var _debug_btn: Button = $Center/PanelContainer/VBox/DebugButton
@onready var _quit_btn: Button = $Center/PanelContainer/VBox/QuitButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 80
	visible = false
	if _resume_btn:
		_resume_btn.pressed.connect(_on_resume_pressed)
	if _debug_btn:
		_debug_btn.pressed.connect(_on_debug_pressed)
	if _quit_btn:
		_quit_btn.pressed.connect(_on_quit_pressed)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
		return
	if _should_block_pause_toggle():
		return
	if _paused:
		unpause()
	else:
		pause()
	get_viewport().set_input_as_handled()


func _should_block_pause_toggle() -> bool:
	var dui: Node = get_node_or_null("/root/DialogueUI")
	if dui and dui.has_method("is_open") and dui.is_open():
		return true
	if GameManager and GameManager.has_method("is_minigame_active") and GameManager.is_minigame_active():
		return true
	var cur: Node = get_tree().current_scene
	if cur and cur.has_node("InventoryPanel"):
		var inv: Node = cur.get_node("InventoryPanel")
		if inv.get("is_open") == true:
			return true
	# Another system paused the tree (e.g. death screen) — do not stack pause menu.
	if get_tree().paused and not _paused:
		return true
	return false


func pause() -> void:
	_paused = true
	get_tree().paused = true
	visible = true
	if _panel:
		_panel.show()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func unpause() -> void:
	_paused = false
	get_tree().paused = false
	visible = false
	if _panel:
		_panel.hide()
	var player: Node = get_tree().get_first_node_in_group("PlayerCharacter")
	if player and player.has_method("should_use_fps_mouse_capture") and player.should_use_fps_mouse_capture():
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _on_resume_pressed() -> void:
	unpause()


func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_debug_pressed() -> void:
	if not GameManager.debug_mode:
		return
	var current_scene := get_tree().current_scene
	if current_scene == null or not current_scene.has_node("DebugPanel"):
		return
	var debug_panel := current_scene.get_node("DebugPanel") as CanvasLayer
	if debug_panel == null:
		return
	debug_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	debug_panel.visible = not debug_panel.visible
