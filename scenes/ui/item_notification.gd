extends CanvasLayer

const ITEM_DATA_TEMPLATE := "res://data/items/%s.tres"

@onready var stack: VBoxContainer = $MarginContainer/NotificationStack

func _ready():
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	if GameManager and not GameManager.item_added.is_connected(_on_item_added):
		GameManager.item_added.connect(_on_item_added)

func _on_item_added(item_id: String, amount: int):
	if item_id == "approved_application":
		_show_notification("Stipendsøknad godkjent! Gå til banken.")
		return
	var display_name := item_id
	var item_data := _load_item_data(item_id)
	if item_data != null:
		display_name = item_data.display_name if item_data.display_name != "" else item_id
	var text := "+ %d x %s" % [amount, display_name]
	_show_notification(text)

func _show_notification(text: String):
	if stack == null:
		return
	var panel := PanelContainer.new()
	panel.self_modulate = Color(1, 1, 1, 0.9)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.06, 0.82)
	style.border_color = Color(1, 1, 1, 0.18)
	style.set_border_width_all(1)
	style.set_content_margin_all(6)
	panel.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_font_size_override("font_size", 40)
	panel.add_child(label)
	stack.add_child(panel)

	var tween := create_tween()
	tween.tween_interval(1.7)
	tween.tween_property(panel, "modulate:a", 0.0, 0.3)
	tween.finished.connect(panel.queue_free)

func _load_item_data(item_id: String) -> ItemData:
	var path := ITEM_DATA_TEMPLATE % item_id
	var loaded := ResourceLoader.load(path)
	if loaded is ItemData:
		return loaded
	return null
