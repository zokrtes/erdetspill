extends CharacterBody3D

enum States {
	Walking,
	Pursuit,
	Attacking,
	Dead
}

enum AttackType {
	MELEE,
	HITSCAN,
	PROJECTILE
}

@export_category("Movement")
@export var walkSpeed : float = 2.0
@export var runSpeed : float = 5.0

@export_category("Attack")
@export var attack_type : AttackType = AttackType.MELEE
@export var attack_range : float = 2.0
@export var attack_cooldown : float = 1.0

@export_category("Attack Ranges")
@export var melee_range : float = 2.0
@export var hitscan_range : float = 23.0
@export var projectile_range : float = 12.0

@export_category("Facing")
@export var facing_tolerance : float = 15.0  # Degrees tolerance (15 = quite strict, 30 = forgiving)
@export var detection_range: float = 20.0
@export var lose_sight_range: float = 24.0

# Weapon resource for ranged attacks (assign in inspector)
@export var enemy_weapon : Resource

# Melee specific
@export var melee_knockback : float = 5.0
@export var melee_damage : float = 10.0

@export_category("Ragdoll")
@export var ragdoll_force : float = 5.0
@export var ragdoll_torque : float = 10.0
@export var ragdoll_lifetime : float = 3.0
@export var drop_item_id: String = ""
@export var drop_item_amount: int = 1

@export_category("Audio")
@export var attack_sound: AudioStream
@export var death_sound: AudioStream
@export var hurt_sound: AudioStream

@export_category("Colors")
@export var use_color_override: bool = false
@export var melee_color : Color = Color(1.0, 0.2, 0.2, 1.0)         # Red
@export var hitscan_color : Color = Color(0.2, 1.0, 0.2, 1.0)       # Green
@export var projectile_color : Color = Color(0.2, 0.2, 1.0, 1.0)    # Blue
@export var attacking_color : Color = Color(1.0, 0.0, 0.0, 1.0)     # Bright red when attacking

@onready var follow_target_3d: FollowTarget3D = $FollowTarget3D
@onready var random_target_3d: RandomTarget3D = $RandomTarget3D
@onready var health_component: HealthComponent = $HealthComponent
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var geometry_node: Node3D = get_node_or_null("Geometry") as Node3D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var weapon_slot: Node3D = $WeaponSlot  # Add a Node3D as weapon spawn point


var state : States = States.Walking
var target : Node3D
var can_attack : bool = true
var attack_timer : float = 0.0

var _is_flashing: bool = false
var _flash_originals: Array = []

func _ready() -> void:
	add_to_group("Enemies")
	ChangeState(States.Walking)
	if geometry_node == null:
		geometry_node = get_node_or_null("CrowGlbModel") as Node3D
	if geometry_node == null:
		for child in get_children():
			if child is Node3D and child != follow_target_3d and child != random_target_3d and child != collision_shape and child != weapon_slot:
				geometry_node = child as Node3D
				break
	if collision_shape and collision_shape.position != Vector3.ZERO:
		collision_shape.position = Vector3.ZERO
	
	if health_component:
		health_component.connect("on_death", _on_enemy_death)

	var sfx := AudioStreamPlayer3D.new()
	sfx.name = "SFX"
	sfx.max_distance = 20.0
	sfx.unit_size = 5.0
	add_child(sfx)

	_update_mesh_color()  # Add this

func _process(delta: float) -> void:
	if state == States.Dead:
		return
	
	if not can_attack:
		attack_timer -= delta
		if attack_timer <= 0:
			can_attack = true
	
	if not is_on_floor():
		velocity += get_gravity() * delta

func _physics_process(delta: float) -> void:
	if state == States.Dead:
		return
	_update_target_tracking()
	if state == States.Pursuit and target != null:
		var look_dir := target.global_position - global_position
		look_dir.y = 0.0
		if look_dir.length() > 0.1:
			var desired_y := atan2(-look_dir.x, -look_dir.z)
			rotation.y = lerp_angle(rotation.y, desired_y, 0.1)
	
	if target and state != States.Attacking:
		var distance_to_target = global_position.distance_to(target.global_position)
		
		# Get attack range based on attack type
		var current_attack_range = attack_range
		match attack_type:
			AttackType.MELEE:
				current_attack_range = melee_range
			AttackType.HITSCAN:
				current_attack_range = hitscan_range
			AttackType.PROJECTILE:
				current_attack_range = projectile_range
		
		# Melee should be distance-only. Ranged attacks still require facing.
		var can_attack_target := false
		if attack_type == AttackType.MELEE:
			can_attack_target = distance_to_target <= current_attack_range
		else:
			can_attack_target = distance_to_target <= current_attack_range and is_facing_target()
		if can_attack_target:
			ChangeState(States.Attacking)

	if is_on_floor() and velocity.length() > 0.3:
		var move_dir := Vector3(velocity.x, 0.0, velocity.z)
		if move_dir.length_squared() > 0.0001:
			move_dir = move_dir.normalized()
			var knee_origin := global_position + Vector3(0.0, 0.15, 0.0)
			var knee_end := knee_origin + move_dir * 0.4
			var sq := PhysicsRayQueryParameters3D.create(knee_origin, knee_end)
			sq.exclude = [self]
			var hit := get_world_3d().direct_space_state.intersect_ray(sq)
			if not hit.is_empty():
				velocity.y = maxf(velocity.y, 3.5)

	move_and_slide()


func _update_target_tracking() -> void:
	var player := get_tree().get_first_node_in_group("PlayerCharacter") as Node3D
	if player == null:
		if state != States.Attacking:
			ChangeState(States.Walking)
		return

	if target != null and (not is_instance_valid(target) or target == self):
		target = null

	if target == null:
		var distance_to_player := global_position.distance_to(player.global_position)
		if distance_to_player <= detection_range:
			target = player
			if state != States.Attacking:
				ChangeState(States.Pursuit)
		return

	if target == player:
		var distance_to_player := global_position.distance_to(player.global_position)
		if distance_to_player > lose_sight_range and state != States.Attacking:
			target = null
			ChangeState(States.Walking)
	
func _update_mesh_color():
	if not use_color_override:
		return
	if not geometry_node:
		return
	
	var target_color : Color
	
	# When attacking - show red
	if state == States.Attacking:
		target_color = attacking_color
	else:
		# Show attack type color
		match attack_type:
			AttackType.MELEE:
				target_color = melee_color
			AttackType.HITSCAN:
				target_color = hitscan_color
			AttackType.PROJECTILE:
				target_color = projectile_color
	
	_apply_color_to_meshes(geometry_node, target_color)

func _apply_color_to_meshes(node: Node, color: Color):
	for child in node.get_children():
		if child is MeshInstance3D:
			var material = StandardMaterial3D.new()
			material.albedo_color = color
			child.material_override = material
		elif child.get_child_count() > 0:
			_apply_color_to_meshes(child, color)
			
func is_facing_target() -> bool:
	if not target:
		return false
	
	# Get direction to target
	var target_direction = (target.global_position - global_position).normalized()
	
	# Get enemy's forward direction (assuming Z is forward, change if needed)
	var forward_direction = -global_transform.basis.z  # For Godot, forward is -Z
	
	# Calculate angle between directions
	var angle = forward_direction.angle_to(target_direction)
	
	# Convert to degrees
	var angle_degrees = rad_to_deg(angle)
	
	# Check if within tolerance
	return angle_degrees <= facing_tolerance
	
	
func ChangeState(newState : States) -> void:
	if state == States.Dead:
		return
		
	state = newState
	_update_mesh_color()  # Add this - updates color when state changes
	match state:
		States.Walking:
			follow_target_3d.ClearTarget()
			follow_target_3d.Speed = walkSpeed
			follow_target_3d.SetFixedTarget(random_target_3d.GetNextPoint())
			target = null
			
		States.Pursuit:
			follow_target_3d.Speed = runSpeed
			follow_target_3d.SetTarget(target)
			
		States.Attacking:
			follow_target_3d.ClearTarget()
			velocity = Vector3.ZERO
			_perform_attack()
			
		States.Dead:
			follow_target_3d.ClearTarget()
			velocity = Vector3.ZERO

func _perform_attack():
	if not can_attack or not target:
		ChangeState(States.Pursuit)
		return
	
	can_attack = false
	attack_timer = attack_cooldown
	_play_sfx(attack_sound)

	if animation_player and animation_player.has_animation("attack"):
		animation_player.play("attack")
	
	match attack_type:
		AttackType.MELEE:
			_melee_attack()
		AttackType.HITSCAN:
			_hitscan_attack()
		AttackType.PROJECTILE:
			_projectile_attack()
	
	await get_tree().create_timer(attack_cooldown).timeout
	if state == States.Attacking and not is_dead():
		ChangeState(States.Pursuit)

func _melee_attack():
	if not target:
		return
	
	var distance = global_position.distance_to(target.global_position)
	if distance <= melee_range:
		print("Melee attack! Damage: ", melee_damage)
		
		var health = target.get_node_or_null("HealthComponent")
		if health:
			health.take_damage(melee_damage)
		
		if target is CharacterBody3D:
			var knockback_dir = (target.global_position - global_position).normalized()
			knockback_dir.y = 0.2
			target.velocity += knockback_dir * melee_knockback

func _hitscan_attack():
	if not target or not enemy_weapon:
		return
	
	# Simple hitscan from enemy to player
	var space = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(weapon_slot.global_position, target.global_position)
	query.exclude = [self]
	
	var result = space.intersect_ray(query)
	
	if result and result.collider == target:
		print("Hitscan attack! Damage: ", enemy_weapon.damagePerProj)
		var health = target.get_node_or_null("HealthComponent")
		if health:
			health.take_damage(enemy_weapon.damagePerProj)

func _projectile_attack():
	if not target or not enemy_weapon or not enemy_weapon.projRef:
		return
	
	print("Projectile attack!")
	
	var projInstance = enemy_weapon.projRef.instantiate()
	var direction = (target.global_position - weapon_slot.global_position).normalized()
	
	# Add to scene
	get_tree().root.add_child(projInstance)
	
	# Set global transform to weapon_slot's global transform
	projInstance.global_transform = weapon_slot.global_transform
	projInstance.direction = direction
	projInstance.damage = enemy_weapon.damagePerProj
	projInstance.timeBeforeVanish = enemy_weapon.projTimeBeforeVanish
	projInstance.gravity_scale = enemy_weapon.projGravityVal
	projInstance.isExplosive = enemy_weapon.isProjExplosive
	
	if projInstance is RigidBody3D:
		projInstance.linear_velocity = direction * enemy_weapon.projMoveSpeed

func _on_follow_target_3d_navigation_finished() -> void:
	if state != States.Dead and state != States.Attacking:
		follow_target_3d.SetFixedTarget(random_target_3d.GetNextPoint())

func hitscanHit(damageVal : float, _hitscanDir : Vector3, _hitscanPos : Vector3):
	if health_component and state != States.Dead:
		health_component.take_damage(damageVal)
		_play_sfx(hurt_sound)
		_flash_hit()

func projectileHit(damageVal : float, _projectileDir : Vector3):
	if health_component and state != States.Dead:
		health_component.take_damage(damageVal)
		_play_sfx(hurt_sound)
		_flash_hit()

func _on_enemy_death():
	_play_sfx(death_sound)
	print("Enemy died!")
	state = States.Dead
	_drop_hunt_item()
	
	target = null
	follow_target_3d.ClearTarget()
	velocity = Vector3.ZERO
	
	if collision_shape:
		collision_shape.disabled = true
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)
	
	_convert_to_rigidbody()
	
	await get_tree().create_timer(0.1).timeout
	queue_free()

func _drop_hunt_item() -> void:
	if drop_item_id == "" or GameManager == null:
		return
	var amount := max(1, drop_item_amount)
	GameManager.add_item(drop_item_id, amount)
	if drop_item_id == "fugleskinn":
		print("🐦 Fugleskinn dropped")
	elif drop_item_id == "elgskinn":
		print("🦌 Elgskinn dropped")

func _convert_to_rigidbody():
	var rigid_body = RigidBody3D.new()
	rigid_body.name = "Ragdoll_" + name
	rigid_body.global_transform = global_transform
	
	var new_collision = CollisionShape3D.new()
	if collision_shape and collision_shape.shape:
		new_collision.shape = collision_shape.shape.duplicate()
		rigid_body.add_child(new_collision)
	
	if geometry_node:
		geometry_node.get_parent().remove_child(geometry_node)
		rigid_body.add_child(geometry_node)
	
	get_tree().root.add_child(rigid_body)
	
	rigid_body.apply_central_impulse(Vector3(
		randf_range(-ragdoll_force, ragdoll_force),
		randf_range(ragdoll_force * 0.5, ragdoll_force),
		randf_range(-ragdoll_force, ragdoll_force)
	))
	
	rigid_body.apply_torque(Vector3(
		randf_range(-ragdoll_torque, ragdoll_torque),
		randf_range(-ragdoll_torque, ragdoll_torque),
		randf_range(-ragdoll_torque, ragdoll_torque)
	))
	
	var timer = Timer.new()
	timer.wait_time = ragdoll_lifetime
	timer.one_shot = true
	timer.timeout.connect(func(): 
		if rigid_body and is_instance_valid(rigid_body):
			rigid_body.queue_free()
	)
	rigid_body.add_child(timer)
	timer.start()

func is_dead() -> bool:
	return state == States.Dead


func _play_sfx(stream: AudioStream) -> void:
	if stream == null:
		return
	var sfx := get_node_or_null("SFX") as AudioStreamPlayer3D
	if sfx == null:
		return
	sfx.stream = stream
	sfx.play()


func _collect_meshes(node: Node, result: Array) -> void:
	if node == null:
		return
	if node is MeshInstance3D:
		result.append(node)
	for child in node.get_children():
		_collect_meshes(child, result)


func _flash_hit() -> void:
	if _is_flashing or geometry_node == null:
		return
	_is_flashing = true
	var meshes: Array = []
	_collect_meshes(geometry_node, meshes)
	if meshes.is_empty():
		_is_flashing = false
		return
	_flash_originals.clear()
	for m in meshes:
		var mi := m as MeshInstance3D
		_flash_originals.append(mi.get_surface_override_material(0))
		var flash := StandardMaterial3D.new()
		flash.albedo_color = Color(1, 0, 0, 1)
		flash.emission_enabled = true
		flash.emission = Color(1, 0, 0, 1)
		flash.emission_energy_multiplier = 2.0
		mi.set_surface_override_material(0, flash)
	get_tree().create_timer(0.08).timeout.connect(func (): _end_flash_hit(meshes), CONNECT_ONE_SHOT)


func _end_flash_hit(meshes: Array) -> void:
	for i in meshes.size():
		var mi := meshes[i] as MeshInstance3D
		if is_instance_valid(mi):
			var orig: Material = _flash_originals[i] as Material
			mi.set_surface_override_material(0, orig)
	_flash_originals.clear()
	_is_flashing = false
	if use_color_override:
		_update_mesh_color()
