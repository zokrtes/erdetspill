extends Node3D

@onready var player = get_node("/root/World/PlayerCharacter")

@export var turn_speed := 5.0  # higher = faster turning

func _physics_process(delta):
	if player:
		var direction = player.global_transform.origin - global_transform.origin
		var target_angle = atan2(direction.x, direction.z)
		
		rotation.y = lerp_angle(rotation.y, target_angle, turn_speed * delta)
