extends Node

@export var sun: DirectionalLight3D
@export var world_env: WorldEnvironment

# Time of day as 0.0 to 1.0
# 0.0 = midnight
# 0.25 = sunrise (6am)
# 0.5 = midday (12pm)
# 0.75 = sunset (6pm)
# 1.0 = midnight again
var time_of_day: float = 0.35


func _ready() -> void:
	add_to_group("LightingCycle")
	if sun == null:
		sun = get_tree().get_first_node_in_group("SunLight") as DirectionalLight3D
	if sun == null:
		sun = _find_node_by_class(get_tree().root, "DirectionalLight3D") as DirectionalLight3D
	if world_env == null:
		world_env = get_tree().get_first_node_in_group("WorldEnvironment") as WorldEnvironment
	if world_env == null:
		world_env = _find_node_by_class(get_tree().root, "WorldEnvironment") as WorldEnvironment
	print("LightingCycle Sun: ", sun)
	print("LightingCycle WorldEnv: ", world_env)
	print("LightingCycle day_duration_seconds: ", GameManager.day_duration_seconds)
	if GameManager.has_signal("day_changed"):
		GameManager.day_changed.connect(_on_day_changed)
	_apply_lighting(time_of_day)


func _process(delta: float) -> void:
	var day_duration := GameManager.day_duration_seconds
	if day_duration > 0.0:
		time_of_day += delta / day_duration
		if time_of_day >= 1.0:
			time_of_day -= 1.0
	_apply_lighting(time_of_day)


func _on_day_changed(_new_day: int) -> void:
	time_of_day = 0.25
	_apply_lighting(time_of_day)


func _apply_lighting(t: float) -> void:
	if sun == null or world_env == null:
		return

	# Sun rotation
	var sun_angle := (t - 0.25) * 360.0
	var sun_x := -90.0 + cos(deg_to_rad(sun_angle)) * 70.0
	sun_x = clamp(sun_x, -180.0, 0.0)
	sun.rotation_degrees.x = sun_x
	sun.rotation_degrees.y = sin(deg_to_rad(sun_angle)) * 45.0

	# Norwegian summer lighting
	# t = 0.0  midnight (never fully dark)
	# t = 0.25 sunrise ~6am (already bright)
	# t = 0.5  midday
	# t = 0.75 sunset ~18:00 (stays light until ~22)
	# t = 0.875 late evening ~21:00 (blue dusk)
	# t = 0.95 night ~23:00 (dim blue, not black)
	var sun_color: Color
	var sun_energy: float
	var sky_top: Color
	var sky_horizon: Color
	var ambient_energy: float

	if t < 0.15:
		# Late night / early morning 00:00-03:36
		# Norwegian summer - never fully dark
		# Dim blue twilight always visible
		sun_color = Color(0.6, 0.7, 1.0)
		sun_energy = 0.15
		sky_top = Color(0.05, 0.07, 0.18)
		sky_horizon = Color(0.15, 0.18, 0.32)
		ambient_energy = 0.12
	elif t < 0.25:
		# Early morning 03:36-06:00
		# Brightening blue-white sky
		var p := (t - 0.15) / 0.1
		sun_color = Color(0.6, 0.7, 1.0).lerp(Color(1.0, 0.92, 0.75), p)
		sun_energy = lerp(0.15, 0.8, p)
		sky_top = Color(0.05, 0.07, 0.18).lerp(Color(0.3, 0.45, 0.65), p)
		sky_horizon = Color(0.15, 0.18, 0.32).lerp(Color(0.6, 0.7, 0.8), p)
		ambient_energy = lerp(0.12, 0.35, p)
	elif t < 0.55:
		# Morning to midday 06:00-13:12
		# Bright white-warm Norwegian daylight
		# Slightly overcast grey-blue sky
		sun_color = Color(1.0, 0.97, 0.88)
		sun_energy = 1.3
		sky_top = Color(0.38, 0.52, 0.68)
		sky_horizon = Color(0.6, 0.72, 0.82)
		ambient_energy = 0.45
	elif t < 0.7:
		# Afternoon 13:12-16:48
		# Still bright, very slight warm shift
		# NO RED - just slightly warmer white
		var p := (t - 0.55) / 0.15
		sun_color = Color(1.0, 0.97, 0.88).lerp(Color(1.0, 0.93, 0.78), p)
		sun_energy = lerp(1.3, 1.1, p)
		sky_top = Color(0.38, 0.52, 0.68).lerp(Color(0.42, 0.55, 0.7), p)
		sky_horizon = Color(0.6, 0.72, 0.82)
		ambient_energy = lerp(0.45, 0.4, p)
	elif t < 0.83:
		# Evening 16:48-19:55
		# Warm golden light - NOT red, just golden
		# This is Norwegian summer evening light
		var p := (t - 0.7) / 0.13
		sun_color = Color(1.0, 0.93, 0.78).lerp(Color(1.0, 0.82, 0.5), p)
		sun_energy = lerp(1.1, 0.6, p)
		sky_top = Color(0.42, 0.55, 0.7).lerp(Color(0.25, 0.38, 0.58), p)
		sky_horizon = Color(0.6, 0.72, 0.82).lerp(Color(0.55, 0.62, 0.75), p)
		ambient_energy = lerp(0.4, 0.25, p)
	elif t < 0.92:
		# Late evening 19:55-22:05
		# Sun low, soft golden-white fading to blue
		# Still clearly light outside
		var p := (t - 0.83) / 0.09
		sun_color = Color(1.0, 0.82, 0.5).lerp(Color(0.7, 0.75, 1.0), p)
		sun_energy = lerp(0.6, 0.2, p)
		sky_top = Color(0.25, 0.38, 0.58).lerp(Color(0.08, 0.12, 0.28), p)
		sky_horizon = Color(0.55, 0.62, 0.75).lerp(Color(0.2, 0.25, 0.45), p)
		ambient_energy = lerp(0.25, 0.14, p)
	else:
		# Night 22:05-24:00
		# Norwegian summer night - BLUE not black
		# Always some light, never pitch dark
		var p := (t - 0.92) / 0.08
		sun_color = Color(0.7, 0.75, 1.0).lerp(Color(0.6, 0.7, 1.0), p)
		sun_energy = lerp(0.2, 0.15, p)
		sky_top = Color(0.08, 0.12, 0.28).lerp(Color(0.05, 0.07, 0.18), p)
		sky_horizon = Color(0.2, 0.25, 0.45).lerp(Color(0.15, 0.18, 0.32), p)
		ambient_energy = lerp(0.14, 0.12, p)

	# Apply sun
	sun.light_color = sun_color
	sun.light_energy = sun_energy

	# Apply sky
	var env := world_env.environment
	if env:
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = sky_horizon
		env.ambient_light_energy = ambient_energy
		var sky_mat = env.sky.sky_material if env.sky else null
		if sky_mat is ProceduralSkyMaterial:
			sky_mat.sky_top_color = sky_top
			sky_mat.sky_horizon_color = sky_horizon
			sky_mat.ground_horizon_color = sky_horizon.darkened(0.2)
			sky_mat.ground_bottom_color = sky_top.darkened(0.4)


func _find_node_by_class(node: Node, class_name_str: String) -> Node:
	if node.get_class() == class_name_str:
		return node
	for child in node.get_children():
		var found := _find_node_by_class(child, class_name_str)
		if found:
			return found
	return null
