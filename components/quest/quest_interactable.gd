extends Node3D
class_name QuestInteractable

enum ActionType {
	PURCHASE_ITEM,
	FILL_FORM,
	CUSTOM_ACTION,
	DELIVER_ITEM,
	COLLECT_ITEM,
	VISIT_LOCATION
}

@export var interactable_id: String = ""
@export var interactable_name: String = "Objekt"
@export var action_type: ActionType = ActionType.CUSTOM_ACTION
@export var prompt_text: String = "E for å bruke"

@export_category("Objective Targets")
@export var target_item_id: String = ""
@export var target_npc_id: String = ""
@export var target_action_id: String = ""
@export var target_location_id: String = ""

@export_category("Action Settings")
@export var item_cost_nok: int = 0
@export var consume_item_on_deliver: bool = true
@export var show_success_message: String = ""
@export var show_fail_message: String = ""

@onready var label_3d: Label3D = $Area3D/Label3D

var in_range := false

func _ready() -> void:
	if label_3d:
		label_3d.text = prompt_text
		label_3d.hide()

func _input(_event: InputEvent) -> void:
	if not in_range:
		return
	if DialogueUI.is_open():
		return
	if Input.is_action_just_pressed("interaction"):
		_perform_action()

func _perform_action() -> void:
	match action_type:
		ActionType.PURCHASE_ITEM:
			_handle_purchase()
		ActionType.FILL_FORM:
			_handle_form_fill()
		ActionType.CUSTOM_ACTION:
			_handle_custom_action()
		ActionType.DELIVER_ITEM:
			_handle_delivery()
		ActionType.COLLECT_ITEM:
			_handle_collection()
		ActionType.VISIT_LOCATION:
			_handle_location_visit()

func _handle_purchase() -> void:
	if target_item_id == "":
		_show_dialogue("Denne butikken mangler item_id.")
		return
	var spend_ctx := "icecream" if target_item_id == "icecream" else "non_icecream"
	if item_cost_nok > 0 and not GameManager.remove_money(item_cost_nok, spend_ctx):
		_show_dialogue(_fallback_message(show_fail_message, "Du mangler penger (%d NOK)." % item_cost_nok))
		return
	var quest_system = _get_quest_system()
	if quest_system == null:
		_show_dialogue("QuestSystem mangler i scenen.")
		return
	GameManager.add_item(target_item_id, 1)
	quest_system.on_item_purchased(target_item_id)
	_show_dialogue(_fallback_message(show_success_message, "Kjøpte %s." % target_item_id))

func _handle_form_fill() -> void:
	var form_id = target_action_id if target_action_id != "" else interactable_id
	if form_id == "":
		_show_dialogue("Skjema mangler id.")
		return
	var quest_system = _get_quest_system()
	if quest_system == null:
		_show_dialogue("QuestSystem mangler i scenen.")
		return
	quest_system.on_form_filled(form_id)
	_show_dialogue(_fallback_message(show_success_message, "Skjema sendt inn."))

func _handle_custom_action() -> void:
	var action_id = target_action_id if target_action_id != "" else interactable_id
	if action_id == "":
		_show_dialogue("Action mangler id.")
		return
	var quest_system = _get_quest_system()
	if quest_system == null:
		_show_dialogue("QuestSystem mangler i scenen.")
		return
	quest_system.on_minigame_completed(action_id)
	_show_dialogue(_fallback_message(show_success_message, "Handling registrert."))

func _handle_delivery() -> void:
	if target_item_id == "" or target_npc_id == "":
		_show_dialogue("Levering mangler item_id eller npc_id.")
		return
	var quest_system = _get_quest_system()
	if quest_system == null:
		_show_dialogue("QuestSystem mangler i scenen.")
		return
	if consume_item_on_deliver and not GameManager.remove_item(target_item_id, 1):
		_show_dialogue(_fallback_message(show_fail_message, "Du har ikke %s å levere." % target_item_id))
		return
	quest_system.on_item_delivered(target_npc_id, target_item_id)
	quest_system.on_minigame_completed(target_npc_id)
	_show_dialogue(_fallback_message(show_success_message, "Levering registrert."))

func _handle_collection() -> void:
	if target_item_id == "":
		_show_dialogue("Samlingsobjekt mangler item_id.")
		return
	var quest_system = _get_quest_system()
	if quest_system == null:
		_show_dialogue("QuestSystem mangler i scenen.")
		return
	GameManager.add_item(target_item_id, 1)
	quest_system.on_item_collected(target_item_id)
	_show_dialogue(_fallback_message(show_success_message, "Plukket opp %s." % target_item_id))

func _handle_location_visit() -> void:
	var location_id = target_location_id if target_location_id != "" else interactable_id
	if location_id == "":
		_show_dialogue("Lokasjon mangler id.")
		return
	var quest_system = _get_quest_system()
	if quest_system == null:
		_show_dialogue("QuestSystem mangler i scenen.")
		return
	quest_system.on_location_visited(location_id)
	_show_dialogue(_fallback_message(show_success_message, "Lokasjon besøkt."))

func _show_dialogue(message: String) -> void:
	DialogueUI.show_dialogue([message], interactable_name, Callable())

func _fallback_message(primary: String, fallback: String) -> String:
	return primary if primary != "" else fallback

func _get_quest_system() -> Node:
	var root = get_tree().root
	if root.has_node("QuestSystem"):
		return root.get_node("QuestSystem")
	if root.has_node("QuestManager"):
		return root.get_node("QuestManager")
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
		if label_3d:
			label_3d.hide()
