extends StaticBody3D

var is_destroyed: bool = false


func destroy_gate() -> void:
	if is_destroyed:
		return
	is_destroyed = true
	# Hide visible gate meshes.
	for child in get_children():
		if child is CSGBox3D or child is MeshInstance3D:
			child.visible = false
	# Disable gate collision.
	for child in get_children():
		if child is CollisionShape3D:
			child.disabled = true
	print("💥 Gate destroyed")


func projectileHit(damage: float, _dir: Vector3) -> void:
	# Only RPG explosions should be able to open the hideout.
	if damage >= 80.0:
		destroy_gate()
