extends CanvasLayer

signal dialogue_finished

@onready var dialogue_panel: Control = $DialoguePanel
@onready var speaker_label: Label = $DialoguePanel/MarginContainer/VBoxContainer/SpeakerLabel
@onready var dialogue_label: Label = $DialoguePanel/MarginContainer/VBoxContainer/DialogueLabel
@onready var button_container: VBoxContainer = $DialoguePanel/MarginContainer/VBoxContainer/ButtonContainer
@onready var continue_button: Button = $DialoguePanel/MarginContainer/VBoxContainer/ButtonContainer/ContinueButton

var _lines: Array = []
var _index: int = 0
var _on_close: Callable = Callable()
var _speaker: String = ""

const THOUGHT_COLOR := Color(0.6, 0.8, 1.0)
const NPC_COLOR := Color.WHITE

func _ready() -> void:
	dialogue_panel.visible = false
	dialogue_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	continue_button.pressed.connect(_on_continue_pressed)

func show_dialogue(lines: Array, speaker: String = "", on_close: Callable = Callable()) -> void:
	_lines = lines.duplicate()
	_index = 0
	_speaker = speaker
	_on_close = on_close
	_clear_menu_buttons()
	continue_button.visible = true
	if speaker != "":
		speaker_label.text = speaker
		speaker_label.visible = true
	else:
		speaker_label.visible = false
	dialogue_panel.visible = true
	_ensure_mouse_visible()
	_freeze_player(true)
	continue_button.grab_focus()
	_show_next_line()

func show_menu(lines: Array, buttons: Array, speaker: String = "") -> void:
	_lines = lines.duplicate()
	_index = 0
	_speaker = speaker
	_on_close = Callable()
	_clear_menu_buttons()
	continue_button.visible = false
	if speaker != "":
		speaker_label.text = speaker
		speaker_label.visible = true
	else:
		speaker_label.visible = false
	dialogue_panel.visible = true
	_ensure_mouse_visible()
	_freeze_player(true)
	if _lines.is_empty():
		dialogue_label.text = ""
	else:
		_show_next_line()
	for btn_data in buttons:
		var act: Callable = btn_data.get("action", Callable())
		_add_button(str(btn_data.get("text", "?")), act)

func close() -> void:
	dialogue_panel.visible = false
	_clear_menu_buttons()
	continue_button.visible = true
	_freeze_player(false)
	if _on_close.is_valid():
		_on_close.call()
	_on_close = Callable()
	dialogue_finished.emit()

func is_open() -> bool:
	return dialogue_panel.visible

func _show_next_line() -> void:
	if _index >= _lines.size():
		close()
		return
	var line = _lines[_index]
	_index += 1
	var text: String = ""
	var is_thought: bool = false
	if line is Dictionary:
		text = str(line.get("text", ""))
		is_thought = bool(line.get("is_thought", false)) or bool(line.get("is_player_thought", false))
	elif str(line).begins_with("§"):
		text = str(line).substr(1)
		is_thought = true
	else:
		text = str(line)
	dialogue_label.text = text
	dialogue_label.add_theme_color_override(
		"font_color",
		THOUGHT_COLOR if is_thought else NPC_COLOR
	)

func _on_continue_pressed() -> void:
	_show_next_line()

func _clear_menu_buttons() -> void:
	for child in button_container.get_children():
		if child != continue_button:
			child.queue_free()

func _add_button(text: String, action: Callable) -> void:
	var btn := Button.new()
	btn.text = text
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.process_mode = Node.PROCESS_MODE_ALWAYS
	btn.custom_minimum_size = Vector2(150, 44)
	btn.pressed.connect(
		func():
			_clear_menu_buttons()
			continue_button.visible = true
			if action.is_valid():
				action.call()
	)
	button_container.add_child(btn)

func _freeze_player(frozen: bool) -> void:
	var player := get_tree().get_first_node_in_group("PlayerCharacter")
	if player and player.has_method("freeze_for_dialogue"):
		player.freeze_for_dialogue(frozen)
	if player and player.has_method("set_weapon_active"):
		player.set_weapon_active(not frozen)

func _ensure_mouse_visible() -> void:
	if Input.get_mouse_mode() != Input.MOUSE_MODE_VISIBLE:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
