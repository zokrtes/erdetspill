extends RigidBody3D

# Dedicated challenge target:
# despawns when hit so Iver challenge can count reliable target clears.

func hitscanHit(propulForce: float, propulDir: Vector3, propulPos: Vector3) -> void:
	var hit_pos: Vector3 = propulPos - global_transform.origin
	if propulDir != Vector3.ZERO:
		apply_impulse(propulDir * propulForce, hit_pos)
	call_deferred("queue_free")


func projectileHit(propulForce: float, propulDir: Vector3) -> void:
	if propulDir != Vector3.ZERO:
		apply_central_force((global_transform.origin - propulDir) * propulForce)
	call_deferred("queue_free")
