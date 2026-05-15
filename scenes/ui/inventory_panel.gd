extends CanvasLayer

@onready var panel: Panel = $Panel
@onready var list_container: VBoxContainer = $Panel/Margin/VBox/Scroll/List
@onready var description_label: Label = $Panel/Margin/VBox/Description

var is_open := false

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	if GameManager:
		if not GameManager.inventory_changed.is_connected(_on_inventory_changed):
			GameManager.inventory_changed.connect(_on_inventory_changed)
		if not GameManager.item_use_blocked.is_connected(_on_item_use_blocked):
			GameManager.item_use_blocked.connect(_on_item_use_blocked)

func _unhandled_input(event: InputEvent):
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_TAB:
		_toggle()
		get_viewport().set_input_as_handled()

func _toggle():
	if is_open:
		_close_inventory()
	else:
		_open_inventory()

func _open_inventory():
	is_open = true
	visible = true
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_set_player_weapon_active(false)
	_set_control_hints_visibility(true)
	_refresh_list()

func _close_inventory():
	is_open = false
	visible = false
	var player = get_tree().get_first_node_in_group("PlayerCharacter")
	var dialogue_waiting := false
	var dialogue_frozen := false
	var movement_frozen := false
	if player:
		dialogue_waiting = bool(player.get("dialogue_waiting_for_button"))
		dialogue_frozen = bool(player.get("camera_frozen"))
		movement_frozen = bool(player.get("movement_frozen"))
	if not dialogue_waiting:
		get_tree().paused = false
	if not dialogue_waiting and not dialogue_frozen and not movement_frozen:
		if player and player.has_method("should_use_fps_mouse_capture") and player.should_use_fps_mouse_capture():
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_set_player_weapon_active(true)
	_set_control_hints_visibility(false)

func _refresh_list():
	for child in list_container.get_children():
		child.queue_free()
	description_label.text = ""

	_add_item_rows()
	_add_ammo_rows()

func _add_item_rows():
	for item_id in GameManager.inventory.keys():
		var slot = GameManager.inventory[item_id]
		var data: ItemData = slot.get("data")
		var amount = int(slot.get("amount", 0))
		if data == null:
			continue
		var hover_text := _item_hover_description(data, item_id)
		var row = _create_row(
			data.display_name if data.display_name != "" else item_id,
			str(amount),
			data.icon,
			data.category,
			hover_text
		)
		if data.category == ItemData.Category.CONSUMABLE:
			row.pressed.connect(_on_consumable_pressed.bind(item_id))
		elif data.category == ItemData.Category.QUEST_ITEM:
			row.pressed.connect(_on_quest_item_pressed.bind(data.description))
		list_container.add_child(row)

func _add_ammo_rows():
	var player = get_tree().get_first_node_in_group("PlayerCharacter")
	if player == null:
		return
	var ammo_dict = player.get("ammoDict")
	var max_dict = player.get("maxNbPerAmmoDict")
	if ammo_dict == null or max_dict == null:
		return
	if not ammo_dict is Dictionary or not max_dict is Dictionary:
		return
	if ammo_dict == null or max_dict == null:
		return
	for ammo_id in ammo_dict.keys():
		var current = int(ammo_dict.get(ammo_id, 0))
		var max_amount = int(max_dict.get(ammo_id, 0))
		var ammo_hover := "Reserve: %d / %d (%s)" % [current, max_amount, str(ammo_id)]
		var row = _create_row(str(ammo_id), "%d/%d" % [current, max_amount], null, ItemData.Category.AMMO, ammo_hover)
		list_container.add_child(row)

func _item_hover_description(data: ItemData, item_id: String) -> String:
	var name_line := data.display_name if data.display_name != "" else item_id
	var desc := data.description.strip_edges() if data.description else ""
	if desc != "":
		return "%s\n\n%s" % [name_line, desc]
	return "%s\n\nIngen beskrivelse." % name_line

func _create_row(name_text: String, amount_text: String, icon: Texture2D, category: int, hover_description: String = "") -> Button:
	var button = Button.new()
	button.flat = true
	button.custom_minimum_size = Vector2(0, 34)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.text = _category_prefix(category) + " " + name_text + "    " + amount_text
	button.clip_text = true
	if icon != null:
		button.icon = icon
		button.expand_icon = true
	button.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	button.add_theme_color_override("font_pressed_color", Color(1, 1, 1))
	button.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	if hover_description != "":
		button.mouse_entered.connect(_on_item_row_mouse_entered.bind(hover_description))
		button.mouse_exited.connect(_on_item_row_mouse_exited)
	return button

func _category_prefix(category: int) -> String:
	if category == ItemData.Category.QUEST_ITEM:
		return "📜"
	if category == ItemData.Category.AMMO:
		return "🔫"
	return "•"

func _on_item_row_mouse_entered(description: String):
	if not is_open or description_label == null:
		return
	description_label.text = description

func _on_item_row_mouse_exited():
	if not is_open or description_label == null:
		return
	description_label.text = ""

func _on_consumable_pressed(item_id: String):
	GameManager.use_item(item_id)
	_refresh_list()

func _on_item_use_blocked(_item_id: String, code: String):
	if not is_open:
		return
	if code == "full_health":
		description_label.text = "Du har full helse."

func _on_quest_item_pressed(description: String):
	description_label.text = description if description != "" else "Ingen beskrivelse."

func _on_inventory_changed(_item_id: String, _new_amount: int):
	if is_open:
		_refresh_list()

func _set_player_weapon_active(enabled: bool):
	var player = get_tree().get_first_node_in_group("PlayerCharacter")
	if player and player.has_method("set_weapon_active"):
		player.set_weapon_active(enabled)


func _set_control_hints_visibility(inventory_open: bool) -> void:
	var flash := get_tree().current_scene.get_node_or_null("FlashlightHint")
	if flash:
		flash.visible = not inventory_open
	var inv_once := get_tree().current_scene.get_node_or_null("InventoryHintOnce")
	if inv_once:
		inv_once.visible = not inventory_open
	var tab := get_tree().current_scene.get_node_or_null("TabHint")
	if tab:
		tab.visible = true
