# quest_box.gd
extends PanelContainer

@export var quest: Quest = null

@onready var title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var description_label: Label = $MarginContainer/VBoxContainer/BriefDescriptionLabel

var quest_id: String = ""

func setup(q: Quest):
	quest = q
	quest_id = q.quest_id
	
	# FIX: Wait for node to be ready
	await ready
	
	_refresh()
	
	# Connect to signals if GameManager exists
	if GameManager:
		GameManager.quest_progress_updated.connect(_on_quest_progress_updated)

func _refresh():
	if not quest:
		return
	
	# FIX: Add safety checks
	if not title_label or not description_label:
		return
	
	title_label.text = quest.name
	var desc := quest.description.strip_edges()
	description_label.text = desc if desc != "" else quest.brief_description
	
	# Styling based on state
	match quest.state:
		Quest.QuestState.COMPLETED:
			modulate = Color(0.5, 0.5, 0.5, 1)
		Quest.QuestState.ACTIVE:
			modulate = Color.WHITE

func _on_quest_progress_updated(p_quest_id: String, _progress: int):
	if quest and quest.quest_id == p_quest_id:
		_refresh()
