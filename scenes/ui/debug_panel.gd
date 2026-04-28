extends CanvasLayer

@onready var money_label: Label = $Panel/MarginContainer/VBoxContainer/MoneyLabel
@onready var xp_label: Label = $Panel/MarginContainer/VBoxContainer/XPLabel
@onready var day_label: Label = $Panel/MarginContainer/VBoxContainer/DayLabel
@onready var quest_label: Label = $Panel/MarginContainer/VBoxContainer/QuestLabel
@onready var health_label: Label = $Panel/MarginContainer/VBoxContainer/HealthLabel
@onready var pos_label: Label = $Panel/MarginContainer/VBoxContainer/PosLabel

@onready var give_money_btn: Button = $Panel/MarginContainer/VBoxContainer/GiveMoneyButton
@onready var give_xp_btn: Button = $Panel/MarginContainer/VBoxContainer/GiveXPButton
@onready var next_day_btn: Button = $Panel/MarginContainer/VBoxContainer/NextDayButton
@onready var complete_quest_btn: Button = $Panel/MarginContainer/VBoxContainer/CompleteQuestButton
@onready var god_mode_btn: Button = $Panel/MarginContainer/VBoxContainer/GodModeButton

var god_mode: bool = false
var _panel_visible: bool = true

func _ready() -> void:
	if not GameManager.debug_mode:
		queue_free()
		return
	give_money_btn.pressed.connect(_give_money)
	give_xp_btn.pressed.connect(_give_xp)
	next_day_btn.pressed.connect(_next_day)
	complete_quest_btn.pressed.connect(_complete_quest)
	god_mode_btn.pressed.connect(_toggle_god_mode)
	GameManager.money_changed.connect(func(_v: int) -> void: _refresh())
	GameManager.xp_changed.connect(func(_v: int) -> void: _refresh())
	GameManager.level_up.connect(func(_v: int) -> void: _refresh())
	_refresh()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F1:
		_panel_visible = not _panel_visible
		$Panel.visible = _panel_visible

func _process(_delta: float) -> void:
	if not $Panel.visible:
		return
	_refresh()

func _refresh() -> void:
	money_label.text = "💰 NOK: " + str(GameManager.player_money)
	xp_label.text = "✨ XP: %d | LVL %d" % [GameManager.player_xp, GameManager.player_level]
	var lighting := get_tree().get_first_node_in_group("LightingCycle")
	if lighting and "time_of_day" in lighting:
		var t: float = lighting.time_of_day
		var hour := int(t * 24.0)
		var minute := int((t * 24.0 - hour) * 60.0)
		day_label.text = "📅 Dag %d  %02d:%02d" % [GameManager.current_day, hour, minute]
	else:
		day_label.text = "📅 Dag: " + str(GameManager.current_day)
	var quests := GameManager.get_active_quests()
	if quests.is_empty():
		quest_label.text = "📜 Quest: ingen"
	else:
		var q: Quest = quests[0] as Quest
		quest_label.text = "📜 " + q.name
		if quests.size() > 1:
			quest_label.text += " (+" + str(quests.size() - 1) + ")"
	var player := get_tree().get_first_node_in_group("PlayerCharacter")
	if player:
		pos_label.text = "📍 " + str(player.global_position.round())
		var health := player.get_node_or_null("HealthComponent")
		if health:
			health_label.text = "❤️ HP: " + str(int(health.current_health)) + "/" + str(int(health.max_health))
		else:
			health_label.text = "❤️ HP: N/A"
	else:
		pos_label.text = "📍 (ingen spiller)"
		health_label.text = "❤️ HP: N/A"

func _give_money() -> void:
	GameManager.add_flat_money_reward(500)

func _give_xp() -> void:
	GameManager.add_xp(50)

func _next_day() -> void:
	GameManager._advance_day()

func _complete_quest() -> void:
	var quests := GameManager.get_active_quests()
	if quests.is_empty():
		return
	GameManager.complete_quest(quests[0] as Quest)

func _toggle_god_mode() -> void:
	god_mode = not god_mode
	god_mode_btn.text = "God Mode " + ("ON" if god_mode else "OFF")
	god_mode_btn.modulate = Color.GREEN if god_mode else Color.WHITE
	var player := get_tree().get_first_node_in_group("PlayerCharacter")
	if player == null:
		return
	var health := player.get_node_or_null("HealthComponent")
	if health:
		if god_mode:
			health.max_health = 999999.0
			health.current_health = 999999.0
		else:
			health.max_health = 100.0
			health.current_health = 100.0
