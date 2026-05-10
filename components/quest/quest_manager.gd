# quest_manager.gd - Wrapper around GameManager for compatibility
extends Node
class_name QuestSystem

signal quest_state_changed(quest_id: String, old_state: int, new_state: int)
signal objective_updated(quest_id: String, objective_id: String, progress: int)
signal quest_completed(quest_id: String)

var all_quests: Dictionary = {}
var _last_known_states: Dictionary = {}
const QUEST_RESOURCE_PATHS: Array[String] = [
	"res://data/quests/quest_01_grandpa_request.tres",
	"res://data/quests/quest_02_bank_inheritance.tres",
	"res://data/quests/quest_03_economic_reality.tres",
	"res://data/quests/quest_04_disappointment.tres",
	"res://data/quests/quest_05_scholarship_application.tres",
	"res://data/quests/quest_06_bank_deposit.tres",
	"res://data/quests/quest_07_second_icecream.tres",
	"res://data/quests/quest_08_final_delivery.tres",
	"res://data/quests/quest_kris_lua.tres",
	"res://data/quests/quest_09_iver_bevis.tres",
	"res://data/quests/quest_10_steinar_grus.tres"
]

func _ready():
	# Wait for GameManager
	await get_tree().process_frame
	_connect_game_manager_signals()
	_load_all_quests()
	_ensure_main_quest_started()

func _load_all_quests():
	all_quests.clear()
	if GameManager.has_method("get_quest_definition"):
		if GameManager.quest_registry.is_empty() and GameManager.has_method("_load_all_quest_definitions"):
			GameManager._load_all_quest_definitions()
		for quest_id in GameManager.quest_registry.keys():
			all_quests[quest_id] = GameManager.quest_registry[quest_id]
		if not all_quests.is_empty():
			_validate_loaded_quests()
			return

	for path in QUEST_RESOURCE_PATHS:
		var quest = ResourceLoader.load(path)
		if quest is Quest and quest.quest_id != "":
			all_quests[quest.quest_id] = quest
	_validate_loaded_quests()

func _ensure_main_quest_started():
	# Keep GRANDPA_REQUEST as an NPC-offered quest so Bestefar's offer dialogue plays first.
	pass

func update_available_quests():
	# This is handled by GameManager's quest requirements check
	pass

func accept_quest(quest_id: String) -> bool:
	var quest = all_quests.get(quest_id)
	if not quest:
		return false
	return GameManager.add_quest(quest, true)

func update_objective(quest_id: String, objective_id: String, amount: int = 1):
	GameManager.update_quest_objective(quest_id, objective_id, amount)

# Event handlers for automatic quest progression
func on_item_collected(item_id: String, amount: int = 1):
	if amount <= 0:
		return
	_update_matching_objectives(QuestObjective.ObjectiveType.GATHER_ITEM, item_id, amount)

func on_npc_talked(npc_id: String):
	_update_matching_objectives(QuestObjective.ObjectiveType.TALK_TO_NPC, npc_id, 1)

func on_location_visited(location_id: String):
	_update_matching_objectives(QuestObjective.ObjectiveType.VISIT_LOCATION, location_id, 1)

func on_item_purchased(item_id: String, amount: int = 1):
	if item_id == "icecream" and GameManager:
		GameManager.inheritance_spent_on_non_ice_cream = false
	if amount <= 0:
		return
	_update_matching_objectives(QuestObjective.ObjectiveType.PURCHASE_ITEM, item_id, amount)

func on_item_delivered(npc_id: String, item_id: String):
	var delivery_key = npc_id + ":" + item_id
	_update_matching_objectives(QuestObjective.ObjectiveType.DELIVER, delivery_key, 1, true)

func on_minigame_completed(minigame_id: String):
	_update_matching_objectives(QuestObjective.ObjectiveType.CUSTOM_ACTION, minigame_id, 1, true)
	_update_matching_objectives(QuestObjective.ObjectiveType.MINIGAME, minigame_id, 1, true)

func on_custom_action(action_id: String):
	_update_matching_objectives(QuestObjective.ObjectiveType.CUSTOM_ACTION, action_id, 1, true)

func on_form_filled(form_id: String):
	_update_matching_objectives(QuestObjective.ObjectiveType.FILL_FORM, form_id, 1, true)

func _update_matching_objectives(objective_type: int, target_id: String, amount: int = 1, allow_partial_match: bool = false):
	if amount <= 0:
		return
	for quest in GameManager.get_active_quests():
		quest.normalize_runtime_state()
		for objective in quest.objectives:
			if objective == null or objective.type != objective_type:
				continue
			if objective.objective_id == "":
				continue
			if objective.target_amount <= 0:
				continue
			if not _is_matching_target(objective.target_id, target_id, allow_partial_match):
				continue
			var current = int(quest.objective_progress.get(objective.objective_id, 0))
			if current >= objective.target_amount:
				continue
			update_objective(quest.quest_id, objective.objective_id, amount)

func _is_matching_target(objective_target_id: String, event_target_id: String, allow_partial_match: bool) -> bool:
	if objective_target_id == event_target_id:
		return true
	if allow_partial_match and objective_target_id.contains(":"):
		var parts = objective_target_id.split(":")
		return parts.has(event_target_id)
	return false

func _connect_game_manager_signals():
	if GameManager == null:
		return
	if not GameManager.quest_changed.is_connected(_on_game_manager_quest_changed):
		GameManager.quest_changed.connect(_on_game_manager_quest_changed)
	if not GameManager.quest_completed.is_connected(_on_game_manager_quest_completed):
		GameManager.quest_completed.connect(_on_game_manager_quest_completed)
	if not GameManager.quest_progress_updated.is_connected(_on_game_manager_quest_progress_updated):
		GameManager.quest_progress_updated.connect(_on_game_manager_quest_progress_updated)
	if not GameManager.item_added.is_connected(_on_game_manager_item_added):
		GameManager.item_added.connect(_on_game_manager_item_added)

func _on_game_manager_quest_changed(quest_id: String, new_state: int):
	var old_state = int(_last_known_states.get(quest_id, new_state))
	_last_known_states[quest_id] = new_state
	quest_state_changed.emit(quest_id, old_state, new_state)

func _on_game_manager_quest_completed(quest_id: String):
	_last_known_states[quest_id] = Quest.QuestState.COMPLETED
	quest_completed.emit(quest_id)

func _on_game_manager_quest_progress_updated(quest_id: String, _progress: float):
	var quest = GameManager.active_quests.get(quest_id)
	if quest == null:
		return
	quest.normalize_runtime_state()
	for objective in quest.objectives:
		if objective == null or objective.objective_id == "":
			continue
		var objective_progress = int(quest.objective_progress.get(objective.objective_id, 0))
		objective_updated.emit(quest_id, objective.objective_id, objective_progress)


func _on_game_manager_item_added(item_id: String, amount: int) -> void:
	if item_id == "fugleskinn" or item_id == "elgskinn" or item_id == "peak_performance_lua":
		return
	on_item_collected(item_id, amount)

func _validate_loaded_quests():
	for quest_id in all_quests.keys():
		var quest: Quest = all_quests[quest_id]
		if quest == null:
			push_warning("QuestSystem: Null quest entry for id %s" % quest_id)
			continue
		if quest.objectives.is_empty():
			push_warning("QuestSystem: Quest %s has no objectives." % quest_id)
			continue
		var objective_ids: Dictionary = {}
		for objective in quest.objectives:
			if objective == null:
				push_warning("QuestSystem: Quest %s contains a null objective." % quest_id)
				continue
			if objective.objective_id == "":
				push_warning("QuestSystem: Quest %s has objective without objective_id." % quest_id)
				continue
			if objective_ids.has(objective.objective_id):
				push_warning("QuestSystem: Quest %s has duplicate objective_id %s." % [quest_id, objective.objective_id])
				continue
			objective_ids[objective.objective_id] = true
			if objective.target_amount <= 0:
				push_warning("QuestSystem: Objective %s in %s has invalid target_amount <= 0." % [objective.objective_id, quest_id])
			if objective.target_id == "" and objective.type != QuestObjective.ObjectiveType.CUSTOM_ACTION:
				push_warning("QuestSystem: Objective %s in %s has empty target_id." % [objective.objective_id, quest_id])
