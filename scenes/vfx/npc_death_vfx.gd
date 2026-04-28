extends Node3D

@onready var blood_particles: GPUParticles3D = $BloodParticles

const MEAT_CHUNK: PackedScene = preload("res://scenes/props/meat_chunk.tscn")


func play(spawn_position: Vector3) -> void:
	global_position = spawn_position
	blood_particles.restart()
	blood_particles.emitting = true
	_spawn_meat_chunks(spawn_position)
	await get_tree().create_timer(4.0).timeout
	queue_free()


func _spawn_meat_chunks(pos: Vector3) -> void:
	var parent_node: Node = get_tree().current_scene
	if parent_node == null:
		parent_node = get_tree().root
	for i in range(5):
		var chunk: RigidBody3D = MEAT_CHUNK.instantiate() as RigidBody3D
		parent_node.add_child(chunk)
		chunk.global_position = pos + Vector3(
			randf_range(-0.3, 0.3),
			randf_range(0.2, 0.8),
			randf_range(-0.3, 0.3))
		chunk.apply_central_impulse(Vector3(
			randf_range(-3.0, 3.0),
			randf_range(2.0, 5.0),
			randf_range(-3.0, 3.0)))
