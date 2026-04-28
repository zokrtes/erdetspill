extends CharacterBody3D

@export var move_speed: float = 2.2
@export var character_model: PackedScene

var customer_name: String = "Kunde"
var is_russ_customer: bool = false
var target_position: Vector3 = Vector3.ZERO
var stand_ref: Node = null
var has_reached_counter: bool = false

func _ready() -> void:
	if not is_in_group("LemonadeCustomer"):
		add_to_group("LemonadeCustomer")
	_ensure_model_root()
	_setup_model()


func setup_customer(name_text: String, russ: bool = false) -> void:
	customer_name = name_text
	is_russ_customer = russ
	if russ and not is_in_group("Russ"):
		add_to_group("Russ")
	elif not russ and is_in_group("Russ"):
		remove_from_group("Russ")


func setup(counter_pos: Vector3, stand: Node) -> void:
	target_position = counter_pos
	stand_ref = stand


func set_model(model_scene: PackedScene) -> void:
	character_model = model_scene
	_setup_model()


func _setup_model() -> void:
	# tag: character scale standard — all humanoids target 1.95m.
	if character_model == null:
		return
	var model_root := _ensure_model_root()
	if model_root == null:
		return
	for child in model_root.get_children():
		child.queue_free()
	var instance := character_model.instantiate()
	model_root.add_child(instance)
	var mesh_instance := _find_mesh(instance)
	if mesh_instance == null:
		return
	var aabb := mesh_instance.get_aabb()
	if aabb.size.y <= 0.0:
		return
	var factor := 1.95 / aabb.size.y
	if instance is Node3D:
		var model_3d := instance as Node3D
		model_3d.scale = Vector3(factor, factor, factor)
		model_3d.rotation_degrees.y = 180.0
		model_3d.position = Vector3(
			-(aabb.position.x + (aabb.size.x * 0.5)) * factor,
			-(aabb.position.y + (aabb.size.y * 0.5)) * factor,
			-(aabb.position.z + (aabb.size.z * 0.5)) * factor
		)


func _ensure_model_root() -> Node3D:
	var model_root := get_node_or_null("Model") as Node3D
	if model_root == null:
		model_root = Node3D.new()
		model_root.name = "Model"
		add_child(model_root)
	# Hide legacy placeholder mesh so customers never render as capsules.
	var placeholder_mesh := get_node_or_null("MeshInstance3D") as MeshInstance3D
	if placeholder_mesh:
		placeholder_mesh.visible = false
	return model_root


func _find_mesh(node: Node) -> MeshInstance3D:
	if node == null:
		return null
	if node is MeshInstance3D:
		return node as MeshInstance3D
	for child in node.get_children():
		var found := _find_mesh(child)
		if found != null:
			return found
	return null


func _physics_process(delta: float) -> void:
	if has_reached_counter:
		if not is_on_floor():
			velocity.y -= 9.8 * delta
		else:
			velocity.y = 0.0
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	if not is_on_floor():
		velocity.y -= 9.8 * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0

	var dist := global_position.distance_to(target_position)
	if dist < 1.2:
		has_reached_counter = true
		velocity.x = 0.0
		velocity.z = 0.0
		if stand_ref and stand_ref.has_method("on_customer_arrived"):
			stand_ref.call("on_customer_arrived", self)
		move_and_slide()
		return

	var dir := (target_position - global_position).normalized()
	dir.y = 0.0
	velocity.x = dir.x * move_speed
	velocity.z = dir.z * move_speed

	# Step up over small curbs / raised edges toward the stand.
	if is_on_floor() and not has_reached_counter:
		var move_dir := Vector3(velocity.x, 0.0, velocity.z).normalized()
		if move_dir != Vector3.ZERO:
			var knee_origin := global_position + Vector3(0.0, 0.15, 0.0)
			var knee_end := knee_origin + move_dir * 0.4
			var sq := PhysicsRayQueryParameters3D.create(knee_origin, knee_end)
			sq.exclude = [self]
			var hit := get_world_3d().direct_space_state.intersect_ray(sq)
			if not hit.is_empty():
				velocity.y = max(velocity.y, 3.0)

	look_at(global_position + dir, Vector3.UP)
	move_and_slide()
