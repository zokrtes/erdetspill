extends Node3D

const ICE_CREAM_SCENE: PackedScene = preload("res://scenes/props/shop/icecream_shop.tscn")

@onready var spawn_points: Array[Marker3D] = [
	$IceCreamSpawn1,
	$IceCreamSpawn2,
	$IceCreamSpawn3
]

var spawned_ice_creams: Array[RigidBody3D] = []

func _ready():
	if not is_in_group("ShopFreezer"):
		add_to_group("ShopFreezer")
	if not is_in_group("ShopShelfSection"):
		add_to_group("ShopShelfSection")
	spawned_ice_creams.resize(spawn_points.size())
	call_deferred("_spawn_ice_creams")

func _spawn_ice_creams():
	for i in range(spawn_points.size()):
		var point: Marker3D = spawn_points[i]
		var ice_cream := ICE_CREAM_SCENE.instantiate() as RigidBody3D
		get_tree().current_scene.add_child(ice_cream)
		await get_tree().process_frame
		ice_cream.global_position = point.global_position
		spawned_ice_creams[i] = ice_cream
		
func respawn_at_next_free_slot():
	for i in range(spawn_points.size()):
		if i >= spawned_ice_creams.size():
			spawned_ice_creams.resize(spawn_points.size())
		if not is_instance_valid(spawned_ice_creams[i]) or spawned_ice_creams[i] == null:
			var ice_cream := ICE_CREAM_SCENE.instantiate() as RigidBody3D
			get_tree().current_scene.add_child(ice_cream)
			ice_cream.global_position = spawn_points[i].global_position
			spawned_ice_creams[i] = ice_cream
			return

func handles_item(item_id: String) -> bool:
	return item_id == "icecream"

func respawn_returned_item():
	respawn_at_next_free_slot()

func on_item_removed(item: RigidBody3D):
	for i in range(spawned_ice_creams.size()):
		if spawned_ice_creams[i] == item:
			spawned_ice_creams[i] = null
			return
