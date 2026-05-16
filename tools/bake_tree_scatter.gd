@tool
extends EditorScript

## Run from Script Editor: File → Run (with ProtonScatter enabled).
## Bakes TreeScatter / TreeScatter3 under Elgveien into static MultiMeshInstance3D nodes.

const SCENE_PATH := "res://levels/main_demo.tscn"
const SCATTER_NAMES := ["TreeScatter", "TreeScatter3"]

const MMI_SETTINGS := {
	"cast_shadow": GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
	"visibility_range_end": 200.0,
	"visibility_range_end_margin": 20.0,
	"ignore_occlusion_culling": false,
}


func _run() -> void:
	if not ClassDB.class_exists("ProtonScatter"):
		push_error("Enable ProtonScatter: Project → Plugins → ProtonScatter.")
		return

	var root: Node = _get_scene_root()
	if root == null:
		push_error("Open %s in the editor first." % SCENE_PATH)
		return

	var baked := 0
	for scatter_name in SCATTER_NAMES:
		var scatter := root.find_child(scatter_name, true, false) as ProtonScatter
		if scatter == null:
			push_warning("Not found: %s" % scatter_name)
			continue
		if scatter.render_mode != 0:
			scatter.render_mode = 0
		scatter.full_rebuild()
		await scatter.build_completed
		_bake_scatter_node(scatter)
		baked += 1

	if baked == 0:
		push_error("Nothing baked.")
		return

	_mark_scene_edited(root)
	print("Baked %d scatter node(s). Save the scene (Ctrl+S)." % baked)


func _get_scene_root() -> Node:
	var edited := get_editor_interface().get_edited_scene_root()
	if edited != null:
		return edited
	var packed := load(SCENE_PATH) as PackedScene
	return packed.instantiate() if packed else null


func _bake_scatter_node(scatter: ProtonScatter) -> void:
	var parent := scatter.get_parent()
	if parent == null:
		return

	var forest := parent.get_node_or_null("BakedForest") as Node3D
	if forest == null:
		forest = Node3D.new()
		forest.name = "BakedForest"
		parent.add_child(forest)
		forest.owner = _scene_owner(parent)
		forest.set_meta("tag", "baked static forest — MultiMesh from ProtonScatter")

	var output := scatter.get_node_or_null("ScatterOutput")
	if output == null:
		push_warning("%s has no ScatterOutput. Rebuild scatter in editor first." % scatter.name)
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
		push_warning("Skipping empty multimesh: %s" % source.name)
		return

	var global_xf := source.global_transform
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "%s_%d" % [scatter_name, index]
	mmi.multimesh = source.multimesh.duplicate(true)
	mmi.material_override = source.material_override
	forest.add_child(mmi)
	mmi.owner = _scene_owner(forest)
	mmi.global_transform = global_xf

	mmi.cast_shadow = MMI_SETTINGS.cast_shadow
	mmi.visibility_range_end = MMI_SETTINGS.visibility_range_end
	mmi.visibility_range_end_margin = MMI_SETTINGS.visibility_range_end_margin
	mmi.ignore_occlusion_culling = MMI_SETTINGS.ignore_occlusion_culling


func _scene_owner(node: Node) -> Node:
	var n: Node = node
	while n != null:
		if n.owner != null:
			return n.owner
		n = n.get_parent()
	return node


func _mark_scene_edited(root: Node) -> void:
	if get_editor_interface().get_edited_scene_root() == root:
		get_editor_interface().mark_scene_as_unsaved()
