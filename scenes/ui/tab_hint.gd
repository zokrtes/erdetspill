extends CanvasLayer


func _ready() -> void:
	layer = 8


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_TAB:
		queue_free()
		get_viewport().set_input_as_handled()
