# UIStats.gd
extends HBoxContainer

const QUEST_BOX = preload("res://components/quest/quest_box.tscn")

@onready var quest_container: VBoxContainer = $QuestDisplay
@onready var xp_label: Label = $Stats/XPLabel
@onready var currency_label: Label = $Stats/NOK
@onready var title_label: Label = $Stats/TitleLabel
var quest_notice_label: Label

const AUTO_QUEST_NOTICES := {
	"ECONOMIC_REALITY": "Du har fått et nytt oppdrag: Gå til butikken.",
	"SECOND_ICECREAM": "Du har fått et nytt oppdrag: Kjøp én is til."
}

func _ready():
	# Wait for GameManager
	await get_tree().process_frame
	
	# Connect to GameManager signals
	if GameManager:
		GameManager.quest_changed.connect(_on_quest_changed)
		GameManager.quest_progress_updated.connect(_on_quest_progress_updated)
		GameManager.money_changed.connect(_on_money_changed)
		GameManager.xp_changed.connect(_on_xp_changed)
		GameManager.title_changed.connect(_on_title_changed)
		
		_refresh_quest_list()
		_on_money_changed(GameManager.player_money)
		_on_xp_changed(GameManager.player_xp)
		_on_title_changed(GameManager.player_title)
	_ensure_quest_notice_label()

func _refresh_quest_list():
	if not quest_container:
		return
		
	# Clear existing
	for child in quest_container.get_children():
		child.queue_free()
	
	if not GameManager:
		return
		
	# Get active quests from GameManager
	var active_quests = GameManager.get_active_quests()
	
	# Create quest boxes
	for quest in active_quests:
		var quest_box = QUEST_BOX.instantiate()
		quest_box.setup(quest)
		quest_container.add_child(quest_box)

func _on_quest_changed(quest_id: String, state: int):
	_refresh_quest_list()
	if state == Quest.QuestState.ACTIVE and AUTO_QUEST_NOTICES.has(quest_id):
		_show_quest_notice(str(AUTO_QUEST_NOTICES[quest_id]))

func _on_quest_progress_updated(quest_id: String, _progress: int):
	# Update specific quest box without full refresh
	for child in quest_container.get_children():
		if child.has_method("setup") and child.quest and child.quest.quest_id == quest_id:
			if child.has_method("_refresh"):
				child._refresh()
			return
	_refresh_quest_list()

func _on_money_changed(new_money: int):
	if currency_label:
		currency_label.text = str(new_money) + " NOK"

func _on_xp_changed(new_xp: int):
	if xp_label:
		if GameManager.player_level >= 5:
			xp_label.text = "MAX"
		else:
			xp_label.text = "LVL %d" % GameManager.player_level

func _on_title_changed(new_title: String):
	if title_label:
		if new_title != "":
			title_label.text = new_title
			title_label.show()
		else:
			title_label.hide()

func _ensure_quest_notice_label():
	if quest_notice_label != null:
		return
	quest_notice_label = Label.new()
	quest_notice_label.visible = false
	quest_notice_label.modulate = Color(1, 1, 1, 0)
	quest_notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quest_notice_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	quest_notice_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quest_notice_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quest_notice_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	quest_notice_label.offset_left = 140
	quest_notice_label.offset_top = 24
	quest_notice_label.offset_right = -140
	quest_notice_label.offset_bottom = 72
	quest_notice_label.add_theme_color_override("font_color", Color(1, 1, 0.85))
	quest_notice_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	quest_notice_label.add_theme_constant_override("shadow_offset_x", 1)
	quest_notice_label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(quest_notice_label)

func _show_quest_notice(text: String):
	_ensure_quest_notice_label()
	if quest_notice_label == null:
		return
	quest_notice_label.text = text
	quest_notice_label.visible = true
	quest_notice_label.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(quest_notice_label, "modulate:a", 1.0, 0.15)
	tween.tween_interval(2.0)
	tween.tween_property(quest_notice_label, "modulate:a", 0.0, 0.35)
	tween.finished.connect(func(): quest_notice_label.visible = false)
