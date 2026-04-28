# game_manager.gd
extends Node

# ============================================
# SIGNALS
# ============================================
signal quest_changed(quest_id: String, state: int)
signal quest_completed(quest_id: String)
signal quest_progress_updated(quest_id: String, progress: int)
signal money_changed(new_amount: int)
signal xp_changed(new_xp: int)
signal level_up(new_level: int)
signal title_changed(new_title: String)
signal item_added(item_id: String, amount: int)
signal item_removed(item_id: String, amount: int)
signal inventory_changed(item_id: String, new_amount: int)
signal consumable_used(item_id: String)
signal item_use_blocked(item_id: String, code: String)
signal minigame_started(minigame_id: String)
signal minigame_ended(minigame_id: String, score: int)
signal gunshot_fired(position: Vector3, range: float)
signal day_changed(new_day: int)
signal power_outage_triggered

# ============================================
# PLAYER VARIABLES
# ============================================
## Set to false before export; when false, debug UI self-removes from levels.
var debug_mode: bool = true
var current_day: int = 1
var day_duration_seconds: float = 300.0
var power_is_out: bool = false
var player_name: String = "Sokrates"
var player_title: String = ""
var player_money: int = 0
var player_xp: int = 0
var player_level: int = 1

# ============================================
# COLLECTIONS
# ============================================
var inventory: Dictionary = {}  # item_id -> { "data": ItemData, "amount": int }
var active_quests: Dictionary = {}  # quest_id -> Quest
var completed_quests: Dictionary = {}  # quest_id -> bool
var failed_quests: Array[String] = []
var quest_registry: Dictionary = {}  # quest_id -> Quest definition
var freezer_icecream_count: int = 0
var bank_payout_claimed: Dictionary = {}  # quest_id -> bool
var active_minigame_id: String = ""
var dead_npcs: Array[String] = []
# tag: inheritance misuse — grandpa guilt if money spent before first ice cream (ECONOMIC_REALITY).
var inheritance_spent_on_non_ice_cream: bool = false
# tag: ice cream inflation — pricing depends on number purchased globally.
var ice_creams_purchased: int = 0

const SFX_ITEM_ADDED := preload("res://assets/sfx/hl1-master/sound/items/ammopickup1.wav")
const SFX_CASH_ADDED := preload("res://assets/sfx/hl1-master/sound/buttons/blip1.wav")
const SFX_CASH_REMOVED := preload("res://assets/sfx/hl1-master/sound/buttons/blip2.wav")

const MEDICAL_HEAL_ITEM_IDS: Array[String] = ["god_morgen_yoghurt", "painkillers"]
const XP_THRESHOLDS: Array[int] = [
	0,    # Level 1
	50,   # Level 2
	120,  # Level 3
	250,  # Level 4
	450   # Level 5
]
const DAMAGE_MULTIPLIERS: Array[float] = [
	1.0,  # Level 1
	1.2,  # Level 2
	1.5,  # Level 3
	1.85, # Level 4
	2.5   # Level 5
]
@export var quest_complete_sound: AudioStream
const QUEST_RESOURCE_PATHS: Array[String] = [
	"res://data/quests/quest_01_grandpa_request.tres",
	"res://data/quests/quest_02_bank_inheritance.tres",
	"res://data/quests/quest_03_economic_reality.tres",
	"res://data/quests/quest_04_disappointment.tres",
	"res://data/quests/quest_05_scholarship_application.tres",
	"res://data/quests/quest_06_bank_deposit.tres",
	"res://data/quests/quest_07_second_icecream.tres",
	"res://data/quests/quest_08_final_delivery.tres",
	"res://data/quests/quest_kris_lua.tres"
]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_ui_sfx_player()
	_load_all_quest_definitions()
	_validate_resources()


func _unhandled_input(event: InputEvent) -> void:
	if not debug_mode:
		return
	if event is InputEventKey and \
			event.pressed and not event.echo and \
			event.keycode == KEY_PAGEDOWN:
		_advance_day()


func _advance_day() -> void:
	current_day += 1
	day_changed.emit(current_day)
	print("DEBUG: Advanced to dag ", current_day)


func trigger_power_outage() -> void:
	if power_is_out:
		return
	power_is_out = true
	power_outage_triggered.emit()


func restore_power() -> void:
	power_is_out = false


func register_dead_npc(npc_id: String) -> void:
	if not dead_npcs.has(npc_id):
		dead_npcs.append(npc_id)
		print("💀 NPC dead: ", npc_id)


func is_npc_dead(npc_id: String) -> bool:
	return dead_npcs.has(npc_id)


func apply_weapon_damage_to_npc_collider(collider: Object, damage: float) -> bool:
	var n: Node = collider as Node
	while n:
		if n.is_in_group("NPC"):
			var hc: Node = n.get_node_or_null("HealthComponent")
			if hc is HealthComponent:
				var health := hc as HealthComponent
				if not health.is_dead:
					health.take_damage(damage)
					return true
			return false
		n = n.get_parent()
	return false

# ============================================
# MONEY SYSTEM
# ============================================
func set_money(amount: int):
	player_money = max(0, amount)
	money_changed.emit(player_money)

func add_money(_amount: int):
	push_warning("add_money is restricted. Use bank_transaction() or add_flat_money_reward().")

func add_flat_money_reward(amount: int):
	if amount <= 0:
		return
	player_money += amount
	money_changed.emit(player_money)
	_play_ui_sfx(SFX_CASH_ADDED)
	print("💰 Added %d money. Total: %d" % [amount, player_money])

func bank_transaction(amount: int, source: String) -> bool:
	if source != "bank_teller":
		push_warning("Blocked bank_transaction from source: %s" % source)
		return false
	if amount <= 0:
		return false
	add_flat_money_reward(amount)
	return true

func bank_document_payout(quest_id: String, amount: int, source: String = "bank_teller") -> bool:
	if bank_payout_claimed.get(quest_id, false):
		return false
	if not bank_transaction(amount, source):
		return false
	bank_payout_claimed[quest_id] = true
	return true

func remove_money(amount: int, spend_context: String = "general") -> bool:
	if player_money >= amount:
		player_money -= amount
		money_changed.emit(player_money)
		_play_ui_sfx(SFX_CASH_REMOVED)
		_maybe_flag_inheritance_mis_spending(spend_context)
		print("💰 Removed %d money. Total: %d" % [amount, player_money])
		return true
	print("❌ Not enough money! Need %d, have %d" % [amount, player_money])
	return false


func _maybe_flag_inheritance_mis_spending(spend_context: String) -> void:
	if spend_context == "icecream":
		return
	if spend_context == "death_penalty":
		return
	if not bank_payout_claimed.get("BANK_INHERITANCE", false):
		return
	if is_quest_completed("ECONOMIC_REALITY"):
		return
	inheritance_spent_on_non_ice_cream = true

func has_enough_money(amount: int) -> bool:
	return player_money >= amount

func get_icecream_price() -> int:
	match ice_creams_purchased:
		0:
			return 100
		1:
			return 200
		_:
			return 250

func on_icecream_purchased() -> void:
	ice_creams_purchased += 1

# ============================================
# XP AND LEVEL SYSTEM
# ============================================
func set_xp(amount: int):
	player_xp = max(0, amount)
	xp_changed.emit(player_xp)
	_check_level_up()

func add_xp(amount: int):
	if amount <= 0:
		return
	player_xp += amount
	xp_changed.emit(player_xp)
	print("✨ +%d XP (total: %d)" % [amount, player_xp])
	_check_level_up()

func _check_level_up():
	while player_level < XP_THRESHOLDS.size() and player_xp >= XP_THRESHOLDS[player_level]:
		player_level += 1
		level_up.emit(player_level)
		print("🎉 LEVEL UP! Now level ", player_level)
		print("💥 Damage multiplier: ", get_damage_multiplier(), "x")

func get_damage_multiplier() -> float:
	var idx := clamp(player_level - 1, 0, DAMAGE_MULTIPLIERS.size() - 1)
	return DAMAGE_MULTIPLIERS[idx]

func get_xp_progress() -> float:
	if player_level >= XP_THRESHOLDS.size():
		return 1.0
	var current_threshold: int = XP_THRESHOLDS[player_level - 1]
	var next_threshold: int = XP_THRESHOLDS[player_level]
	if next_threshold <= current_threshold:
		return 1.0
	return clamp(
		float(player_xp - current_threshold) / float(next_threshold - current_threshold),
		0.0,
		1.0
	)

# ============================================
# TITLE SYSTEM
# ============================================
func set_title(title: String):
	player_title = title
	title_changed.emit(player_title)
	print("🏆 Title set: ", title)

func add_title(title: String):
	if player_title == "":
		player_title = title
	else:
		# Unngå duplikater
		if not player_title.contains(title):
			player_title += " | " + title
	title_changed.emit(player_title)
	print("🏆 Title awarded: ", title)

func has_title(title: String) -> bool:
	return player_title.contains(title)

func clear_titles():
	player_title = ""
	title_changed.emit(player_title)

# ============================================
# INVENTORY SYSTEM
# ============================================
func add_item(item_id: String, amount: int = 1):
	if amount <= 0:
		return
	var item_data := _load_item_data(item_id)
	if item_data == null:
		push_warning("Item resource not found for item_id: %s" % item_id)
		return

	var previous_amount = get_item_count(item_id)
	var max_stack = max(1, item_data.max_stack)
	var next_amount = previous_amount + amount
	if item_data.stackable:
		next_amount = min(next_amount, max_stack)
	else:
		next_amount = 1

	inventory[item_id] = {
		"data": item_data,
		"amount": next_amount
	}
	var added_amount = max(0, next_amount - previous_amount)
	if added_amount > 0:
		_play_ui_sfx(SFX_ITEM_ADDED)
		item_added.emit(item_id, added_amount)
	inventory_changed.emit(item_id, next_amount)
	print("📦 Added %d x %s to inventory" % [added_amount, item_id])


var _ui_sfx_player: AudioStreamPlayer


func _setup_ui_sfx_player() -> void:
	if _ui_sfx_player != null:
		return
	_ui_sfx_player = AudioStreamPlayer.new()
	_ui_sfx_player.name = "UISfxPlayer"
	_ui_sfx_player.bus = "Master"
	_ui_sfx_player.volume_db = -6.0
	add_child(_ui_sfx_player)


func _play_ui_sfx(stream: AudioStream) -> void:
	if stream == null:
		return
	if _ui_sfx_player == null:
		_setup_ui_sfx_player()
	_ui_sfx_player.stream = stream
	_ui_sfx_player.play()

func add_icecream_to_freezer(amount: int = 1):
	freezer_icecream_count += max(0, amount)

func get_freezer_icecream_count() -> int:
	return freezer_icecream_count

func remove_item(item_id: String, amount: int = 1) -> bool:
	if not inventory.has(item_id):
		return false

	var current_amount = int(inventory[item_id].get("amount", 0))
	if current_amount >= amount:
		current_amount -= amount
		item_removed.emit(item_id, amount)
		print("📦 Removed %d x %s from inventory" % [amount, item_id])

		if current_amount <= 0:
			inventory.erase(item_id)
			inventory_changed.emit(item_id, 0)
		else:
			inventory[item_id]["amount"] = current_amount
			inventory_changed.emit(item_id, current_amount)
		return true
	
	print("❌ Not enough %s! Have %d, need %d" % [item_id, current_amount, amount])
	return false

func get_item_count(item_id: String) -> int:
	if not inventory.has(item_id):
		return 0
	return int(inventory[item_id].get("amount", 0))

func has_item(item_id: String, amount: int = 1) -> bool:
	return get_item_count(item_id) >= amount

func use_item(item_id: String) -> bool:
	if not inventory.has(item_id):
		return false
	var slot = inventory[item_id]
	var data: ItemData = slot.get("data")
	if data == null:
		push_warning("Item slot missing data for %s" % item_id)
		return false
	match data.category:
		ItemData.Category.CONSUMABLE:
			if _is_medical_heal_item(item_id) and _player_health_is_full():
				item_use_blocked.emit(item_id, "full_health")
				return false
			if remove_item(item_id, 1):
				consumable_used.emit(item_id)
				_on_item_used(item_id)
				return true
			return false
		ItemData.Category.QUEST_ITEM:
			push_warning("Quest item cannot be used directly: %s" % item_id)
			return false
		ItemData.Category.AMMO:
			push_warning("Ammo is handled by weapon system: %s" % item_id)
			return false
	return false

func _is_medical_heal_item(item_id: String) -> bool:
	return MEDICAL_HEAL_ITEM_IDS.has(item_id)

func _player_health_is_full() -> bool:
	var tree := get_tree()
	if tree == null:
		return false
	var player := tree.get_first_node_in_group("PlayerCharacter")
	if player == null:
		return false
	var hc = player.get_node_or_null("HealthComponent")
	if hc == null:
		return false
	return float(hc.current_health) >= float(hc.max_health)

# ============================================
# QUEST SYSTEM - HELPER FUNCTIONS
# ============================================
func _check_quest_requirements(quest: Quest) -> bool:
	# Check required quests
	for required_id in quest.required_quest_ids:
		if not completed_quests.has(required_id):
			print("Missing required quest: ", required_id)
			return false
	
	# Check required items
	for item_id in quest.required_items:
		if not has_item(item_id):
			print("Missing required item: ", item_id)
			return false
	
	# Check required money
	if quest.required_money > 0 and player_money < quest.required_money:
		print("Missing required money: Need ", quest.required_money, " have ", player_money)
		return false
	
	return true

# ============================================
# QUEST SYSTEM - MAIN METHODS
# ============================================
func add_quest(quest: Quest, auto_start: bool = true):
	# Check if quest already completed
	if completed_quests.has(quest.quest_id):
		print("Quest already completed: ", quest.quest_id)
		return false
	
	# Check if quest already active
	if active_quests.has(quest.quest_id):
		print("Quest already active: ", quest.quest_id)
		return false
	
	# Check requirements
	if not _check_quest_requirements(quest):
		print("Quest requirements not met: ", quest.quest_id)
		return false
	
	var quest_instance = quest.duplicate(true)
	quest_instance.normalize_runtime_state()
	
	if auto_start:
		quest_instance.state = Quest.QuestState.ACTIVE
		# Initialize objective progress only for missing keys (keeps migrated progress intact).
		for objective in quest_instance.objectives:
			if objective != null and objective.objective_id != "" and not quest_instance.objective_progress.has(objective.objective_id):
				quest_instance.objective_progress[objective.objective_id] = 0
		if quest_instance.objectives.is_empty():
			quest_instance.current_progress = 0
	
	active_quests[quest_instance.quest_id] = quest_instance
	quest_changed.emit(quest_instance.quest_id, quest_instance.state)
	print("📜 Quest added: ", quest_instance.name)
	return true

func update_quest_progress(quest_id: String, amount: int = 1):
	if not active_quests.has(quest_id):
		return
	
	var quest = active_quests[quest_id]
	quest.normalize_runtime_state()
	if quest.state != Quest.QuestState.ACTIVE:
		return
	
	# Update first objective by default (legacy support)
	if quest.objectives.is_empty():
		quest.current_progress += amount
		quest_progress_updated.emit(quest_id, quest.current_progress)
		print("📈 Quest progress: ", quest.name, " - ", quest.current_progress, "/", quest.target_amount)
		
		if quest.current_progress >= quest.target_amount:
			complete_quest(quest)
	else:
		# Update the first objective
		var first_objective = quest.objectives[0]
		quest.update_objective(first_objective.objective_id, amount)
		quest_progress_updated.emit(quest_id, quest.get_total_progress())
		
		if quest.is_complete():
			complete_quest(quest)

func update_quest_objective(quest_id: String, objective_id: String, amount: int = 1):
	if not active_quests.has(quest_id):
		return
	
	var quest = active_quests[quest_id]
	quest.normalize_runtime_state()
	if quest.state != Quest.QuestState.ACTIVE:
		return
	
	quest.update_objective(objective_id, amount)
	quest_progress_updated.emit(quest_id, quest.get_total_progress())
	
	if quest.is_complete():
		complete_quest(quest)

func complete_quest(quest: Quest):
	print("Completing quest: ", quest.name)
	print("Reward items: ", quest.reward_items)
	print("✅ Quest completed: ", quest.name)
	
	quest.state = Quest.QuestState.COMPLETED
	completed_quests[quest.quest_id] = true
	
	# Give rewards
	if quest.reward_money > 0:
		if _has_document_reward(quest):
			push_warning("Quest %s has document reward item and money reward; skipping direct money reward." % quest.quest_id)
		else:
			add_flat_money_reward(quest.reward_money)
	add_xp(quest.reward_xp)
	
	for item_id in quest.reward_items:
		if item_id is String and item_id != "":
			add_item(item_id, 1)
	
	if quest.reward_title != "":
		add_title(quest.reward_title)
	_play_quest_complete_sound()
	
	# AUTO-START unlocked quests
	for next_quest_id in quest.unlock_quests:
		print("🔓 Auto-starting unlocked quest: ", next_quest_id)
		var next_quest = _load_quest_by_id(next_quest_id)
		if next_quest:
			add_quest(next_quest, true)
	
	active_quests.erase(quest.quest_id)
	quest_completed.emit(quest.quest_id)
	quest_changed.emit(quest.quest_id, Quest.QuestState.COMPLETED)

func _play_quest_complete_sound() -> void:
	var player = get_tree().get_first_node_in_group("PlayerCharacter")
	if player == null:
		return
	var audio := AudioStreamPlayer.new()
	player.add_child(audio)
	audio.bus = "Sfx"
	if quest_complete_sound != null:
		audio.stream = quest_complete_sound
	elif ResourceLoader.exists("res://assets/sfx/erdetlyd/quest_complete.ogg"):
		audio.stream = load("res://assets/sfx/erdetlyd/quest_complete.ogg")
	else:
		audio.queue_free()
		return
	audio.play()
	audio.finished.connect(func(): audio.queue_free())

func end_minigame(minigame_id: String, score):
	minigame_ended.emit(minigame_id, int(score))
	if active_minigame_id == minigame_id:
		active_minigame_id = ""
	if score <= 0:
		return
	var quest_system = _get_quest_system_node()
	if quest_system and quest_system.has_method("on_minigame_completed"):
		quest_system.on_minigame_completed(minigame_id)

func start_minigame(minigame_id: String) -> bool:
	if active_minigame_id != "" and active_minigame_id != minigame_id:
		push_warning("Cannot start minigame '%s'. Active minigame: '%s'" % [minigame_id, active_minigame_id])
		return false
	active_minigame_id = minigame_id
	minigame_started.emit(minigame_id)
	return true

func is_minigame_active() -> bool:
	return active_minigame_id != ""

func _load_quest_by_id(quest_id: String):
	var from_registry = quest_registry.get(quest_id)
	if from_registry:
		return from_registry
	return _load_legacy_quest_by_id(quest_id)

func _load_all_quest_definitions():
	quest_registry.clear()
	for resource_path in QUEST_RESOURCE_PATHS:
		var quest = ResourceLoader.load(resource_path)
		if not (quest is Quest):
			push_warning("Failed to load quest resource: " + resource_path)
			continue
		if quest.quest_id == "":
			push_warning("Quest resource missing quest_id: " + resource_path)
			continue
		if quest_registry.has(quest.quest_id):
			push_warning("Duplicate quest_id '%s' in %s" % [quest.quest_id, resource_path])
			continue
		quest_registry[quest.quest_id] = quest

func _load_legacy_quest_by_id(quest_id: String):
	var legacy_files = {
		"GRANDPA_REQUEST": "res://data/quests/quest_01_grandpa_request.tres",
		"BANK_INHERITANCE": "res://data/quests/quest_02_bank_inheritance.tres",
		"ECONOMIC_REALITY": "res://data/quests/quest_03_economic_reality.tres",
		"GRANDPA_DISAPPOINTMENT": "res://data/quests/quest_04_disappointment.tres",
		"SCHOLARSHIP_APPLICATION": "res://data/quests/quest_05_scholarship_application.tres",
		"BANK_DEPOSIT": "res://data/quests/quest_06_bank_deposit.tres",
		"SECOND_ICECREAM": "res://data/quests/quest_07_second_icecream.tres",
		"FINAL_DELIVERY": "res://data/quests/quest_08_final_delivery.tres"
	}
	var path = legacy_files.get(quest_id, "")
	if path != "":
		var quest = ResourceLoader.load(path)
		if quest is Quest:
			return quest
	return null

func get_quest_definition(quest_id: String) -> Quest:
	return _load_quest_by_id(quest_id)

func get_active_quests() -> Array:
	var result: Array = []
	for quest in active_quests.values():
		result.append(quest)
	return result

func is_quest_completed(quest_id: String) -> bool:
	return completed_quests.has(quest_id)

func has_active_quest(quest_id: String) -> bool:
	return active_quests.has(quest_id)

func _get_quest_system_node() -> Node:
	var root = get_tree().root
	if root.has_node("QuestSystem"):
		return root.get_node("QuestSystem")
	var current_scene = get_tree().current_scene
	if current_scene and current_scene.has_node("QuestManager"):
		return current_scene.get_node("QuestManager")
	return null

func _has_document_reward(quest: Quest) -> bool:
	for item_id in quest.reward_items:
		if not (item_id is String):
			continue
		if item_id.contains("document") or item_id.contains("application"):
			return true
	return false

func _on_item_used(item_id: String):
	print("Used item: %s" % item_id)

func _load_item_data(item_id: String) -> ItemData:
	var path = "res://data/items/%s.tres" % item_id
	var loaded = ResourceLoader.load(path)
	if loaded is ItemData:
		return loaded
	# Exported builds can remap text resources, so FileAccess checks can be misleading.
	print("Failed to load ItemData for: ", item_id, " path: ", path)
	return null

func _validate_resources():
	print("=== RESOURCE VALIDATION ===")
	print("Quests loaded: ", quest_registry.size())
	for quest_id in quest_registry:
		print("  ✓ ", quest_id)

	var item_ids = [
		"icecream", "inheritance_document",
		"approved_application", "god_morgen_yoghurt", "painkillers"
	]
	for item_id in item_ids:
		var path = "res://data/items/%s.tres" % item_id
		var item = ResourceLoader.load(path)
		if item == null:
			push_warning("  ✗ MISSING ITEM: " + item_id)
		else:
			print("  ✓ item: ", item_id)
	print("===========================")

# ============================================
# HELPER FUNCTIONS
# ============================================
func reset_game():
	current_day = 1
	power_is_out = false
	player_money = 0
	player_xp = 0
	player_level = 1
	player_title = ""
	inventory.clear()
	active_quests.clear()
	completed_quests.clear()
	failed_quests.clear()
	freezer_icecream_count = 0
	bank_payout_claimed.clear()
	inheritance_spent_on_non_ice_cream = false
	ice_creams_purchased = 0
	active_minigame_id = ""
	dead_npcs.clear()
	
	# Emit reset signals
	money_changed.emit(0)
	xp_changed.emit(0)
	title_changed.emit("")
	
	print("🔄 Game reset complete")

func get_stats() -> Dictionary:
	return {
		"name": player_name,
		"title": player_title,
		"money": player_money,
		"xp": player_xp,
		"level": player_level,
		"active_quests": active_quests.size(),
		"completed_quests": completed_quests.size(),
		"inventory_size": inventory.size()
	}

func print_status():
	print("\n=== PLAYER STATUS ===")
	print("Name: ", player_name)
	print("Title: ", player_title if player_title != "" else "None")
	print("Money: ", player_money, " NOK")
	print("XP: ", player_xp, " (Level ", player_level, ")")
	print("Active quests: ", active_quests.size())
	print("Completed quests: ", completed_quests.size())
	print("Inventory items: ", inventory.size())
	
	if active_quests.size() > 0:
		print("\n--- Active Quests ---")
		for quest in active_quests.values():
			print("  - ", quest.name, ": ", quest.current_progress, "/", quest.target_amount)
	
	if inventory.size() > 0:
		print("\n--- Inventory ---")
		for item_id in inventory:
			print("  - ", item_id, ": ", int(inventory[item_id].get("amount", 0)))
	print("=====================\n")
