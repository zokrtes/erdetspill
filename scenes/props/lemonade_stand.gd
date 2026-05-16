extends Node3D

@export var ghost_preview: bool = false
@export var sign_texture: ImageTexture
@export var customer_scene: PackedScene = preload("res://scenes/npc/lemonade_customer.tscn")
@export var sign_drawing_scene: PackedScene = preload("res://scenes/minigames/sign_drawing.tscn")

@onready var sign_mesh: MeshInstance3D = $SignMesh
@onready var sit_point: Marker3D = $SitPoint
@onready var prompt_label: Label3D = $PromptLabel3D

var is_open: bool = false
var player_sitting: bool = false
var sign_drawn: bool = false

var _interaction_in_range: bool = false
var _sign_in_range: bool = false
var _player: Node = null
var _active_customer: CharacterBody3D = null
var _spawn_timer: float = 0.0
var _spawn_interval: float = 20.0

const CUSTOMER_VARIANTS := [
	{"name": "Nabo"},
	{"name": "Forbipasserende"},
	{"name": "Bankansatt"},
	{"name": "Jogger"}
]

const CUSTOMER_MODELS := {
	# tag: lemonade customer cast — explicit model mapping.
	"Nabo": preload("res://assets/props/Characters_psx/Models/Female/Character_Female_12.fbx"),
	"Forbipasserende": preload("res://assets/props/Characters_psx/Models/Male/Character_06.fbx"),
	"Bankansatt": preload("res://assets/props/Characters_psx/Models/Male/Character_02.fbx"),
	"Jogger": preload("res://assets/props/Characters_psx/Models/Male/Character_06.fbx")
}

func _ready() -> void:
	if ghost_preview:
		set_process(false)
		set_physics_process(false)
		set_process_input(false)
		set_process_unhandled_input(false)
		prompt_label.hide()
		$InteractionArea.monitoring = false
		$InteractionArea.monitorable = false
		$SignInteractionArea.monitoring = false
		$SignInteractionArea.monitorable = false
		return

	# Player is on collision layer 2 in this project.
	$InteractionArea.set_collision_mask_value(1, true)
	$InteractionArea.set_collision_mask_value(2, true)
	$SignInteractionArea.set_collision_mask_value(1, true)
	$SignInteractionArea.set_collision_mask_value(2, true)
	$InteractionArea.body_entered.connect(_on_interaction_area_body_entered)
	$InteractionArea.body_exited.connect(_on_interaction_area_body_exited)
	$SignInteractionArea.body_entered.connect(_on_sign_area_body_entered)
	$SignInteractionArea.body_exited.connect(_on_sign_area_body_exited)
	prompt_label.hide()
	_apply_sign_texture()

func _process(delta: float) -> void:
	if ghost_preview:
		return
	if not player_sitting or not is_open:
		return
	if _active_customer != null and is_instance_valid(_active_customer):
		return
	_spawn_timer += delta
	if _spawn_timer >= _spawn_interval:
		_spawn_timer = 0.0
		_spawn_interval = randf_range(15.0, 25.0)
		_spawn_customer()


func _unhandled_input(_event: InputEvent) -> void:
	if ghost_preview:
		return
	if not _interaction_in_range:
		return
	if DialogueUI.is_open():
		return
	if Input.is_action_just_pressed("interaction"):
		_handle_interaction()

func _handle_interaction() -> void:
	if not player_sitting and not sign_drawn:
		if not _sign_in_range:
			DialogueUI.show_dialogue(["Gå nærmere skiltet for å tegne."], "Lemonadebod", Callable())
			return
		DialogueUI.show_dialogue(
			["Tegn skiltet ditt før du åpner boden."],
			"Lemonadebod",
			func(): _open_sign_drawing()
		)
		return
	if not player_sitting:
		_sit_player()
		return
	_stand_up_player()

func _open_sign_drawing() -> void:
	if sign_drawing_scene == null:
		return
	var minigame := sign_drawing_scene.instantiate()
	get_tree().root.add_child(minigame)
	if minigame.has_signal("sign_finished"):
		minigame.connect("sign_finished", _on_sign_finished)

func _on_sign_finished(texture: ImageTexture) -> void:
	sign_texture = texture
	sign_drawn = true
	_apply_sign_texture()
	_update_prompt()

func _apply_sign_texture() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.93, 0.87, 0.65, 1)
	mat.roughness = 0.9
	if sign_texture:
		mat.albedo_texture = sign_texture
	sign_mesh.material_override = mat

func _sit_player() -> void:
	_player = get_tree().get_first_node_in_group("PlayerCharacter")
	if _player == null:
		return
	if _player.has_method("_drop_carried_object"):
		_player.call("_drop_carried_object")
	if _player is Node3D:
		(_player as Node3D).global_position = sit_point.global_position
	if _player.has_method("sit_at_stand"):
		_player.sit_at_stand(true)
	elif _player.has_method("set_sitting_at_stand"):
		_player.set_sitting_at_stand(true)
	elif _player.has_method("freeze_for_dialogue"):
		_player.freeze_for_dialogue(true)
	else:
		_player.movement_frozen = true
		_player.camera_frozen = true
	if _player.has_method("set_weapon_active"):
		_player.set_weapon_active(false)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	is_open = true
	player_sitting = true
	_spawn_timer = 18.0
	_spawn_interval = 20.0
	_update_prompt()

func _stand_up_player() -> void:
	var player := get_tree().get_first_node_in_group("PlayerCharacter")
	if player and player.has_method("sit_at_stand"):
		player.sit_at_stand(false)
		if player is CharacterBody3D:
			(player as CharacterBody3D).velocity = Vector3(0.0, 0.5, 0.0)
	elif player and player.has_method("set_sitting_at_stand"):
		player.set_sitting_at_stand(false)
	elif player and player.has_method("freeze_for_dialogue"):
		player.freeze_for_dialogue(false)
	else:
		player.movement_frozen = false
		player.camera_frozen = false
	if player and player.has_method("set_weapon_active"):
		player.set_weapon_active(true)
	if player and player.has_method("should_use_fps_mouse_capture") and player.should_use_fps_mouse_capture():
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_player = player
	is_open = false
	player_sitting = false
	_spawn_timer = 0.0
	_update_prompt()


func _get_spawn_position() -> Vector3:
	var base := global_position + global_transform.basis.z * 7.0
	# Sample floor at spawn XZ to avoid spawning under/over terrain.
	var from := Vector3(base.x, base.y + 5.0, base.z)
	var to := Vector3(base.x, base.y - 3.0, base.z)
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [self]
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if not result.is_empty():
		base.y = float((result["position"] as Vector3).y) + 0.1
	return base


func _get_counter_position() -> Vector3:
	var base := global_position + (-global_transform.basis.z) * 1.2
	base.y = _sample_floor_y(base)
	return base


func _sample_floor_y(pos: Vector3) -> float:
	var from := Vector3(pos.x, pos.y + 3.0, pos.z)
	var to := Vector3(pos.x, pos.y - 2.0, pos.z)
	var query := PhysicsRayQueryParameters3D.create(from, to)
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return pos.y
	return float((result["position"] as Vector3).y)


func _spawn_customer() -> void:
	# tag: lemonade spawn pipeline — assign model immediately after spawn.
	if customer_scene == null:
		push_warning("Lemonade stand: no customer_scene assigned.")
		return
	var customer := customer_scene.instantiate() as CharacterBody3D
	var spawn_pos: Vector3 = _get_spawn_position()
	var counter_pos: Vector3 = _get_counter_position()
	var pick: Dictionary = CUSTOMER_VARIANTS[randi() % CUSTOMER_VARIANTS.size()]
	get_tree().current_scene.add_child(customer)
	customer.global_position = spawn_pos
	customer.call("setup_customer", pick["name"])
	var model_scene: PackedScene = CUSTOMER_MODELS.get(str(pick["name"]), null)
	if model_scene != null and customer.has_method("set_model"):
		customer.call("set_model", model_scene)
	customer.call("setup", counter_pos, self)
	_active_customer = customer

func on_customer_arrived(customer: CharacterBody3D) -> void:
	if not is_open:
		_active_customer = null
		customer.queue_free()
		return
	var customer_name := str(customer.get("customer_name"))
	var greeting_options: Array[String] = [
		"Hei. Hva koster lemonaden?",
		"Selger du lemonade?",
		"Jeg er tørst."
	]
	var greeting: String = greeting_options[randi() % greeting_options.size()]
	DialogueUI.show_menu(
		[greeting],
		[
			{"text": "10 kr", "action": func(): _sell(10, customer)},
			{"text": "20 kr", "action": func(): _sell(20, customer)},
			{"text": "50 kr", "action": func(): _sell(50, customer)},
			{"text": "Gratis", "action": func(): _sell(0, customer)}
		],
		customer_name
	)

func _sell(price: int, customer: Node) -> void:
	if customer == null or not is_instance_valid(customer):
		return
	var customer_name := str(customer.get("customer_name"))
	var customer_response := ""
	if price == 0:
		customer_response = _pick_random(["Takk skal du ha!", "Gratis? Wow.", "Du er snill."])
	elif price <= 20:
		customer_response = _pick_random(["Fair nok.", "Greit.", "Her har du."])
		GameManager.add_flat_money_reward(price)
	elif price == 50:
		if randf() < 0.6:
			customer_response = "Jaja..."
			GameManager.add_flat_money_reward(price)
		else:
			customer_response = _pick_random(["50 kr?! For lemonade?", "Det er for dyrt.", "Nei takk."])

	var leave_cb := func():
		if is_instance_valid(customer) and customer.has_method("leave"):
			customer.call("leave")
		elif is_instance_valid(customer):
			customer.queue_free()
			_active_customer = null
		_rehide_weapon_if_still_sitting()
	DialogueUI.show_dialogue([customer_response], customer_name, leave_cb)


func on_customer_leaving(_customer: Node) -> void:
	_active_customer = null


func _rehide_weapon_if_still_sitting() -> void:
	if not player_sitting:
		return
	var player := get_tree().get_first_node_in_group("PlayerCharacter")
	if player and player.has_method("set_weapon_active"):
		player.set_weapon_active(false)

func _pick_random(options: Array[String]) -> String:
	if options.is_empty():
		return ""
	return options[randi() % options.size()]

func _on_interaction_area_body_entered(body: Node3D) -> void:
	if body.is_in_group("PlayerCharacter"):
		_interaction_in_range = true
		_update_prompt()

func _on_interaction_area_body_exited(body: Node3D) -> void:
	if body.is_in_group("PlayerCharacter"):
		_interaction_in_range = false
		_update_prompt()

func _on_sign_area_body_entered(body: Node3D) -> void:
	if body.is_in_group("PlayerCharacter"):
		_sign_in_range = true
		_update_prompt()

func _on_sign_area_body_exited(body: Node3D) -> void:
	if body.is_in_group("PlayerCharacter"):
		_sign_in_range = false
		_update_prompt()

func _update_prompt() -> void:
	if not _interaction_in_range:
		prompt_label.hide()
		return
	if player_sitting:
		prompt_label.text = "E - Stå opp"
	else:
		prompt_label.text = "E - Sett deg" if sign_drawn else "E - Tegn skilt"
	prompt_label.show()
