extends RigidBody3D

# tag: weapon projectile / explosion radius damage (includes PlayerCharacter / RPG self-damage).

#properties variables
var isExplosive : bool = false
var direction : Vector3 
var damage : float
var timeBeforeVanish : float 
var bodiesList : Array = []

const EXPLOSION_RADIUS: float = 6.0

#references variables
@onready var mesh = $Mesh
@onready var hitbox = $Hitbox

@export_group("Sound variables")
@onready var audioManager : PackedScene = preload("../../Misc/Scenes/AudioManagerScene.tscn")
@export var explosionSound : AudioStream

@export_group("Particles variables")
@onready var particlesManager : PackedScene = preload("../../Misc/Scenes/ParticlesManagerScene.tscn")

func _ready():
	# FIX: Ensure uniform scaling for Jolt Physics
	_fix_uniform_scale()
	
	# Optional: Disable gravity if not needed
	gravity_scale = 0.0

func _fix_uniform_scale():
	# Check if scale is non-uniform
	if scale.x != scale.y or scale.x != scale.z or scale.y != scale.z:
		print("Warning: Non-uniform scale detected (", scale, "). Fixing to uniform scale.")
		# Calculate uniform scale (use average)
		var uniformScale = (scale.x + scale.y + scale.z) / 3.0
		scale = Vector3(uniformScale, uniformScale, uniformScale)
		
		# If mesh needs non-uniform scaling, apply it to the mesh child instead
		if mesh and mesh is MeshInstance3D:
			# Store the desired visual scale
			var visualScale = Vector3(0.29, 0.29, 0.25)  # Your desired scale
			mesh.scale = visualScale

func _process(delta):
	if timeBeforeVanish > 0.0: 
		timeBeforeVanish -= delta
	else: 
		hit()
		
func _on_body_entered(body):
	# Prevent multiple hits
	if not hitbox.disabled:
		hit()
		applyDamage(body)

func hit():
	mesh.visible = false
	hitbox.set_deferred("disabled", true)
	
	if isExplosive: 
		explode()
	else:
		queue_free()

func applyDamage(body: Node, damage_scale: float = 1.0) -> void:
	if body == null or body in bodiesList:
		return
	var dmg: float = damage * damage_scale
	var dealt := false
	if body.is_in_group("Enemies") and body.has_method("projectileHit"):
		bodiesList.append(body)
		body.projectileHit(dmg, direction)
		dealt = true
	elif body.is_in_group("HitableObjects") and body.has_method("projectileHit"):
		bodiesList.append(body)
		body.projectileHit(dmg, direction)
		dealt = true
	elif body.is_in_group("PlayerCharacter"):
		bodiesList.append(body)
		var hc: Node = body.get_node_or_null("HealthComponent")
		if hc and hc.has_method("take_damage"):
			hc.take_damage(dmg)
		dealt = true
	if not dealt:
		return


func explode():
	weaponSoundManagement(explosionSound)
	
	var particlesIns = particlesManager.instantiate()
	particlesIns.particleToEmit = "Explosion"
	particlesIns.global_transform = global_transform
	get_tree().get_root().add_child(particlesIns)
	_apply_explosion_damage(global_transform.origin, EXPLOSION_RADIUS)
	queue_free()


func _apply_explosion_damage(center: Vector3, radius: float) -> void:
	var space := get_world_3d().direct_space_state
	if space == null:
		return
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = sphere
	params.transform = Transform3D(Basis(), center)
	params.collide_with_bodies = true
	params.collide_with_areas = false
	params.exclude = [get_rid()]
	var hits: Array = space.intersect_shape(params, 64)
	for hit in hits:
		var hit_dict: Dictionary = hit as Dictionary
		var collider: Object = hit_dict.get("collider")
		if collider == null or not (collider is Node3D):
			continue
		var n3: Node3D = collider as Node3D
		var dist: float = center.distance_to(n3.global_transform.origin)
		var falloff: float = clampf(1.0 - dist / maxf(radius, 0.001), 0.15, 1.0)
		applyDamage(collider as Node, falloff)


func weaponSoundManagement(soundName):
	if soundName != null:
		var audioIns = audioManager.instantiate()
		audioIns.global_transform = global_transform
		get_tree().get_root().add_child(audioIns)
		audioIns.bus = "Sfx"
		audioIns.volume_db = 5.0
		audioIns.stream = soundName
		audioIns.play()
