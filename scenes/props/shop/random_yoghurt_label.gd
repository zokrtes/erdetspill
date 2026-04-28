extends MeshInstance3D

## Random label on surface 1; surface 0 uses the paired cap albedo (no runtime sampling).

const _LABEL_VARIANTS := [
	{
		"label": preload("res://assets/textures/images/god_morgen_yoghurt.png"),
		"cap_color": Color(0.9063355, 0, 0.022646217, 1),
	},
	{
		"label": preload("res://assets/textures/images/god_morgen_yoghurt_vanilla.png"),
		"cap_color": Color(0.92, 0.88, 0.78, 1),
	},
	{
		"label": preload("res://assets/textures/images/god_morgen_yoghurt_yellow.png"),
		"cap_color": Color(0.95, 0.82, 0.15, 1),
	},
	{
		"label": preload("res://assets/textures/images/god_morgen_yoghurt_purple.png"),
		"cap_color": Color(0.5, 0.22, 0.65, 1),
	},
]


func _ready() -> void:
	if _LABEL_VARIANTS.is_empty():
		return
	var entry: Dictionary = _LABEL_VARIANTS[randi() % _LABEL_VARIANTS.size()]
	var tex: Texture2D = entry["label"] as Texture2D
	var cap_color: Color = entry["cap_color"] as Color
	if tex == null:
		return

	var cap_base: StandardMaterial3D = get_surface_override_material(0) as StandardMaterial3D
	if cap_base:
		var cap_mat := cap_base.duplicate() as StandardMaterial3D
		cap_mat.albedo_color = cap_color
		set_surface_override_material(0, cap_mat)

	var label_base: StandardMaterial3D = get_surface_override_material(1) as StandardMaterial3D
	if label_base:
		var label_mat := label_base.duplicate() as StandardMaterial3D
		label_mat.albedo_texture = tex
		set_surface_override_material(1, label_mat)
