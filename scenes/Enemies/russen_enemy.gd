extends CharacterBody3D

enum RussState {
	PATROL,
	INVESTIGATE,
	CHASE,
	ATTACK,
	DEAD
}

const GRAVITY: float = 9.8

@export_category("Movement")
@export var patrol_speed: float = 1.2
@export var investigate_speed: float = 2.5
@export var chase_speed: float = 4.5

@export_category("Patrol")
@export var patrol_center: Vector3 = Vector3.ZERO
@export var patrol_radius: float = 8.0
@export var patrol_repick_min: float = 3.0
@export var patrol_repick_max: float = 6.0

@export_category("Detection")
@export var sight_range: float = 10.0
@export var proximity_range: float = 2.5
@export var chase_lost_range: float = 15.0
@export_category("Vision")
@export var fov_degrees: float = 90.0
@export var vision_distance: float = 10.0
@export var vision_ray_count: int = 7
@export var vision_height_offset: float = 1.0

@export_category("Attack")
@export var attack_cooldown: float = 1.5
@export var melee_range: float = 1.5
@export var melee_damage: float = 8.0
@export var melee_knockback: float = 2.0
@export var xp_reward: int = 0
@export var is_hideout_russ: bool = false

@export_category("Drunk Stagger")
@export var chase_stagger_frequency: float = 3.0
@export var chase_stagger_amount: float = 0.4
@export_category("Model")
@export var character_model: PackedScene

@onready var health_component: HealthComponent = $HealthComponent
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var model_root: Node3D = $Model

var russ_state: RussState = RussState.PATROL
var player_target: CharacterBody3D
var investigate_target: Vector3 = Vector3.ZERO
var last_known_player_pos: Vector3 = Vector3.ZERO
var patrol_target: Vector3 = Vector3.ZERO
var can_attack: bool = true
var attack_timer: float = 0.0
var patrol_timer: float = 0.0
var investigate_timer: float = 0.0
var _stagger_time: float = 0.0
var _death_timer: float = 3.0
var _friendly_until: float = 0.0


func _ready() -> void:
	add_to_group("Enemies")
	# Ensure Russ always collides with player layer (2).
	set_collision_mask_value(2, true)
	patrol_center = global_position
	patrol_target = patrol_center
	patrol_timer = randf_range(patrol_repick_min, patrol_repick_max)
	_setup_model()
	player_target = get_tree().get_first_node_in_group("PlayerCharacter") as CharacterBody3D
	if health_component:
		health_component.on_death.connect(_on_enemy_death)
	if GameManager and not GameManager.gunshot_fired.is_connected(_on_gunshot):
		GameManager.gunshot_fired.connect(_on_gunshot)
	_apply_difficulty()
	_enter_patrol()


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
	var mesh_instance := _find_first_mesh_recursive(instance)
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


func _find_first_mesh_recursive(node: Node) -> MeshInstance3D:
	if node == null:
		return null
	if node is MeshInstance3D:
		return node as MeshInstance3D
	for child in node.get_children():
		var mesh := _find_first_mesh_recursive(child)
		if mesh != null:
			return mesh
	return null


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		if velocity.y < 0.0:
			velocity.y = 0.0

	if russ_state == RussState.DEAD:
		_death_timer -= delta
		move_and_slide()
		if _death_timer <= 0.0:
			queue_free()
		return

	if _is_temporarily_friendly():
		if russ_state == RussState.CHASE or russ_state == RussState.ATTACK:
			_enter_patrol()

	if not can_attack:
		attack_timer -= delta
		if attack_timer <= 0.0:
			can_attack = true

	if player_target == null or not is_instance_valid(player_target):
		player_target = get_tree().get_first_node_in_group("PlayerCharacter") as CharacterBody3D

	_detect_player()
	_update_state(delta)
	if is_on_floor() and velocity.y >= 0.0 and velocity.length() > 0.3:
		var move_dir := Vector3(velocity.x, 0, velocity.z).normalized()
		if move_dir != Vector3.ZERO:
			var knee_origin := global_position + Vector3(0, 0.15, 0)
			var knee_end := knee_origin + move_dir * 0.4
			var sq := PhysicsRayQueryParameters3D.create(knee_origin, knee_end)
			sq.exclude = [self]
			var hit := get_world_3d().direct_space_state.intersect_ray(sq)
			if not hit.is_empty():
				velocity.y = max(velocity.y, 3.5)
	move_and_slide()
	_draw_vision_debug()


func _update_state(delta: float) -> void:
	if global_position.distance_to(patrol_center) > patrol_radius * 2.0 and russ_state != RussState.CHASE:
		_enter_investigate(patrol_center)
	match russ_state:
		RussState.PATROL:
			_update_patrol(delta)
		RussState.INVESTIGATE:
			_update_investigate(delta)
		RussState.CHASE:
			_update_chase(delta)
		RussState.ATTACK:
			_update_attack()


func _update_patrol(delta: float) -> void:
	patrol_timer -= delta
	if patrol_timer <= 0.0:
		patrol_target = _random_point_in_patrol_disc()
		patrol_timer = randf_range(patrol_repick_min, patrol_repick_max)
	_move_horizontal_toward(patrol_target, patrol_speed, 0.25)


func _update_investigate(delta: float) -> void:
	investigate_timer -= delta
	_move_horizontal_toward(investigate_target, investigate_speed, 0.2)
	if _horizontal_distance_to(investigate_target) <= 1.0 or investigate_timer <= 0.0:
		_enter_patrol()


func _update_chase(delta: float) -> void:
	if player_target == null or not is_instance_valid(player_target):
		_enter_investigate(last_known_player_pos)
		return
	last_known_player_pos = player_target.global_position
	var dist := global_position.distance_to(player_target.global_position)
	if dist > chase_lost_range:
		_enter_investigate(last_known_player_pos)
		return
	var horizontal_dist := _horizontal_distance_to(player_target.global_position)
	if horizontal_dist <= melee_range:
		_enter_attack()
		return
	_stagger_time += delta
	var dir := _horizontal_direction_to(player_target.global_position)
	var right := global_transform.basis.x.normalized()
	var stagger := sin(_stagger_time * chase_stagger_frequency) * chase_stagger_amount
	dir = (dir + right * stagger).normalized()
	velocity.x = dir.x * chase_speed
	velocity.z = dir.z * chase_speed
	_face_direction(dir)


func _update_attack() -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	if player_target == null or not is_instance_valid(player_target):
		_enter_investigate(last_known_player_pos)
		return
	var dist := _horizontal_distance_to(player_target.global_position)
	if dist > melee_range + 1.0:
		_enter_chase(player_target)
		return
	print("State: ATTACK dist: ", dist, " can_attack: ", can_attack)
	if can_attack:
		_perform_melee_attack()


func _detect_player() -> void:
	if russ_state == RussState.DEAD:
		return
	if _is_temporarily_friendly():
		return
	if player_target == null or not is_instance_valid(player_target):
		return
	var dist := global_position.distance_to(player_target.global_position)
	if dist <= proximity_range:
		_enter_chase(player_target)
		return
	var seen := _cast_vision()
	if seen != null:
		_enter_chase(seen)
		return
	if russ_state == RussState.CHASE and dist > chase_lost_range:
		_enter_investigate(last_known_player_pos)


func _cast_vision() -> CharacterBody3D:
	if player_target == null:
		return null
	if vision_ray_count < 2:
		vision_ray_count = 2
	var eye_pos := global_position + Vector3(0.0, vision_height_offset, 0.0)
	var half_fov := deg_to_rad(fov_degrees * 0.5)
	var step := deg_to_rad(fov_degrees) / float(vision_ray_count - 1)
	var forward := (-global_transform.basis.z).normalized()
	for i in range(vision_ray_count):
		var angle := -half_fov + step * i
		var dir := forward.rotated(Vector3.UP, angle).normalized()
		var ray_end := eye_pos + dir * vision_distance
		var query := PhysicsRayQueryParameters3D.create(eye_pos, ray_end)
		query.exclude = [self]
		var result := get_world_3d().direct_space_state.intersect_ray(query)
		if result.is_empty():
			continue
		var hit = result.get("collider")
		if hit == player_target:
			return player_target
		if hit is Node and player_target.is_ancestor_of(hit):
			return player_target
	return null


func _draw_vision_debug() -> void:
	if not OS.is_debug_build():
		return
	if vision_ray_count < 2:
		return
	if not Engine.has_singleton("DebugDraw3D"):
		return
	var debug_draw := Engine.get_singleton("DebugDraw3D")
	if debug_draw == null:
		return
	var eye_pos := global_position + Vector3(0.0, vision_height_offset, 0.0)
	var half_fov := deg_to_rad(fov_degrees * 0.5)
	var step := deg_to_rad(fov_degrees) / float(vision_ray_count - 1)
	var forward := (-global_transform.basis.z).normalized()
	for i in range(vision_ray_count):
		var angle := -half_fov + step * i
		var dir := forward.rotated(Vector3.UP, angle).normalized()
		var color := Color.GREEN if russ_state == RussState.CHASE else Color.YELLOW
		debug_draw.draw_ray_3d(eye_pos, dir, vision_distance, color)


func _perform_melee_attack() -> void:
	if player_target == null:
		return
	can_attack = false
	attack_timer = attack_cooldown

	# Prefer the player's explicit health component to avoid hitting wrong child scripts.
	var health: Node = player_target.get_node_or_null("HealthComponent")
	if health == null:
		health = _find_health_component_recursive(player_target)
	if health == null:
		push_warning("No health found on player")
		return

	health.take_damage(melee_damage)

	# Knockback
	var dir := (player_target.global_position - global_position).normalized()
	dir.y = 0.15
	player_target.velocity += dir * melee_knockback


func _apply_difficulty() -> void:
	if is_hideout_russ:
		# Hideout Russ — genuinely dangerous.
		if health_component:
			health_component.max_health = 120.0
			health_component.current_health = 120.0
		melee_damage = 18.0
		melee_range = 2.2
		chase_speed = 9.0
		sight_range = 20.0
		patrol_speed = 2.0
		melee_knockback = 4.5
		attack_cooldown = 1.0
		chase_stagger_amount = 0.18
		xp_reward = 25
	else:
		# Street Russ — weak nuisance.
		if health_component:
			health_component.max_health = 40.0
			health_component.current_health = 40.0
		melee_damage = 8.0
		melee_range = 1.9
		chase_speed = 7.5
		sight_range = 25.0
		patrol_speed = 1.2
		melee_knockback = 2.8
		attack_cooldown = 1.2
		chase_stagger_amount = 0.2
		xp_reward = 10


func _move_horizontal_toward(target_pos: Vector3, speed: float, turn_weight: float) -> void:
	var dir := _horizontal_direction_to(target_pos)
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	_face_direction(dir, turn_weight)


func _horizontal_direction_to(target_pos: Vector3) -> Vector3:
	var to_target := target_pos - global_position
	to_target.y = 0.0
	if to_target.length_squared() <= 0.0001:
		return Vector3.ZERO
	return to_target.normalized()


func _face_direction(dir: Vector3, turn_weight: float = 0.2) -> void:
	if dir == Vector3.ZERO:
		return
	var desired := atan2(-dir.x, -dir.z)
	rotation.y = lerp_angle(rotation.y, desired, clamp(turn_weight, 0.05, 1.0))


func _horizontal_distance_to(target_pos: Vector3) -> float:
	var delta := target_pos - global_position
	delta.y = 0.0
	return delta.length()


func _find_health_component_recursive(node: Node) -> Node:
	for child in node.get_children():
		if child is HealthComponent:
			return child
		var found := _find_health_component_recursive(child)
		if found != null:
			return found
	return null


func _random_point_in_patrol_disc() -> Vector3:
	var angle := randf() * TAU
	var dist := randf_range(0.4, patrol_radius)
	var point := patrol_center + Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
	point.y = _sample_floor_y(point, patrol_center.y)
	return point


func _sample_floor_y(xz_pos: Vector3, fallback_y: float) -> float:
	var from := Vector3(xz_pos.x, fallback_y + 3.0, xz_pos.z)
	var to := Vector3(xz_pos.x, fallback_y - 2.0, xz_pos.z)
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [self]
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return fallback_y
	return (result["position"] as Vector3).y


func _enter_patrol() -> void:
	if russ_state == RussState.DEAD:
		return
	russ_state = RussState.PATROL
	patrol_target = _random_point_in_patrol_disc()
	patrol_timer = randf_range(patrol_repick_min, patrol_repick_max)


func _enter_investigate(pos: Vector3) -> void:
	if russ_state == RussState.DEAD:
		return
	russ_state = RussState.INVESTIGATE
	investigate_target = pos
	investigate_target.y = _sample_floor_y(investigate_target, patrol_center.y)
	investigate_timer = 8.0


func _enter_chase(target: CharacterBody3D) -> void:
	if russ_state == RussState.DEAD or target == null or _is_temporarily_friendly():
		return
	player_target = target
	last_known_player_pos = target.global_position
	russ_state = RussState.CHASE

func set_temporary_friendly(duration_seconds: float) -> void:
	_friendly_until = max(_friendly_until, (Time.get_ticks_msec() / 1000.0) + duration_seconds)
	if russ_state == RussState.CHASE or russ_state == RussState.ATTACK:
		_enter_patrol()

func _is_temporarily_friendly() -> bool:
	return (Time.get_ticks_msec() / 1000.0) < _friendly_until


func _enter_attack() -> void:
	if russ_state == RussState.DEAD:
		return
	russ_state = RussState.ATTACK


func _on_gunshot(shot_position: Vector3, alert_range: float) -> void:
	if russ_state == RussState.DEAD:
		return
	if global_position.distance_to(shot_position) > alert_range:
		return
	if russ_state == RussState.CHASE:
		return
	_enter_investigate(shot_position)


func hitscanHit(damageVal: float, _hitscanDir: Vector3, _hitscanPos: Vector3) -> void:
	if health_component and russ_state != RussState.DEAD:
		health_component.take_damage(damageVal)


func projectileHit(damageVal: float, _projectileDir: Vector3) -> void:
	if health_component and russ_state != RussState.DEAD:
		health_component.take_damage(damageVal)


func _on_enemy_death() -> void:
	russ_state = RussState.DEAD
	velocity.x = 0.0
	velocity.z = 0.0
	_death_timer = 3.0
	if collision_shape:
		collision_shape.disabled = true
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)
	if model_root:
		model_root.hide()
	if GameManager and xp_reward > 0:
		GameManager.add_xp(xp_reward)


func is_dead() -> bool:
	return russ_state == RussState.DEAD
