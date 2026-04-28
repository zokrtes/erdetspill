extends RefCounted
class_name CarriablePickup

## Shared setup for anything the player can carry (shop items, hitable props, etc.).
## Player is on physics layer 2; carriables must mask layer 2 to be solid against the character.

const META_SAVED_LAYER := "_carry_saved_collision_layer"
const META_SAVED_MASK := "_carry_saved_collision_mask"

static func register(rigid: RigidBody3D) -> void:
	if not rigid.is_in_group("Carriable"):
		rigid.add_to_group("Carriable")
	rigid.set_collision_mask_value(2, true)

static func save_physics_before_carry(rigid: RigidBody3D) -> void:
	if rigid.has_meta(META_SAVED_LAYER):
		return
	rigid.set_meta(META_SAVED_LAYER, rigid.collision_layer)
	rigid.set_meta(META_SAVED_MASK, rigid.collision_mask)

static func restore_physics_after_drop(rigid: RigidBody3D) -> void:
	if rigid.has_meta(META_SAVED_LAYER):
		rigid.collision_layer = int(rigid.get_meta(META_SAVED_LAYER))
		rigid.collision_mask = int(rigid.get_meta(META_SAVED_MASK))
		rigid.remove_meta(META_SAVED_LAYER)
		rigid.remove_meta(META_SAVED_MASK)
	else:
		rigid.collision_layer = 1
		rigid.collision_mask = 1 | 2
