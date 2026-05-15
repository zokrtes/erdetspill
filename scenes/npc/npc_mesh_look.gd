extends Node3D

var player: Node3D


func _ready() -> void:
	player = get_tree().get_first_node_in_group("PlayerCharacter") as Node3D

@export var turn_speed := 5.0  # higher = faster turning

func _physics_process(delta):
	if player:
		var direction = player.global_transform.origin - global_transform.origin
		var target_angle = atan2(direction.x, direction.z)
		
		rotation.y = lerp_angle(rotation.y, target_angle, turn_speed * delta)
