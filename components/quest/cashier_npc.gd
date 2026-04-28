extends Node3D

@export var checkout_zone: NodePath
@export var npc_name: String = "Kassedama"
@export var character_model: PackedScene

var label_3d: Label3D

var in_range: bool = false
var first_time_greeting: bool = true
var _player_ref: Node3D = null
var _showed_excuse_this_visit: bool = false

var inflation_excuses: Array[String] = [
	"Det har vært stor etterspørsel i dag.",
	"Leverandøren skrudde opp prisene.",
	"Inflasjonen, du vet hvordan det er.",
	"Vi har nesten ikke is igjen.",
	"Strømprisene påvirker kjøleskapet.",
	"Det er helg snart.",
	"Sjefen min bestemte det i morges."
]

var greetings: Array[String] = [
	"Kan jeg hjelpe deg?",
	"Legg varene pa bandet.",
	"Ta deg god tid."
]
var broke_lines: Array[String] = [
	"Du har ikke nok penger.",
	"Kort i boks? Det holder ikke.",
	"Kom tilbake nar du har penger."
]
var confirm_lines: Array[String] = [
	"Vaersagod.",
	"Ha en fin dag!",
	"Kom igjen snart.",
	"Der gar du."
]

func _ready() -> void:
	randomize()
	label_3d = get_node_or_null("NameLabel") as Label3D
	if label_3d == null:
		label_3d = get_node_or_null("Area3D/Label3D") as Label3D
	_setup_model()
	if label_3d:
		label_3d.hide()
		label_3d.text = "E for å snakke med kassedama"


func _process(delta: float) -> void:
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


func _setup_model() -> void:
	# tag: character scale standard — all humanoids target 1.95m.
	if character_model == null:
		return
	var model_root := get_node_or_null("Model") as Node3D
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
	if not in_range:
		return
	if GameManager.has_method("is_minigame_active") and GameManager.is_minigame_active():
		return
	if DialogueUI.is_open():
		return
	if Input.is_action_just_pressed("interaction"):
		_interact()

func _interact() -> void:
	if GameManager.ice_creams_purchased >= 1 and not _showed_excuse_this_visit:
		_showed_excuse_this_visit = true
		DialogueUI.show_dialogue(
			[_pick_random_line(inflation_excuses)],
			npc_name,
			func(): _continue_interaction_after_excuse()
		)
		return
	_continue_interaction_after_excuse()

func _continue_interaction_after_excuse() -> void:
	var zone: Node = _get_checkout_zone()
	if zone == null or not zone.has_method("get_items") or not zone.has_method("_calculate_total"):
		DialogueUI.show_dialogue([_pick_random_line(greetings)], npc_name, Callable())
		return

	var items: Array[RigidBody3D] = zone.get_items()
	var total_cost: int = int(zone._calculate_total())
	if items.is_empty():
		if first_time_greeting:
			first_time_greeting = false
			DialogueUI.show_dialogue(
				[
					"Hei! Velkommen.",
					"Legg det du vil kjøpe på båndet her.",
					"Så tar vi det derfra."
				],
				npc_name,
				Callable()
			)
			return
		DialogueUI.show_dialogue([_pick_random_line(greetings)], npc_name, Callable())
		return
	_show_purchase_confirmation(items, total_cost)

func _show_purchase_confirmation(items: Array[RigidBody3D], total_cost: int) -> void:
	var summary_text := _build_cart_summary_text(items, total_cost)
	var on_confirm := func():
		if GameManager.player_money >= total_cost:
			_process_purchase(items, total_cost)
		else:
			DialogueUI.show_dialogue([_pick_random_line(broke_lines)], npc_name, Callable())
	DialogueUI.show_menu(
		[summary_text],
		[
			{"text": "Ja", "action": on_confirm},
			{"text": "Nei", "action": func(): DialogueUI.close()}
		],
		npc_name
	)

func _classify_cart_spend_kind(items: Array[RigidBody3D]) -> String:
	var seen_ice := false
	var seen_other := false
	for item in items:
		if not is_instance_valid(item):
			continue
		var ammo_type: String = str(item.ammo_type) if "ammo_type" in item else ""
		if ammo_type != "":
			seen_other = true
			continue
		var iid := str(item.item_id) if "item_id" in item else ""
		if iid == "icecream":
			seen_ice = true
		else:
			seen_other = true
	if seen_other:
		return "non_icecream"
	if seen_ice:
		return "icecream"
	return "general"


func _give_weapon_to_player(weapon_int_id: int) -> void:
	var player := _get_player()
	if player == null:
		return
	var weapon_manager := player.get_node_or_null(player.weapon_controller_path)
	if weapon_manager == null:
		return
	if weapon_int_id in weapon_manager.weaponStack:
		return
	if weapon_manager.has_method("acquire_weapon_by_id"):
		weapon_manager.acquire_weapon_by_id(weapon_int_id)
	else:
		weapon_manager.weaponStack.append(weapon_int_id)
	print("🔫 Weapon added to stack: ", weapon_int_id)


func _process_purchase(items: Array[RigidBody3D], total: int) -> void:
	if items.is_empty() or total <= 0:
		return
	var charge_total := _calculate_purchase_total(items)
	var spend_kind := _classify_cart_spend_kind(items)
	if not GameManager.remove_money(charge_total, spend_kind):
		return
	var player = _get_player()
	var quest_system = _get_quest_system()
	for item in items:
		if not is_instance_valid(item):
			continue
		if item.is_in_group("WallWeapon"):
			_give_weapon_to_player(int(item.weapon_int_id))
			if item.has_method("mark_as_sold"):
				item.mark_as_sold()
			continue
		var ammo_type: String = str(item.ammo_type) if "ammo_type" in item else ""
		if ammo_type != "":
			var ammo_payload := {ammo_type: int(item.ammo_amount)}
			if player:
				var link_component: Node = player.get_node_or_null("LinkComponent")
				if link_component and link_component.has_method("ammoRefillLink"):
					link_component.ammoRefillLink(ammo_payload)
				elif player.has_method("add_ammo_to_inventory"):
					player.add_ammo_to_inventory(ammo_type, int(item.ammo_amount))
				else:
					push_warning("Player missing ammo refill path for type: %s" % ammo_type)
		else:
			GameManager.add_item(item.item_id, 1)
			if item.item_id == "icecream" and quest_system:
				quest_system.on_item_purchased("icecream", 1)
			if item.item_id == "icecream" and GameManager.has_method("on_icecream_purchased"):
				GameManager.on_icecream_purchased()
		item.queue_free()
	var zone: Node = _get_checkout_zone()
	if zone:
		zone.items_on_counter = zone.items_on_counter.filter(func(item): return is_instance_valid(item))
		zone._update_price_label()
	DialogueUI.show_dialogue([_pick_random_line(confirm_lines)], npc_name, Callable())

func _build_cart_summary_text(items: Array[RigidBody3D], total_cost: int) -> String:
	var lines: Array[String] = []
	lines.append("Handlekurv:")
	for item in items:
		if not is_instance_valid(item):
			continue
		var item_name: String
		if item.is_in_group("WallWeapon"):
			item_name = str(item.weapon_name) if item.get("weapon_name") != null else "Våpen"
		else:
			item_name = str(item.display_name) if "display_name" in item and str(item.display_name) != "" else str(item.item_id)
		var item_price := int(item.price) if "price" in item else 0
		if "item_id" in item and str(item.item_id) == "icecream" and GameManager and GameManager.has_method("get_icecream_price"):
			item_price = int(GameManager.get_icecream_price())
		lines.append("- %s (%d NOK)" % [item_name, item_price])
	lines.append("")
	lines.append("Totalt: %d NOK" % total_cost)
	lines.append("Kjop varene?")
	return "\n".join(lines)

func _calculate_purchase_total(items: Array[RigidBody3D]) -> int:
	var total := 0
	for item in items:
		if not is_instance_valid(item):
			continue
		if "item_id" in item and str(item.item_id) == "icecream" and GameManager and GameManager.has_method("get_icecream_price"):
			total += int(GameManager.get_icecream_price())
			continue
		if item.has_method("get_price"):
			total += int(item.get_price())
		elif "price" in item:
			total += int(item.price)
	return total

func _pick_random_line(lines: Array[String]) -> String:
	if lines.is_empty():
		return "..."
	return lines[randi() % lines.size()]

func _get_player() -> Node:
	return get_tree().get_first_node_in_group("PlayerCharacter")

func _get_checkout_zone() -> Node:
	if checkout_zone == NodePath():
		return null
	return get_node_or_null(checkout_zone)

func _get_quest_system() -> Node:
	var root = get_tree().root
	if root.has_node("QuestSystem"):
		return root.get_node("QuestSystem")
	var current_scene = get_tree().current_scene
	if current_scene and current_scene.has_node("QuestManager"):
		return current_scene.get_node("QuestManager")
	return null

func _on_area_3d_body_entered(body: Node3D) -> void:
	if body.is_in_group("PlayerCharacter"):
		in_range = true
		if label_3d:
			label_3d.show()

func _on_area_3d_body_exited(body: Node3D) -> void:
	if body.is_in_group("PlayerCharacter"):
		in_range = false
		_showed_excuse_this_visit = false
		if label_3d:
			label_3d.hide()
