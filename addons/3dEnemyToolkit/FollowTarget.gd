extends NavigationAgent3D
class_name FollowTarget3D

signal ReachedTarget(target: Node3D)

@export var Speed: float = 5.0
@export var TurnSpeed: float = 0.3
@export var ReachTargetMinDistance: float = 1.3

var target: Node3D
var isTargetSet: bool = false
var targetPosition: Vector3 = Vector3.ZERO
var lastTargetPosition: Vector3 = Vector3.ZERO
var fixedTarget: bool = false

@onready var parent: CharacterBody3D = get_parent() as CharacterBody3D


func _ready() -> void:
	velocity_computed.connect(_on_velocity_computed)


func _physics_process(_delta: float) -> void:
	if parent == null:
		return
	if fixedTarget:
		go_to_location(targetPosition)
	elif target:
		go_to_location(target.global_position)
		if parent.global_position.distance_to(target.global_position) <= ReachTargetMinDistance:
			ReachedTarget.emit(target)


func SetFixedTarget(newTarget: Vector3) -> void:
	target = null
	targetPosition = newTarget
	fixedTarget = true
	isTargetSet = true


func SetTarget(newTarget: Node3D) -> void:
	target = newTarget
	targetPosition = Vector3.ZERO
	fixedTarget = false
	isTargetSet = true


func ClearTarget() -> void:
	target = null
	targetPosition = Vector3.ZERO
	isTargetSet = false


func go_to_location(new_target_position: Vector3) -> void:
	if not isTargetSet or lastTargetPosition != new_target_position:
		set_target_position(new_target_position)
		lastTargetPosition = new_target_position
		isTargetSet = true

	var look_dir: float = atan2(-parent.velocity.x, -parent.velocity.z)
	parent.rotation.y = lerp_angle(parent.rotation.y, look_dir, TurnSpeed)

	if is_navigation_finished():
		isTargetSet = false
		return

	var next_path_position: Vector3 = get_next_path_position()
	var current_enemy_position: Vector3 = parent.global_position
	var new_velocity: Vector3 = (next_path_position - current_enemy_position).normalized() * Speed

	if avoidance_enabled:
		set_velocity(new_velocity.move_toward(new_velocity, 0.25))
	else:
		parent.velocity = new_velocity.move_toward(new_velocity, 0.25)


func _on_velocity_computed(safe_velocity: Vector3) -> void:
	if parent == null:
		return
	parent.velocity = parent.velocity.move_toward(safe_velocity, 0.25)
