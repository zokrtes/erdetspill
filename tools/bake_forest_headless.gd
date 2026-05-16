extends SceneTree

## Headless bake (Godot console, project root):
##   godot --path . --headless --script res://tools/bake_forest_headless.gd

const SCENE_PATH := "res://levels/main_demo.tscn"
const SCATTER_NAMES := ["TreeScatter", "TreeScatter3"]
const WAIT_MS := 180000

const MMI_SETTINGS := {
	"cast_shadow": GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
	"visibility_range_end": 200.0,
	"visibility_range_end_margin": 20.0,
	"ignore_occlusion_culling": false,
}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var code := await _bake()
	quit(code)


func _bake() -> int:
	var packed := load(SCENE_PATH) as PackedScene
	if packed == null:
		push_error("Could not load %s" % SCENE_PATH)
		return 1

	var root: Node = packed.instantiate()
	_freeze_scene_logic(root)
	get_root().add_child(root)

	for _i in 5:
		await physics_frame
		await process_frame

	var scatters: Array[ProtonScatter] = []
	for scatter_name in SCATTER_NAMES:
		var scatter := root.find_child(scatter_name, true, false) as ProtonScatter
		if scatter == null:
			push_warning("Missing scatter: %s" % scatter_name)
			continue
		scatter.process_mode = Node.PROCESS_MODE_ALWAYS
		scatter.dbg_disable_thread = true
		if scatter.render_mode != 0:
			scatter.render_mode = 0
		scatters.append(scatter)

	if scatters.is_empty():
		push_error("No scatter nodes found.")
		root.queue_free()
		return 1

	for scatter in scatters:
		scatter.full_rebuild()
		if not await _wait_for_scatter(scatter):
			push_error("Timed out waiting for %s rebuild." % scatter.name)
			root.queue_free()
			return 1
		_bake_scatter_node(scatter)

	var out := PackedScene.new()
	var pack_err := out.pack(root)
	root.queue_free()
	if pack_err != OK:
		push_error("pack() failed: %s" % error_string(pack_err))
		return 1

	var save_err := ResourceSaver.save(out, SCENE_PATH)
	if save_err != OK:
		push_error("save failed: %s" % error_string(save_err))
		return 1

	print("Baked %d scatter node(s) into %s" % [scatters.size(), SCENE_PATH])
	return 0


func _freeze_scene_logic(root: Node) -> void:
	_set_process_mode_recursive(root, Node.PROCESS_MODE_DISABLED)
	for scatter_name in SCATTER_NAMES:
		var scatter := root.find_child(scatter_name, true, false)
		if scatter:
			_enable_process_branch(scatter)


func _set_process_mode_recursive(node: Node, mode: Node.ProcessMode) -> void:
	node.process_mode = mode
	for child in node.get_children():
		_set_process_mode_recursive(child, mode)


func _enable_process_branch(node: Node) -> void:
	var current: Node = node
	while current:
		current.process_mode = Node.PROCESS_MODE_INHERIT
		current = current.get_parent()
	node.process_mode = Node.PROCESS_MODE_ALWAYS
	_set_process_mode_recursive(node, Node.PROCESS_MODE_INHERIT)


func _wait_for_scatter(scatter: ProtonScatter) -> bool:
	var deadline := Time.get_ticks_msec() + WAIT_MS
	while Time.get_ticks_msec() < deadline:
		if scatter.is_thread_running():
			await physics_frame
			await process_frame
			continue
		var output := scatter.get_node_or_null("ScatterOutput")
		if output and output.get_child_count() > 0:
			var has_mm := false
			for item_root in output.get_children():
				if not _find_multimeshes(item_root).is_empty():
					has_mm = true
					break
			if has_mm:
				return true
		await physics_frame
		await process_frame
	return false


func _bake_scatter_node(scatter: ProtonScatter) -> void:
	var parent := scatter.get_parent()
	if parent == null:
		return

	var forest := parent.get_node_or_null("BakedForest") as Node3D
	if forest == null:
		forest = Node3D.new()
		forest.name = "BakedForest"
		parent.add_child(forest)
		forest.owner = parent
		forest.set_meta("tag", "baked static forest — MultiMesh from ProtonScatter")

	var output := scatter.get_node_or_null("ScatterOutput")
	if output == null:
		push_warning("%s has no ScatterOutput after rebuild." % scatter.name)
		parent.remove_child(scatter)
		scatter.free()
		return

	var index := 0
	for item_root in output.get_children():
		for mmi in _find_multimeshes(item_root):
			_duplicate_mmi(mmi, forest, scatter.name, index)
			index += 1

	parent.remove_child(scatter)
	scatter.free()


func _find_multimeshes(node: Node) -> Array[MultiMeshInstance3D]:
	var found: Array[MultiMeshInstance3D] = []
	if node is MultiMeshInstance3D:
		found.append(node)
	for child in node.get_children():
		found.append_array(_find_multimeshes(child))
	return found


func _duplicate_mmi(source: MultiMeshInstance3D, forest: Node3D, scatter_name: String, index: int) -> void:
	if source.multimesh == null or source.multimesh.mesh == null:
		push_warning("Skipping empty multimesh under %s" % scatter_name)
		return

	var mmi := MultiMeshInstance3D.new()
	mmi.name = "%s_%d" % [scatter_name, index]
	mmi.multimesh = source.multimesh.duplicate(true)
	mmi.material_override = source.material_override
	forest.add_child(mmi)
	mmi.owner = forest
	mmi.global_transform = source.global_transform
	mmi.cast_shadow = MMI_SETTINGS.cast_shadow
	mmi.visibility_range_end = MMI_SETTINGS.visibility_range_end
	mmi.visibility_range_end_margin = MMI_SETTINGS.visibility_range_end_margin
	mmi.ignore_occlusion_culling = MMI_SETTINGS.ignore_occlusion_culling
