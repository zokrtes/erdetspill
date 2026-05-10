extends CharacterBody3D

# tag: player character — movement, carry, pickup hint, weapons, health hooks.

class_name PlayerCharacter 

@export_group("Movement variables")
var moveSpeed : float
var moveAccel : float
var moveDeccel : float
var desiredMoveSpeed : float 
@export var desiredMoveSpeedCurve : Curve
@export var maxSpeed : float
@export var inAirMoveSpeedCurve : Curve
var inputDirection : Vector2 
var moveDirection : Vector3 
@export var hitGroundCooldown : float #amount of time the character keep his accumulated speed before losing it (while being on ground)
var hitGroundCooldownRef : float 
@export var bunnyHopDmsIncre : float #bunny hopping desired move speed incrementer
@export var autoBunnyHop : bool = false
var lastFramePosition : Vector3 
var lastFrameVelocity : Vector3
var wasOnFloor : bool
var walkOrRun : String = "WalkState" #keep in memory if play char was walking or running before being in the air
#for crouch visible changes
@export var baseHitboxHeight : float
@export var baseModelHeight : float
@export var heightChangeSpeed : float

@export_group("Crouch variables")
@export var crouchSpeed : float
@export var crouchAccel : float
@export var crouchDeccel : float
@export var continiousCrouch : bool = false #if true, doesn't need to keep crouch button on to crouch
@export var crouchHitboxHeight : float
@export var crouchModelHeight : float

@export_group("Walk variables")
@export var walkSpeed : float
@export var walkAccel : float
@export var walkDeccel : float

@export_group("Run variables")
@export var runSpeed : float
@export var runAccel : float 
@export var runDeccel : float 
@export var continiousRun : bool = false #if true, doesn't need to keep run button on to run

@export_group("Jump variables")
@export var jumpHeight : float
@export var jumpTimeToPeak : float
@export var jumpTimeToFall : float
@onready var jumpVelocity : float = (2.0 * jumpHeight) / jumpTimeToPeak
@export var jumpCooldown : float
var jumpCooldownRef : float 
@export var nbJumpsInAirAllowed : int 
var nbJumpsInAirAllowedRef : int 
var jumpBuffOn : bool = false
var bufferedJump : bool = false
@export var coyoteJumpCooldown : float
var coyoteJumpCooldownRef : float
var coyoteJumpOn : bool = false
@export_range(0.1, 1.0, 0.05) var inAirInputMultiplier: float = 1.0

@export_group("Gravity variables")
@onready var jumpGravity : float = (-2.0 * jumpHeight) / (jumpTimeToPeak * jumpTimeToPeak)
@onready var fallGravity : float = (-2.0 * jumpHeight) / (jumpTimeToFall * jumpTimeToFall)

@export_group("Keybind variables")
@export var moveForwardAction : String = ""
@export var moveBackwardAction : String = ""
@export var moveLeftAction : String = ""
@export var moveRightAction : String = ""
@export var runAction : String = ""
@export var crouchAction : String = ""
@export var jumpAction : String = ""

#references variables
@onready var camHolder : Node3D = $CameraHolder
@onready var model : MeshInstance3D = $Model
@onready var hitbox : CollisionShape3D = $Hitbox
@onready var stateMachine : Node = %StateMachine
@onready var hud : CanvasLayer = $HUD
@onready var ceilingCheck : RayCast3D = $Raycasts/CeilingCheck
@onready var floorCheck : RayCast3D = $Raycasts/FloorCheck
# WEAPON_CONTROLLER_PATH tag for UI/minigame systems.
@export var weapon_controller_path: NodePath = NodePath("CameraHolder/CameraRecoilHolder/Camera/WeaponManager")
@onready var weapon_manager: Node = get_node_or_null(weapon_controller_path)
var _weapon_active: bool = true
var _previously_active_weapon: Node = null
var carried_icecream_count: int = 0
var carried_object: RigidBody3D = null
var movement_frozen: bool = false
var camera_frozen: bool = false
var dialogue_waiting_for_button: bool = false
var is_sitting: bool = false
var _external_knockback: Vector3 = Vector3.ZERO
const KNOCKBACK_DECAY: float = 14.0

func should_use_fps_mouse_capture() -> bool:
	return not is_sitting and not movement_frozen and not camera_frozen and not dialogue_waiting_for_button

const CARRY_MAX_DISTANCE: float = 2.5
const CARRY_HOLD_DISTANCE: float = 1.8
const CARRY_LERP_WEIGHT: float = 0.2

var pickup_hint_label: Label3D

@onready var health_component: HealthComponent = $HealthComponent
@onready var health_bar: ProgressBar = $HUD/UIStats/Stats/HealthBar
const DEATH_SCREEN_SCENE: PackedScene = preload("res://scenes/ui/death_screen.tscn")

func _ready():
	if not is_in_group("PlayerCharacter"):
		add_to_group("PlayerCharacter")
	if not is_in_group("StoreBoundsActor"):
		add_to_group("StoreBoundsActor")
	#set move variables, and value references
	moveSpeed = walkSpeed
	moveAccel = walkAccel
	moveDeccel = walkDeccel
	
	hitGroundCooldownRef = hitGroundCooldown
	jumpCooldownRef = jumpCooldown
	nbJumpsInAirAllowedRef = nbJumpsInAirAllowed
	coyoteJumpCooldownRef = coyoteJumpCooldown
	# Connect health signals
	if health_component:
		health_component.connect("on_damage_taken", _on_damage_taken)
		health_component.connect("on_death", _on_player_death)
		_refresh_health_ui()
	if GameManager:
		if not GameManager.minigame_started.is_connected(_on_minigame_started):
			GameManager.minigame_started.connect(_on_minigame_started)
		if not GameManager.minigame_ended.is_connected(_on_minigame_ended):
			GameManager.minigame_ended.connect(_on_minigame_ended)
		if not GameManager.consumable_used.is_connected(_on_consumable_used):
			GameManager.consumable_used.connect(_on_consumable_used)
		_setup_pickup_hint_label()

func _process(_delta: float):
	displayProperties()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F:
		var fl := get_node_or_null("CameraHolder/CameraRecoilHolder/Camera/Flashlight") as SpotLight3D
		if fl:
			fl.visible = not fl.visible
		get_viewport().set_input_as_handled()
	# Sitting: block a few actions from propagating. When not sitting, return so keys are not marked handled.
	if not is_sitting:
		return
	if event.is_action_pressed("jump") or event.is_action_pressed("crouch") or event.is_action_pressed("run") or event.is_action_pressed("carry_object"):
		get_viewport().set_input_as_handled()


func _physics_process(_delta : float):
	if is_sitting:
		velocity.x = 0.0
		velocity.z = 0.0
		velocity.y = 0.0
		move_and_slide()
		return
	_update_pickup_hint()
	if Input.is_action_just_pressed("carry_object"):
		_toggle_carry()
	_update_carried_object()
	if movement_frozen:
		velocity = Vector3.ZERO
		move_and_slide()
		return
	modifyPhysicsProperties()
	_apply_external_knockback(_delta)
	
	move_and_slide()


func apply_external_knockback(impulse: Vector3) -> void:
	_external_knockback += impulse


func _apply_external_knockback(delta: float) -> void:
	if _external_knockback.length_squared() <= 0.0001:
		return
	velocity += _external_knockback
	_external_knockback = _external_knockback.move_toward(Vector3.ZERO, KNOCKBACK_DECAY * delta)
	
func displayProperties():
	#display properties on the hud
	if hud != null:
		hud.displayCurrentState(stateMachine.currStateName)
		hud.displayCurrentDirection(moveDirection)
		hud.displayDesiredMoveSpeed(desiredMoveSpeed)
		hud.displayVelocity(velocity.length())
		hud.displayNbJumpsInAirAllowed(nbJumpsInAirAllowed)
		
func modifyPhysicsProperties():
	lastFramePosition = position #get play char position every frame
	lastFrameVelocity = velocity #get play char velocity every frame
	wasOnFloor = !is_on_floor() #check if play char was on floor every frame
	
func gravityApply(delta : float):
	#if play char goes up, apply jump gravity
	#otherwise, apply fall gravity
	if !is_on_floor():
		if velocity.y >= 0.0: velocity.y += jumpGravity * delta
		elif velocity.y < 0.0: velocity.y += fallGravity * delta


func _on_damage_taken(current_health: float, damage_taken: float):
	print("Player took ", damage_taken, " damage! Health: ", current_health)
	_refresh_health_ui()
	var overlay := get_node_or_null("DamageFlashLayer/DamageOverlay") as ColorRect
	if overlay == null:
		return
	var c := overlay.color
	c.a = 0.4
	overlay.color = c
	var tw := create_tween()
	tw.tween_property(overlay, "color:a", 0.0, 0.4)

# tag: consumables — god_morgen_yoghurt / painkillers heal amounts (ItemData CONSUMABLE).
func _on_consumable_used(item_id: String):
	if not health_component:
		return
	var heal_amount := 0.0
	match item_id:
		"painkillers":
			heal_amount = 20.0
		"god_morgen_yoghurt":
			heal_amount = 35.0
		_:
			return
	health_component.heal(heal_amount)
	_refresh_health_ui()


func _refresh_health_ui() -> void:
	if not health_component or health_bar == null:
		return
	var current_hp := int(clamp(health_component.current_health, 0.0, health_component.max_health))
	health_bar.max_value = health_component.max_health
	health_bar.value = current_hp
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.75, 0.12, 0.12, 1.0) if current_hp < 30 else Color(0.23, 0.76, 0.27, 1.0)
	health_bar.add_theme_stylebox_override("fill", fill)


func _on_player_death():
	if DialogueUI and DialogueUI.is_open():
		DialogueUI.close()
	if has_method("freeze_for_dialogue"):
		freeze_for_dialogue(false)
	if has_method("set_weapon_active"):
		set_weapon_active(true)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	var money_now = int(GameManager.player_money)
	var penalty = max(10, int(money_now * 0.2))
	penalty = min(money_now, penalty)
	GameManager.remove_money(penalty, "death_penalty")
	var death_screen := DEATH_SCREEN_SCENE.instantiate()
	if death_screen.has_method("set_penalty"):
		death_screen.set_penalty(penalty)
	get_tree().root.add_child(death_screen)

func _on_minigame_started(_minigame_id: String):
	set_weapon_active(false)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _on_minigame_ended(_minigame_id: String, _score: int):
	set_weapon_active(true)
	if should_use_fps_mouse_capture():
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func set_weapon_active(enabled: bool):
	if weapon_manager == null:
		weapon_manager = get_node_or_null(weapon_controller_path)
	if weapon_manager == null:
		return
	if _weapon_active == enabled:
		return

	if not enabled:
		if weapon_manager.has_method("get_current_weapon_model"):
			_previously_active_weapon = weapon_manager.get_current_weapon_model()
		if weapon_manager.has_method("hide_all_weapon_models"):
			weapon_manager.hide_all_weapon_models()
		elif weapon_manager.has_method("set_weapon_visible"):
			weapon_manager.set_weapon_visible(false)
		if weapon_manager.has_method("set_weapon_controls_enabled"):
			weapon_manager.set_weapon_controls_enabled(false)
		weapon_manager.set_process(false)
		weapon_manager.set_physics_process(false)
		weapon_manager.set_process_input(false)
		_weapon_active = false
	else:
		if weapon_manager.has_method("hide_all_weapon_models"):
			weapon_manager.hide_all_weapon_models()
		if _previously_active_weapon != null and weapon_manager.has_method("show_weapon_model"):
			weapon_manager.show_weapon_model(_previously_active_weapon)
		elif weapon_manager.has_method("set_weapon_visible"):
			weapon_manager.set_weapon_visible(true)
		if weapon_manager.has_method("set_weapon_controls_enabled"):
			weapon_manager.set_weapon_controls_enabled(true)
		weapon_manager.set_process(true)
		weapon_manager.set_physics_process(true)
		weapon_manager.set_process_input(true)
		_weapon_active = true

func _setup_pickup_hint_label() -> void:
	pickup_hint_label = Label3D.new()
	pickup_hint_label.text = "V - Plukk opp"
	pickup_hint_label.hide()
	pickup_hint_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	pickup_hint_label.font_size = 22
	pickup_hint_label.modulate = Color(1, 1, 1, 0.95)
	pickup_hint_label.no_depth_test = true
	add_child(pickup_hint_label)


func _update_pickup_hint() -> void:
	if pickup_hint_label == null:
		return
	if is_sitting or movement_frozen or camera_frozen or dialogue_waiting_for_button or has_carried_object():
		pickup_hint_label.hide()
		return
	var viewport_camera: Camera3D = get_viewport().get_camera_3d()
	if viewport_camera == null:
		pickup_hint_label.hide()
		return
	var from: Vector3 = viewport_camera.global_transform.origin
	var to: Vector3 = from + (-viewport_camera.global_transform.basis.z * CARRY_MAX_DISTANCE)
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = false
	query.exclude = [self]
	var result: Dictionary = space_state.intersect_ray(query)
	if result.is_empty():
		pickup_hint_label.hide()
		return
	var collider: Variant = result.get("collider")
	if collider is RigidBody3D and (collider as RigidBody3D).is_in_group("Carriable"):
		var hit_pos: Vector3 = result.get("position", (collider as Node3D).global_position) as Vector3
		pickup_hint_label.global_position = hit_pos + Vector3.UP * 0.25
		pickup_hint_label.show()
	else:
		pickup_hint_label.hide()


# tag: carry API — has_carried_object(), get_carried_object() (shop security / ShopItem).
func has_carried_object() -> bool:
	return carried_object != null

func get_carried_object() -> RigidBody3D:
	return carried_object

func _toggle_carry():
	if carried_object:
		_drop_item()
		return
	_try_pickup_carriable()

func _try_pickup_carriable():
	var viewport_camera: Camera3D = get_viewport().get_camera_3d()
	if viewport_camera == null:
		return
	var from: Vector3 = viewport_camera.global_transform.origin
	var to: Vector3 = from + (-viewport_camera.global_transform.basis.z * CARRY_MAX_DISTANCE)
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = false
	query.exclude = [self]
	var result: Dictionary = space_state.intersect_ray(query)
	if result.is_empty():
		return
	var collider: Variant = result.get("collider")
	if not (collider is RigidBody3D):
		return
	var body: RigidBody3D = collider as RigidBody3D
	if not body.is_in_group("Carriable"):
		return
	CarriablePickup.save_physics_before_carry(body)
	carried_object = body
	carried_object.freeze = true
	carried_object.collision_layer = 0
	carried_object.collision_mask = 0
	carried_object.linear_velocity = Vector3.ZERO
	carried_object.angular_velocity = Vector3.ZERO
	if carried_object.has_method("on_picked_up"):
		carried_object.on_picked_up()
	set_weapon_active(false)

func _update_carried_object():
	if carried_object == null:
		return
	if not is_instance_valid(carried_object):
		carried_object = null
		if _can_show_weapon():
			set_weapon_active(true)
		return
	var viewport_camera: Camera3D = get_viewport().get_camera_3d()
	if viewport_camera == null:
		return
	var target_pos: Vector3 = viewport_camera.global_transform.origin + (-viewport_camera.global_transform.basis.z * CARRY_HOLD_DISTANCE)
	carried_object.global_position = carried_object.global_position.lerp(target_pos, CARRY_LERP_WEIGHT)
	carried_object.linear_velocity = Vector3.ZERO
	carried_object.angular_velocity = Vector3.ZERO

func _drop_item():
	if carried_object == null:
		return
	if is_instance_valid(carried_object):
		carried_object.freeze = false
		CarriablePickup.restore_physics_after_drop(carried_object)
	carried_object = null
	if _can_show_weapon():
		set_weapon_active(true)

func _drop_carried_object():
	_drop_item()

func _can_show_weapon() -> bool:
	if is_sitting or movement_frozen or camera_frozen:
		return false
	var current_scene: Node = get_tree().current_scene
	if current_scene and current_scene.has_node("InventoryPanel"):
		var inventory_panel: Node = current_scene.get_node("InventoryPanel")
		if inventory_panel and inventory_panel.has_method("get"):
			if bool(inventory_panel.get("is_open")):
				return false
	return true

func freeze_for_dialogue(frozen: bool):
	if not frozen and dialogue_waiting_for_button:
		return
	movement_frozen = frozen
	camera_frozen = frozen
	if frozen:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		velocity = Vector3.ZERO
		set_weapon_active(false)
	else:
		if should_use_fps_mouse_capture():
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		if _can_show_weapon():
			set_weapon_active(true)

func set_dialogue_waiting_for_button(waiting: bool):
	dialogue_waiting_for_button = waiting
	if waiting:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

## Sitting at the lemonade stand: block movement and FPS look; mouse is free for UI.
func sit_at_stand(sitting: bool) -> void:
	is_sitting = sitting
	movement_frozen = sitting
	camera_frozen = sitting
	if sitting:
		velocity = Vector3.ZERO
		_force_stand_up()
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		set_weapon_active(false)
	else:
		if stateMachine and stateMachine.has_method("transition_to"):
			stateMachine.transition_to("WalkState")
		if should_use_fps_mouse_capture():
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		if _can_show_weapon():
			set_weapon_active(true)


func _force_stand_up() -> void:
	if stateMachine and stateMachine.has_method("transition_to"):
		if stateMachine.currStateName == "Crouch":
			stateMachine.transition_to("WalkState")
	var cap := hitbox.shape as CapsuleShape3D
	if cap:
		cap.height = baseHitboxHeight
	if model:
		model.scale.y = baseModelHeight


func set_sitting_at_stand(sitting: bool, _look_target: Vector3 = Vector3.ZERO) -> void:
	sit_at_stand(sitting)

func get_carried_icecream_count() -> int:
	return carried_icecream_count

func try_pickup_icecream() -> bool:
	if carried_icecream_count >= 2:
		return false
	carried_icecream_count += 1
	return true

func take_carried_icecream(amount: int) -> int:
	var taken = min(max(0, amount), carried_icecream_count)
	carried_icecream_count -= taken
	return taken

func add_ammo_to_inventory(ammo_type: String, amount: int) -> int:
	if amount <= 0:
		return 0
	if weapon_manager == null:
		weapon_manager = get_node_or_null(weapon_controller_path)
	if weapon_manager == null:
		return 0
	var ammo_manager: Node = weapon_manager.get("ammoManager")
	if ammo_manager == null:
		return 0
	var ammo_dict: Dictionary = ammo_manager.get("ammoDict")
	var max_dict: Dictionary = ammo_manager.get("maxNbPerAmmoDict")
	if not ammo_dict.has(ammo_type) or not max_dict.has(ammo_type):
		return 0
	var current: int = int(ammo_dict.get(ammo_type, 0))
	var max_amount: int = int(max_dict.get(ammo_type, current))
	var next_amount: int = min(max_amount, current + amount)
	var added: int = max(0, next_amount - current)
	ammo_dict[ammo_type] = next_amount
	return added
