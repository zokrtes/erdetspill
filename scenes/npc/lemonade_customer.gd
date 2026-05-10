extends CharacterBody3D

enum CustomerState {
	WALKING_PAST,
	APPROACHING,
	AT_COUNTER,
	LEAVING,
}

@export var move_speed: float = 2.2
@export var character_model: PackedScene

var customer_name: String = "Kunde"
var customer_state: CustomerState = CustomerState.WALKING_PAST
var walk_direction: Vector3 = Vector3.RIGHT
var stand_position: Vector3 = Vector3.ZERO
var counter_position: Vector3 = Vector3.ZERO
var stand_ref: Node = null
var _decision_made: bool = false
var _arrival_notified: bool = false


func _ready() -> void:
	if not is_in_group("LemonadeCustomer"):
		add_to_group("LemonadeCustomer")
	_ensure_model_root()
	_setup_model()


func setup_customer(name_text: String) -> void:
	customer_name = name_text


func setup(counter_pos: Vector3, stand: Node) -> void:
	counter_position = counter_pos
	stand_ref = stand
	if stand is Node3D:
		stand_position = (stand as Node3D).global_position
	else:
		stand_position = counter_pos
	customer_state = CustomerState.WALKING_PAST
	_decision_made = false
	_arrival_notified = false
	walk_direction = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-0.2, 0.2)).normalized()
	if walk_direction.length_squared() < 0.001:
		walk_direction = Vector3.RIGHT


func set_model(model_scene: PackedScene) -> void:
	character_model = model_scene
	_setup_model()


func leave() -> void:
	if customer_state == CustomerState.LEAVING:
		return
	customer_state = CustomerState.LEAVING
	if stand_ref and stand_ref.has_method("on_customer_leaving"):
		stand_ref.call("on_customer_leaving", self)


func _setup_model() -> void:
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


func _horizontal_dist_to(pos: Vector3) -> float:
	var a := Vector3(global_position.x, 0.0, global_position.z)
	var b := Vector3(pos.x, 0.0, pos.z)
	return a.distance_to(b)


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0


func _try_step_up(move_dir: Vector3) -> void:
	if not is_on_floor():
		return
	if customer_state != CustomerState.APPROACHING and customer_state != CustomerState.WALKING_PAST:
		return
	if move_dir.length_squared() < 0.0001:
		return
	var knee_origin := global_position + Vector3(0.0, 0.15, 0.0)
	var knee_end := knee_origin + move_dir.normalized() * 0.4
	var sq := PhysicsRayQueryParameters3D.create(knee_origin, knee_end)
	sq.exclude = [self]
	var hit := get_world_3d().direct_space_state.intersect_ray(sq)
	if not hit.is_empty():
		velocity.y = max(velocity.y, 3.0)


func _physics_process(delta: float) -> void:
	_apply_gravity(delta)

	match customer_state:
		CustomerState.WALKING_PAST:
			velocity.x = walk_direction.x * move_speed
			velocity.z = walk_direction.z * move_speed
			_try_step_up(Vector3(velocity.x, 0.0, velocity.z))
			if stand_position != Vector3.ZERO:
				var dist_stand := _horizontal_dist_to(stand_position)
				if dist_stand < 4.0 and not _decision_made:
					_decision_made = true
					if randf() < 0.6:
						customer_state = CustomerState.APPROACHING
					else:
						pass
				elif dist_stand > 42.0:
					queue_free()
			if walk_direction.length_squared() > 0.0001:
				look_at(global_position + walk_direction.normalized(), Vector3.UP)
			move_and_slide()

		CustomerState.APPROACHING:
			var to_counter := counter_position - global_position
			to_counter.y = 0.0
			if to_counter.length_squared() < 0.0001:
				velocity.x = 0.0
				velocity.z = 0.0
				move_and_slide()
				return
			var dir := to_counter.normalized()
			velocity.x = dir.x * move_speed
			velocity.z = dir.z * move_speed
			_try_step_up(dir)
			look_at(global_position + dir, Vector3.UP)
			if global_position.distance_to(counter_position) < 1.2:
				customer_state = CustomerState.AT_COUNTER
				velocity.x = 0.0
				velocity.z = 0.0
				if not _arrival_notified and stand_ref and stand_ref.has_method("on_customer_arrived"):
					_arrival_notified = true
					stand_ref.call("on_customer_arrived", self)
			move_and_slide()

		CustomerState.AT_COUNTER:
			if not is_on_floor():
				velocity.y -= 9.8 * delta
			else:
				velocity.y = 0.0
			velocity.x = 0.0
			velocity.z = 0.0
			move_and_slide()

		CustomerState.LEAVING:
			var leave_target := global_position + walk_direction.normalized() * 20.0
			leave_target.y = global_position.y
			var to_leave := leave_target - global_position
			to_leave.y = 0.0
			if to_leave.length_squared() > 0.0001:
				var ldir := to_leave.normalized()
				velocity.x = ldir.x * move_speed * 1.5
				velocity.z = ldir.z * move_speed * 1.5
				_try_step_up(ldir)
				look_at(global_position + ldir, Vector3.UP)
			if _horizontal_dist_to(stand_position) > 15.0:
				queue_free()
			move_and_slide()
