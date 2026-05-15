extends CanvasLayer

var _shown: bool = false


func _ready() -> void:
	visible = false
	layer = 10
	var lc := get_tree().get_first_node_in_group("LightingCycle")
	if lc == null:
		return
	var timer := Timer.new()
	timer.wait_time = 1.0
	timer.timeout.connect(_check_night)
	add_child(timer)
	timer.start()


func _check_night() -> void:
	if _shown:
		return
	var lc := get_tree().get_first_node_in_group("LightingCycle")
	if lc and lc.get("time_of_day") != null and float(lc.time_of_day) > 0.75:
		_show_hint()


func _show_hint() -> void:
	visible = true
	_shown = true


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F:
		queue_free()
		get_viewport().set_input_as_handled()
