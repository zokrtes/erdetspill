extends Node3D

const NPC_DEATH_VFX: PackedScene = preload("res://scenes/vfx/npc_death_vfx.tscn")
const HAPPINESS_VFX: PackedScene = preload("res://scenes/vfx/happiness_vfx.tscn")
const ENDING_OVERLAY: PackedScene = preload("res://scenes/ui/ending_overlay.tscn")

@export_group("Identity")
@export var npc_id: String = ""
@export var npc_name: String = "NPC"
@export var character_model: PackedScene = preload("res://assets/props/Characters_psx/Models/Male/Character_06.fbx")

@export_group("Quests")
@export var quests: Array[Quest] = []

@export_group("Dialogue")
@export var idle_dialogue: Array[String] = []

@export_group("Bank")
@export var bank_teller_mode: bool = false

@export_group("Payoff")
@export var happy_sound: AudioStream = null

var model_mesh: MeshInstance3D
var model_root: Node3D
var interaction_area: Area3D
var name_label: Label3D
var health_component: Node

var in_range: bool = false
var current_quest: Quest = null
var is_dead: bool = false
var _player_ref: Node3D = null

func _ready() -> void:
	model_root = get_node_or_null("Model") as Node3D
	_setup_model()
	model_mesh = _find_mesh(model_root)
	name_label = _resolve_name_label()
	interaction_area = get_node_or_null("InteractionArea") as Area3D
	if interaction_area == null:
		interaction_area = get_node_or_null("Area3D") as Area3D
	health_component = get_node_or_null("HealthComponent")

	if name_label:
		name_label.text = "E — " + npc_name
		name_label.visible = false

	if interaction_area:
		interaction_area.body_entered.connect(_on_area_3d_body_entered)
		interaction_area.body_exited.connect(_on_area_3d_body_exited)

	if health_component:
		health_component.on_death.connect(_on_npc_death)
		add_to_group("NPC")

	print("✓ NPC ready: ", npc_name, " [", npc_id, "] quests: ", quests.size())


func _process(delta: float) -> void:
	if is_dead:
		return
	if GameManager.is_npc_dead(npc_id):
		return
	if _player_ref == null or not is_instance_valid(_player_ref):
		_player_ref = get_tree().get_first_node_in_group("PlayerCharacter") as Node3D
	if _player_ref == null:
		return
	var to_player := _player_ref.global_position - global_position
	to_player.y = 0.0
	if to_player.length_squared() <= 0.0001:
		return
	var desired := atan2(-to_player.x, -to_player.z)
	rotation.y = lerp_angle(rotation.y, desired, clamp(delta * 6.0, 0.0, 1.0))


func _resolve_name_label() -> Label3D:
	var l := get_node_or_null("NameLabel") as Label3D
	if l:
		return l
	return get_node_or_null("Area3D/Label3D") as Label3D


func _setup_model() -> void:
	# tag: character scale standard — all humanoids target 1.95m.
	if character_model == null:
		return
	if model_root == null:
		return
	for child in model_root.get_children():
		child.queue_free()
	var instance := character_model.instantiate()
	model_root.add_child(instance)
	var mesh_instance := _find_mesh(instance)
	if mesh_instance == null:
		return
	var aabb := mesh_instance.get_aabb()
	if aabb.size.y <= 0.0:
		return
	var factor := 1.95 / aabb.size.y
	if instance is Node3D:
		var model_3d := instance as Node3D
		model_3d.scale = Vector3(factor, factor, factor)
		model_3d.rotation_degrees.y = 180.0
		model_3d.position = Vector3(
			-(aabb.position.x + (aabb.size.x * 0.5)) * factor,
			-(aabb.position.y + (aabb.size.y * 0.5)) * factor,
			-(aabb.position.z + (aabb.size.z * 0.5)) * factor
		)


func _find_mesh(node: Node) -> MeshInstance3D:
	if node == null:
		return null
	if node is MeshInstance3D:
		return node as MeshInstance3D
	for child in node.get_children():
		var found := _find_mesh(child)
		if found != null:
			return found
	return null


func _input(_event: InputEvent) -> void:
	if is_dead:
		return
	if GameManager.is_npc_dead(npc_id):
		return
	if not in_range:
		return
	if GameManager.has_method("is_minigame_active") and GameManager.is_minigame_active():
		return
	if DialogueUI.is_open():
		return

	if Input.is_action_just_pressed("interaction"):
		_interact()


func _interact() -> void:
	if is_dead:
		return
	if GameManager.is_npc_dead(npc_id):
		return
	if DialogueUI.is_open():
		return

	print("=== INTERACT with ", npc_name, " ===")

	if bank_teller_mode:
		_show_bank_menu()
		return

	if npc_id == "grandpa" and GameManager.inheritance_spent_on_non_ice_cream:
		DialogueUI.show_dialogue(
			[
				"du kjøpte ikke is? da får du gjøre som i gamle dager, selg lemonade, bygg standet ute"
			],
			"Bestefar",
			Callable()
		)
		return

	var npc_active_quests = _get_active_quests_for_npc()
	if not npc_active_quests.is_empty():
		for quest in npc_active_quests:
			if quest.is_complete():
				if _can_turn_in_quest(quest):
					_show_completion_and_turn_in(quest)
				else:
					DialogueUI.show_dialogue(_get_turn_in_blocked_dialogue(quest), npc_name, Callable())
				return
		var first_quest = npc_active_quests[0]
		DialogueUI.show_dialogue(
			_dialogue_or_fallback(first_quest.offer_dialogue, ["*du snakker med " + npc_name + "*"]),
			npc_name,
			func():
				var changed = _update_talk_objective_if_needed(first_quest)
				if changed and first_quest.is_complete():
					if _can_turn_in_quest(first_quest):
						_prepare_turn_in_rewards(first_quest)
						GameManager.complete_quest(first_quest)
						quests.erase(first_quest)
					else:
						push_warning("Quest %s complete but turn-in requirements not met." % first_quest.quest_id)
		)
		return

	var available_quests = _get_available_quests()
	if available_quests.is_empty():
		print("No available quests")
		if bank_teller_mode:
			_show_bank_menu()
			return
		var lines := idle_dialogue
		if lines.is_empty():
			lines = ["Hei, " + npc_name + " har ingenting til deg akkurat nå."]
		DialogueUI.show_dialogue(lines, npc_name, Callable())
	else:
		print("Offering new quest: ", available_quests[0].name)
		_offer_quest(available_quests[0])


func _is_quest_available(quest: Quest) -> bool:
	if not GameManager:
		return false

	if GameManager.is_quest_completed(quest.quest_id):
		print("  ", quest.name, " - already completed")
		return false

	if GameManager.has_active_quest(quest.quest_id):
		print("  ", quest.name, " - already active")
		return false

	for required_id in quest.required_quest_ids:
		if not GameManager.is_quest_completed(required_id):
			print("  ", quest.name, " - missing required quest: ", required_id)
			return false

	print("  ", quest.name, " - AVAILABLE")
	return true


func _get_available_quests() -> Array[Quest]:
	var available: Array[Quest] = []
	for quest in quests:
		if _is_quest_available(quest):
			available.append(quest)
	return available


func _offer_quest(quest: Quest) -> void:
	current_quest = quest

	var quest_dialogue = _dialogue_or_fallback(
		quest.offer_dialogue,
		["Vil du akseptere oppdraget: " + quest.name + "?"]
	)

	DialogueUI.show_dialogue(
		quest_dialogue,
		npc_name,
		func():
			print("Adding quest: ", current_quest.name)
			var offered_quest_id = current_quest.quest_id
			var accepted = GameManager.add_quest(current_quest)
			if accepted:
				var active_quest: Quest = GameManager.active_quests.get(offered_quest_id)
				if active_quest != null and _update_talk_objective_if_needed(active_quest) and active_quest.is_complete() and _can_turn_in_quest(active_quest):
					_prepare_turn_in_rewards(active_quest)
					GameManager.complete_quest(active_quest)
					quests.erase(current_quest)
			current_quest = null
	)


func _get_active_quests_for_npc() -> Array[Quest]:
	var matches: Array[Quest] = []
	for quest in GameManager.get_active_quests():
		if _quest_targets_this_npc(quest):
			matches.append(quest)
	return matches


func _quest_targets_this_npc(quest: Quest) -> bool:
	for objective in quest.objectives:
		if objective == null:
			continue
		if objective.type == QuestObjective.ObjectiveType.TALK_TO_NPC and objective.target_id == npc_id:
			return true
	if quest.quest_id == "FINAL_DELIVERY" and npc_id == "grandpa":
		return true
	return false


func _update_talk_objective_if_needed(quest: Quest) -> bool:
	var changed = false
	for objective in quest.objectives:
		if objective == null:
			continue
		if objective.type != QuestObjective.ObjectiveType.TALK_TO_NPC:
			continue
		if objective.target_id != npc_id:
			continue
		var current = int(quest.objective_progress.get(objective.objective_id, 0))
		if current < objective.target_amount:
			quest.update_objective(objective.objective_id, 1)
			GameManager.quest_progress_updated.emit(quest.quest_id, quest.get_total_progress())
			changed = true
	return changed


func _can_turn_in_quest(quest: Quest) -> bool:
	if quest.quest_id == "FINAL_DELIVERY":
		return GameManager.has_item("icecream", 2)
	return true


func _get_turn_in_blocked_dialogue(quest: Quest) -> Array[String]:
	if quest.quest_id == "FINAL_DELIVERY":
		return [
			"Du mangler fortsatt is til leveringen.",
			"Kom tilbake når du har minst to is."
		]
	return ["Du mangler fortsatt noe før dette kan leveres inn."]


func _show_completion_and_turn_in(quest: Quest) -> void:
	var completion_dialogue = _dialogue_or_fallback(quest.completion_dialogue, ["Oppdrag fullført!"])
	if quest.quest_id == "FINAL_DELIVERY":
		DialogueUI.show_dialogue(
			completion_dialogue,
			npc_name,
			func():
				if GameManager.is_quest_completed("FINAL_DELIVERY"):
					return
				_prepare_turn_in_rewards(quest)
				GameManager.complete_quest(quest)
				quests.erase(quest)
				call_deferred("_begin_final_delivery_payoff")
		)
		return
	DialogueUI.show_dialogue(
		completion_dialogue,
		npc_name,
		func():
			if not GameManager.is_quest_completed(quest.quest_id):
				_prepare_turn_in_rewards(quest)
				GameManager.complete_quest(quest)
				quests.erase(quest)
	)


func _begin_final_delivery_payoff() -> void:
	await _play_final_delivery_payoff()


func _play_final_delivery_payoff() -> void:
	# tag: FINAL_DELIVERY payoff — flash, VFX, title, ending overlay.
	_freeze_player_payoff(true)
	_flash_mesh_warm_yellow()
	_spawn_happiness_vfx()
	_play_happy_sound()
	GameManager.add_title("Isens Utvalgte")
	var root: Node = get_tree().current_scene
	if root == null:
		root = get_tree().root
	var overlay: Node = ENDING_OVERLAY.instantiate()
	root.add_child(overlay)
	if overlay.has_method("run_sequence"):
		await overlay.run_sequence()
	_freeze_player_payoff(false)


func _freeze_player_payoff(locked: bool) -> void:
	var player := get_tree().get_first_node_in_group("PlayerCharacter")
	if player and player.has_method("freeze_for_dialogue"):
		player.freeze_for_dialogue(locked)
	if player and player.has_method("set_weapon_active"):
		player.set_weapon_active(not locked)


func _flash_mesh_warm_yellow() -> void:
	if model_root == null:
		return
	var tw := create_tween()
	tw.tween_property(model_root, "scale", Vector3(1.04, 1.04, 1.04), 0.14)
	tw.tween_property(model_root, "scale", Vector3.ONE, 0.42)


func _spawn_happiness_vfx() -> void:
	var vfx: Node = HAPPINESS_VFX.instantiate()
	var root: Node = get_tree().current_scene
	if root:
		root.add_child(vfx)
	else:
		get_tree().root.add_child(vfx)
	if vfx.has_method("play"):
		vfx.call("play", global_position + Vector3(0, 1.0, 0))


func _play_happy_sound() -> void:
	if happy_sound == null:
		return
	var ap := AudioStreamPlayer.new()
	add_child(ap)
	ap.stream = happy_sound
	ap.bus = "Sfx"
	ap.play()
	ap.finished.connect(func(): ap.queue_free())


func _prepare_turn_in_rewards(quest: Quest) -> void:
	if quest.quest_id == "FINAL_DELIVERY":
		GameManager.remove_item("icecream", 2)
		GameManager.add_icecream_to_freezer(2)


func _dialogue_or_fallback(lines: Array[String], fallback: Array[String]) -> Array[String]:
	if lines.is_empty():
		return fallback
	return lines


func _get_quest_system() -> Node:
	var root = get_tree().root
	if root.has_node("QuestSystem"):
		return root.get_node("QuestSystem")
	var current_scene = get_tree().current_scene
	if current_scene and current_scene.has_node("QuestManager"):
		return current_scene.get_node("QuestManager")
	return null


func _show_bank_menu() -> void:
	var buttons: Array = []

	if GameManager.has_item("inheritance_document"):
		buttons.append({
			"text": "Løs inn arvedokument (100 kr)",
			"action": func():
				if not GameManager.bank_document_payout("BANK_INHERITANCE", 100, "bank_teller"):
					DialogueUI.show_dialogue(["Dette dokumentet er allerede løst inn."], npc_name, Callable())
					return
				GameManager.remove_item("inheritance_document", 1)
				var quest_system = _get_quest_system()
				if quest_system:
					quest_system.on_npc_talked("bank_teller")
				DialogueUI.show_dialogue(
					["Mormors arv.", "100 kroner.", "Ha en fin dag."],
					npc_name,
					Callable()
				)
		})

	if GameManager.has_item("approved_application"):
		buttons.append({
			"text": "Ta ut stipend (150 kr)",
			"action": func():
				if not GameManager.bank_document_payout("BANK_DEPOSIT", 150, "bank_teller"):
					DialogueUI.show_dialogue(["Stipendet er allerede utbetalt."], npc_name, Callable())
					return
				GameManager.remove_item("approved_application", 1)
				var quest_system = _get_quest_system()
				if quest_system:
					quest_system.on_npc_talked("bank_teller")
				DialogueUI.show_dialogue(
					["Stipendet er utbetalt.", "150 kroner.", "Ha en fin dag."],
					npc_name,
					Callable()
				)
		})

	buttons.append({
		"text": "Ingen ting",
		"action": func(): DialogueUI.close()
	})

	DialogueUI.show_menu(["Hei. Hva kan jeg hjelpe deg med?"], buttons, npc_name)


func _on_area_3d_body_entered(body: Node3D) -> void:
	if is_dead:
		return
	if body.is_in_group("PlayerCharacter"):
		in_range = true
		if name_label:
			name_label.visible = true


func _on_area_3d_body_exited(body: Node3D) -> void:
	if body.is_in_group("PlayerCharacter"):
		in_range = false
		if name_label:
			name_label.visible = false


func _on_npc_death() -> void:
	if is_dead:
		return
	is_dead = true
	_trigger_death_vfx()
	_break_world()


func _trigger_death_vfx() -> void:
	var vfx: Node3D = NPC_DEATH_VFX.instantiate() as Node3D
	var scene_root: Node = get_tree().current_scene
	if scene_root:
		scene_root.add_child(vfx)
	else:
		get_tree().root.add_child(vfx)
	if vfx.has_method("play"):
		vfx.call("play", global_position + Vector3(0, 1.0, 0))
	for child in get_children():
		if child is MeshInstance3D:
			child.visible = false
		if child is Node3D and child.name == "Model":
			child.visible = false
		_hide_meshes_recursive(child)
	var area: Area3D = get_node_or_null("InteractionArea") as Area3D
	if area == null:
		area = get_node_or_null("Area3D") as Area3D
	if area:
		area.monitoring = false
		area.monitorable = false


func _hide_meshes_recursive(n: Node) -> void:
	for c in n.get_children():
		if c is MeshInstance3D:
			c.visible = false
		if c is Node3D and c.name == "Model":
			c.visible = false
		_hide_meshes_recursive(c)


func _break_world() -> void:
	for player in get_tree().get_nodes_in_group("AmbiencePlayer"):
		if player.has_method("stop"):
			player.stop()
	GameManager.register_dead_npc(npc_id)
	quests.clear()
	in_range = false
	if name_label:
		name_label.visible = false
