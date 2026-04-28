extends CanvasLayer

@onready var penalty_label: Label = $Overlay/CenterPanel/VBoxContainer/PenaltyLabel
@onready var retry_button: Button = $Overlay/CenterPanel/VBoxContainer/RetryButton

var penalty_amount: int = 0

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

func set_penalty(amount: int) -> void:
	penalty_amount = max(0, amount)
	_update_text()

func _update_text() -> void:
	if not penalty_label:
		return
	penalty_label.text = "Du mistet %d kroner." % penalty_amount

func _on_retry_pressed() -> void:
	get_tree().paused = false
	if GameManager and GameManager.has_method("reset_game"):
		GameManager.reset_game()
	queue_free()  # Free this node before reloading
	get_tree().reload_current_scene()

func _exit_tree() -> void:
	if get_tree():
		get_tree().paused = false
