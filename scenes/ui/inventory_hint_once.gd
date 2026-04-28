extends CanvasLayer

## One-time hint: TAB for inventory. Persists via user:// config.

const CFG_PATH := "user://ui_seen.cfg"
const CFG_SECTION := "hints"
const CFG_KEY := "inventory_tab_hint_shown"

@onready var _center: Control = $Center
@onready var _panel: PanelContainer = $Center/PanelContainer
@onready var _label: Label = $Center/PanelContainer/VBox/HintLabel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 75
	visible = false
	if _panel:
		_panel.hide()
	var cfg := ConfigFile.new()
	if cfg.load(CFG_PATH) == OK and bool(cfg.get_value(CFG_SECTION, CFG_KEY, false)):
		queue_free()
		return
	call_deferred("_show_hint_once")


func _show_hint_once() -> void:
	visible = true
	if _panel:
		_panel.show()
	if _label:
		_label.text = "TAB - Inventory"
	_center.modulate = Color(1, 1, 1, 1)
	var tween := create_tween()
	tween.tween_interval(3.0)
	tween.tween_property(_center, "modulate:a", 0.0, 0.5)
	tween.finished.connect(_on_hint_finished)

func _on_hint_finished() -> void:
	var cfg := ConfigFile.new()
	cfg.load(CFG_PATH)
	cfg.set_value(CFG_SECTION, CFG_KEY, true)
	cfg.save(CFG_PATH)
	queue_free()
