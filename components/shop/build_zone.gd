extends Area3D

@export var required_scraps: int = 5
@export var lemonade_stand_scene: PackedScene = preload("res://scenes/props/lemonade_stand.tscn")
@export var stand_spawn_offset: Vector3 = Vector3(0, 0, 0)
@export var debug_status_text: bool = true

@onready var prompt_label: Label3D = $Label3D
@onready var legacy_visual_mesh: MeshInstance3D = get_node_or_null("MeshInstance3D") as MeshInstance3D

var _scraps_in_zone: Array[RigidBody3D] = []
var _player_in_range: bool = false
var _stand_spawned: bool = false
var _activated: bool = false
var _preview: Node3D = null

func _ready() -> void:
	if not is_in_group("LemonadeBuildZone"):
		add_to_group("LemonadeBuildZone")

	# Player character runs on layer 2 in this project; listen for both world props and player.
	set_collision_mask_value(1, true)
	set_collision_mask_value(2, true)
	monitoring = true
	monitorable = true
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	prompt_label.hide()
	prompt_label.text = "E - Bygg bod"
	if legacy_visual_mesh:
		legacy_visual_mesh.hide()
	_hide_preview()

func activate_from_scrap_pickup() -> void:
	if _stand_spawned or _activated:
		return
	_activated = true
	_spawn_preview()

func _physics_process(_delta: float) -> void:
	_refresh_overlaps()
	_update_prompt()

func _input(_event: InputEvent) -> void:
	if not _can_build():
		return
	if Input.is_action_just_pressed("interaction"):
		_build_stand()

func _can_build() -> bool:
	return _activated and _player_in_range and _scraps_in_zone.size() >= required_scraps and not _stand_spawned

func _on_body_entered(_body: Node) -> void:
	_refresh_overlaps()
	_update_prompt()

func _on_body_exited(_body: Node) -> void:
	_refresh_overlaps()
	_update_prompt()

func _update_prompt() -> void:
	if not _activated or _stand_spawned:
		prompt_label.hide()
		return

	var build_ready := _can_build()
	if build_ready:
		prompt_label.text = "E - Bygg bod"
		prompt_label.show()
		return

	if debug_status_text and _player_in_range:
		prompt_label.text = "Trebit: %d/%d" % [_scraps_in_zone.size(), required_scraps]
		prompt_label.show()
		return

	prompt_label.hide()

func _refresh_overlaps() -> void:
	_player_in_range = false
	_scraps_in_zone.clear()
	if not _activated:
		return

	for body in get_overlapping_bodies():
		if body.is_in_group("PlayerCharacter"):
			_player_in_range = true
		elif body is RigidBody3D and body.is_in_group("WoodScrap"):
			_scraps_in_zone.append(body as RigidBody3D)

func _spawn_preview() -> void:
	if lemonade_stand_scene == null:
		return
	if _preview != null and is_instance_valid(_preview):
		_preview.show()
		return

	_preview = lemonade_stand_scene.instantiate() as Node3D
	if _preview:
		_preview.set("ghost_preview", true)
	add_child(_preview)
	_preview.global_position = global_position + stand_spawn_offset
	_make_preview_noninteractive(_preview)

func _hide_preview() -> void:
	if _preview != null and is_instance_valid(_preview):
		_preview.hide()

func _make_preview_noninteractive(node: Node) -> void:
	if node is CollisionObject3D:
		(node as CollisionObject3D).collision_layer = 0
		(node as CollisionObject3D).collision_mask = 0
	if node is Area3D:
		(node as Area3D).monitoring = false
		(node as Area3D).monitorable = false
	if node is RigidBody3D:
		(node as RigidBody3D).freeze = true
	if node is Node3D:
		_apply_preview_material_recursive(node as Node3D)
	for child in node.get_children():
		_make_preview_noninteractive(child)

func _apply_preview_material_recursive(n: Node3D) -> void:
	for child in n.get_children():
		if child is MeshInstance3D:
			var mi := child as MeshInstance3D
			var mat := StandardMaterial3D.new()
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color = Color(1, 1, 1, 0.22)
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
			mi.material_override = mat
		if child is Node3D:
			_apply_preview_material_recursive(child as Node3D)

func _build_stand() -> void:
	if lemonade_stand_scene == null:
		return
	_stand_spawned = true
	prompt_label.hide()
	_hide_preview()

	for scrap in _scraps_in_zone:
		if is_instance_valid(scrap):
			scrap.queue_free()
	_scraps_in_zone.clear()

	var stand := lemonade_stand_scene.instantiate()
	get_parent().add_child(stand)
	if stand is Node3D:
		(stand as Node3D).global_position = global_position + stand_spawn_offset
