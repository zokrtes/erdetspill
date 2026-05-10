# UIStats.gd
extends HBoxContainer

const QUEST_BOX = preload("res://components/quest/quest_box.tscn")

@onready var quest_container: VBoxContainer = %QuestDisplay as VBoxContainer
@onready var currency_label: Label = $Stats/NOK
@onready var title_label: Label = $Stats/TitleLabel

func _ready():
	# Wait for GameManager
	await get_tree().process_frame
	if quest_container == null:
		quest_container = get_node_or_null("../../QuestHud/QuestPanel/QuestDisplay") as VBoxContainer

	# Connect to GameManager signals
	if GameManager:
		GameManager.quest_changed.connect(_on_quest_changed)
		GameManager.quest_progress_updated.connect(_on_quest_progress_updated)
		GameManager.money_changed.connect(_on_money_changed)
		GameManager.title_changed.connect(_on_title_changed)
		
		_refresh_quest_list()
		_on_money_changed(GameManager.player_money)
		_on_title_changed(GameManager.player_title)

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

func _on_quest_progress_updated(quest_id: String, _progress: int):
	if quest_container == null:
		return
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

func _on_title_changed(new_title: String):
	if title_label:
		if new_title != "":
			title_label.text = new_title
			title_label.show()
		else:
			title_label.hide()

