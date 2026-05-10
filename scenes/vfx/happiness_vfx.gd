extends Node3D

@onready var stars: GPUParticles3D = $StarParticles
@onready var hearts: GPUParticles3D = $HeartParticles

func play(pos: Vector3) -> void:
	global_position = pos
	stars.emitting = true
	await get_tree().create_timer(0.3).timeout
	hearts.emitting = true
	await get_tree().create_timer(max(stars.lifetime, hearts.lifetime) + 0.2).timeout
	queue_free()
