extends Node3D

@export var russ_scene: PackedScene
@export var is_hideout_spawner: bool = false
@export var spawn_count: int = 1
@export var patrol_radius: float = 8.0
@export var respawn_day_delay: int = 1

var _spawned_enemies: Array[Node] = []
var _death_day: int = -1
var _waiting_for_respawn: bool = false


func _ready() -> void:
	call_deferred("_spawn_all")
	if GameManager and GameManager.has_signal("day_changed"):
		GameManager.day_changed.connect(_on_day_changed)


func _spawn_all() -> void:
	for _i in range(spawn_count):
		_spawn_one()


func _spawn_one() -> void:
	if russ_scene == null:
		return
	if not is_inside_tree():
		return
	var russ = russ_scene.instantiate()
	var spawn_parent: Node = get_parent()
	if spawn_parent == null:
		return
	spawn_parent.add_child(russ)

	var offset := Vector3(randf_range(-2.0, 2.0), 0.0, randf_range(-2.0, 2.0))
	russ.global_position = global_position + offset
	russ.patrol_center = global_position
	russ.patrol_radius = patrol_radius

	if russ.has_method("_apply_difficulty"):
		russ.is_hideout_russ = is_hideout_spawner
		russ._apply_difficulty()

	var health = russ.get_node_or_null("HealthComponent")
	if health and health.has_signal("on_death"):
		health.on_death.connect(func() -> void: _on_russ_died(russ))

	_spawned_enemies.append(russ)


func _on_russ_died(russ: Node) -> void:
	_spawned_enemies.erase(russ)
	if not _waiting_for_respawn:
		_waiting_for_respawn = true
		var day_value = GameManager.get("current_day") if GameManager else null
		_death_day = int(day_value) if day_value != null else 0


func _on_day_changed(new_day: int) -> void:
	if not _waiting_for_respawn:
		return
	if new_day >= _death_day + respawn_day_delay:
		_waiting_for_respawn = false
		_death_day = -1
		print("Respawning Russ at: ", name)
		_spawn_all()
