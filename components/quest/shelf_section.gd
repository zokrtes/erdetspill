extends Node3D

@export var item_scene: PackedScene
@export var spawn_points: Array[NodePath] = []
@export var handled_item_id: String = ""

var spawned_items: Array[RigidBody3D] = []

func _ready():
	if not is_in_group("ShopShelfSection"):
		add_to_group("ShopShelfSection")
	spawned_items.resize(spawn_points.size())
	call_deferred("_spawn_items")  # wait for scene tree to be ready

func _spawn_items():
	for i in range(spawn_points.size()):
		var point: Node3D = get_node_or_null(spawn_points[i])
		if point == null or item_scene == null:
			continue
		var item := item_scene.instantiate() as RigidBody3D
		get_tree().current_scene.add_child(item)
		await get_tree().process_frame  # wait for add_child to complete
		item.global_position = point.global_position
		spawned_items[i] = item

func respawn_returned_item():
	if item_scene == null:
		return
	for i in range(spawn_points.size()):
		if i >= spawned_items.size():
			spawned_items.resize(spawn_points.size())
		if not is_instance_valid(spawned_items[i]) or spawned_items[i] == null:
			var point: Node3D = get_node_or_null(spawn_points[i])
			if point == null:
				continue
			var item := item_scene.instantiate() as RigidBody3D
			get_tree().current_scene.add_child(item)
			item.global_position = point.global_position
			spawned_items[i] = item
			return

func handles_item(item_id: String) -> bool:
	return handled_item_id == item_id and handled_item_id != ""

func on_item_removed(item: RigidBody3D):
	for i in range(spawned_items.size()):
		if spawned_items[i] == item:
			spawned_items[i] = null
			return
