extends Node3D

@onready var particles: GPUParticles3D = $Particles

func play(pos: Vector3, hit_normal: Vector3 = Vector3.UP) -> void:
	global_position = pos
	var mat := particles.process_material as ParticleProcessMaterial
	if mat:
		mat.direction = hit_normal
	particles.emitting = true
	await get_tree().create_timer(particles.lifetime + 0.2).timeout
	queue_free()
