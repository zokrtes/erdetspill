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

# Weapon resource for ranged attacks (assign in inspector)
@export var enemy_weapon : Resource

# Melee specific
@export var melee_knockback : float = 5.0
@export var melee_damage : float = 10.0

@export_category("Ragdoll")
@export var ragdoll_force : float = 5.0
@export var ragdoll_torque : float = 10.0
@export var ragdoll_lifetime : float = 3.0

@export_category("Colors")
@export var melee_color : Color = Color(1.0, 0.2, 0.2, 1.0)         # Red
@export var hitscan_color : Color = Color(0.2, 1.0, 0.2, 1.0)       # Green
@export var projectile_color : Color = Color(0.2, 0.2, 1.0, 1.0)    # Blue
@export var attacking_color : Color = Color(1.0, 0.0, 0.0, 1.0)     # Bright red when attacking

@onready var follow_target_3d: FollowTarget3D = $FollowTarget3D
@onready var random_target_3d: RandomTarget3D = $RandomTarget3D
@onready var health_component: HealthComponent = $HealthComponent
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var geometry_node: Node3D = $Geometry
@onready var vision_area: SimpleVision3D = $SimpleVision3D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var weapon_slot: Node3D = $WeaponSlot  # Add a Node3D as weapon spawn point


var state : States = States.Walking
var target : Node3D
var can_attack : bool = true
var attack_timer : float = 0.0

func _ready() -> void:
	add_to_group("Enemies")
	ChangeState(States.Walking)
	
	if health_component:
		health_component.connect("on_death", _on_enemy_death)
		
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
		
		# ONLY ATTACK IF WITHIN RANGE AND FACING TARGET
		if distance_to_target <= current_attack_range and is_facing_target():
			ChangeState(States.Attacking)
	
	move_and_slide()
	
func _update_mesh_color():
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

func _on_simple_vision_3d_get_sight(body: Node3D) -> void:
	if state != States.Dead and state != States.Attacking:
		target = body
		ChangeState(States.Pursuit)

func _on_simple_vision_3d_lost_sight() -> void:
	if state != States.Dead and state != States.Attacking:
		ChangeState(States.Walking)

func hitscanHit(damageVal : float, _hitscanDir : Vector3, _hitscanPos : Vector3):
	if health_component and state != States.Dead:
		health_component.take_damage(damageVal)
		
func projectileHit(damageVal : float, _projectileDir : Vector3):
	if health_component and state != States.Dead:
		health_component.take_damage(damageVal)

func _on_enemy_death():
	print("Enemy died!")
	state = States.Dead
	
	target = null
	follow_target_3d.ClearTarget()
	velocity = Vector3.ZERO
	
	if vision_area:
		vision_area.Enabled = false
	
	if collision_shape:
		collision_shape.disabled = true
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)
	
	_convert_to_rigidbody()
	
	await get_tree().create_timer(0.1).timeout
	queue_free()

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
