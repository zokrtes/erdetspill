extends Node3D

const SCHOLARSHIP_FORM_SCENE = preload("res://scenes/minigames/scholarship_form.tscn")

@onready var label_3d: Label3D = $Area3D/Label3D

var in_range := false

func _ready() -> void:
	if label_3d:
		label_3d.text = "E for å åpne stipendskjema"
		label_3d.hide()

func _input(_event: InputEvent) -> void:
	if not in_range:
		return
	if GameManager.has_method("is_minigame_active") and GameManager.is_minigame_active():
		return
	if DialogueUI.is_open():
		return
	if Input.is_action_just_pressed("interaction"):
		_try_open_minigame()

func _try_open_minigame() -> void:
	if _is_form_open():
		return
	if GameManager.has_item("approved_application"):
		DialogueUI.show_dialogue(["Du har allerede søkt om stipend."], "Stipendterminal", Callable())
		return
	var quest = _get_scholarship_quest()
	if quest == null:
		DialogueUI.show_dialogue(["Ingen aktiv stipend-quest."], "Stipendterminal", Callable())
		return
	quest.normalize_runtime_state()

	var talk_obj_id = "talk_to_chief_keef"
	var talk_progress = int(quest.objective_progress.get(talk_obj_id, 0))
	if talk_progress < 1:
		DialogueUI.show_dialogue(["Snakk med Chief Keef først."], "Stipendterminal", Callable())
		return

	if not GameManager.start_minigame("scholarship_form"):
		return
	var minigame = SCHOLARSHIP_FORM_SCENE.instantiate()
	get_tree().current_scene.add_child(minigame)

func _is_form_open() -> bool:
	var current_scene = get_tree().current_scene
	if current_scene == null:
		return false
	return current_scene.has_node("ScholarshipFormMinigame")

func _get_scholarship_quest() -> Quest:
	for quest in GameManager.get_active_quests():
		if quest.quest_id == "SCHOLARSHIP_APPLICATION":
			return quest
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
