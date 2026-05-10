extends Node

@export var normal_scene: PackedScene
@export var poster_scene: PackedScene

@export var poster_count: int = 10

func _ready() -> void:
	await get_tree().process_frame
	_spawn_all_lights()

func _spawn_all_lights() -> void:
	var all_spawns := get_tree().get_nodes_in_group("StreetlightSpawn")
	if all_spawns.is_empty():
		push_warning("No StreetlightSpawn markers")
		return

	var pool := all_spawns.duplicate()
	pool.shuffle()
	var assigned := {}

	var poster_assigned := 0
	for spawn in pool:
		if poster_assigned >= poster_count:
			break
		assigned[spawn] = "poster"
		poster_assigned += 1

	for spawn in all_spawns:
		if not assigned.has(spawn):
			assigned[spawn] = "normal"

	for spawn in all_spawns:
		var variant: String = assigned.get(spawn, "normal")
		var scene: PackedScene = poster_scene if variant == "poster" else normal_scene
		if scene == null:
			continue
		var light := scene.instantiate()
		get_tree().current_scene.add_child(light)
		if light is Node3D and spawn is Node3D:
			(light as Node3D).global_position = (spawn as Node3D).global_position
			(light as Node3D).global_rotation = (spawn as Node3D).global_rotation
