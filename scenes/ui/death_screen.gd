extends CanvasLayer

@onready var retry_button: Button = $Overlay/CenterPanel/VBoxContainer/RetryButton
@onready var title_label: Label = $Overlay/CenterPanel/VBoxContainer/TitleLabel

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
	_update_text()
	retry_button.pressed.connect(_on_retry_pressed)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		_on_retry_pressed()
		get_viewport().set_input_as_handled()

func _update_text() -> void:
	if title_label:
		title_label.text = "DU DØDE"

func _on_retry_pressed() -> void:
	get_tree().paused = false
	if GameManager and GameManager.has_method("reset_game"):
		GameManager.reset_game()
	queue_free()  # Free this node before reloading
	get_tree().reload_current_scene()

func _exit_tree() -> void:
	if get_tree():
		get_tree().paused = false
