extends Node3D


func play(at_pos: Vector3) -> void:
	global_position = at_pos
	var particles := get_node_or_null("Sparkles") as GPUParticles3D
	if particles:
		particles.restart()
		particles.emitting = true
	await get_tree().create_timer(1.5).timeout
	queue_free()
