# quest.gd
extends Resource
class_name Quest

enum QuestType { GATHER, TALK, MINIGAME, SHOPPING, INTERNAL, APPLICATION, DELIVER }
enum QuestState { LOCKED, AVAILABLE, ACTIVE, COMPLETED, FAILED }

@export_category("Basic Info")
@export var quest_id: String = ""
@export var name: String = ""
@export_multiline var description: String = ""
@export var brief_description: String = ""
@export var quest_type: QuestType = QuestType.GATHER

@export_category("Requirements")
@export var required_quest_ids: Array[String] = []
@export var required_items: Array[String] = []
@export var required_money: int = 0

@export_category("Objectives")
@export var objectives: Array[QuestObjective] = []

@export_category("Rewards")
@export var reward_money: int = 0
@export var reward_items: Array[String] = []
@export var reward_title: String = ""
@export var unlock_quests: Array[String] = []

@export_category("Dialogue")
@export var offer_dialogue: Array[String] = []
@export var completion_dialogue: Array[String] = []
## When non-empty, NPC dialogue uses these (text + optional sound per line). Otherwise falls back to string-only `offer_dialogue` / `completion_dialogue`.
@export var offer_lines: Array[DialogueLine] = []
@export var completion_lines: Array[DialogueLine] = []

# Runtime state
var state: QuestState = QuestState.LOCKED
var objective_progress: Dictionary = {}  # objective_id -> current_progress

# Legacy support for old system
var target_amount: int = 1
var current_progress: int = 0:
	set(value):
		current_progress = value
		# Also update first objective if exists and using legacy mode
		if objectives.size() > 0 and objectives[0].target_amount > 0:
			objective_progress[objectives[0].objective_id] = value

func normalize_runtime_state():
	if objective_progress == null:
		objective_progress = {}

	if objectives.is_empty():
		# Legacy quest mode still relies on scalar progress values.
		current_progress = max(0, current_progress)
		target_amount = max(1, target_amount)
		return

	var first_objective_id = objectives[0].objective_id
	var has_any_progress = false
	for key in objective_progress.keys():
		if int(objective_progress[key]) > 0:
			has_any_progress = true
			break

	for objective in objectives:
		if objective == null:
			continue
		var objective_id = objective.objective_id
		if objective_id == "":
			continue
		var value = int(objective_progress.get(objective_id, 0))
		var clamped = clamp(value, 0, max(1, objective.target_amount))
		objective_progress[objective_id] = clamped

	if not has_any_progress and current_progress > 0 and first_objective_id != "":
		objective_progress[first_objective_id] = clamp(current_progress, 0, max(1, objectives[0].target_amount))

	if first_objective_id != "":
		current_progress = int(objective_progress.get(first_objective_id, 0))
	target_amount = max(1, objectives[0].target_amount)

func get_required_quest_ids() -> Array[String]:
	return required_quest_ids

func get_total_progress() -> float:
	if objectives.is_empty():
		return float(current_progress) / float(target_amount) if target_amount > 0 else 1.0
	
	var total = 0.0
	for objective in objectives:
		var current = objective_progress.get(objective.objective_id, 0)
		if objective.target_amount > 0:
			total += float(current) / float(objective.target_amount)
	return total / float(objectives.size()) if objectives.size() > 0 else 1.0

func is_complete() -> bool:
	if objectives.is_empty():
		return current_progress >= target_amount
	
	for objective in objectives:
		var current = objective_progress.get(objective.objective_id, 0)
		if current < objective.target_amount:
			return false
	return true

func update_objective(objective_id: String, amount: int = 1) -> bool:
	if state != QuestState.ACTIVE:
		return false

	var objective = _get_objective_by_id(objective_id)
	if not objective:
		return false

	if not objective_progress.has(objective_id):
		objective_progress[objective_id] = 0

	var new_progress = min(int(objective_progress[objective_id]) + amount, objective.target_amount)
	objective_progress[objective_id] = new_progress
	
	# Legacy support
	if objectives.size() > 0 and objectives[0].objective_id == objective_id:
		current_progress = new_progress
	
	return new_progress >= objective.target_amount

func _get_objective_by_id(objective_id: String) -> QuestObjective:
	for obj in objectives:
		if obj.objective_id == objective_id:
			return obj
	return null

func reset_progress():
	current_progress = 0
	objective_progress.clear()
	for objective in objectives:
		if objective != null and objective.objective_id != "":
			objective_progress[objective.objective_id] = 0
