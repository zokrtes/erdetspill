extends Area3D
# tag: world grus ammo — E / interaction; adds grus_ammo to AmmunitionManager.
# AmmunitionManagerScript.gd: var ammoDict, var maxNbPerAmmoDict (same names on the node).

@export var ammo_amount: int = 5
@export var max_pickups: int = 3

var _pickup_count: int = 0
var _player_nearby: Node = null


func _ready() -> void:
	monitoring = true
	body_entered.connect(_on_entered)
	body_exited.connect(_on_exited)


func _on_entered(body: Node3D) -> void:
	if body.is_in_group("PlayerCharacter"):
		_player_nearby = body
		var label := get_node_or_null("Label3D") as Label3D
		if label:
			label.visible = true


func _on_exited(body: Node3D) -> void:
	if body.is_in_group("PlayerCharacter"):
		_player_nearby = null
		var label := get_node_or_null("Label3D") as Label3D
		if label:
			label.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if _player_nearby == null:
		return
	if not (event is InputEventKey or \
			event is InputEventJoypadButton):
		return
	if event.is_action_pressed("interaction"):
		_pickup()


func _pickup() -> void:
	if _pickup_count >= max_pickups:
		return
	var player := _player_nearby
	if player == null:
		return
	var wm: Node = null
	var wm_path: Variant = player.get("weapon_controller_path")
	if wm_path != null and wm_path != NodePath():
		wm = player.get_node_or_null(wm_path as NodePath)
	if wm == null:
		wm = player.get_node_or_null("WeaponManager")
	if wm == null:
		return
	var am: Node = wm.get("ammoManager") as Node
	if am == null:
		am = wm.get_node_or_null("AmmunitionManager")
	if am == null:
		return
	var cur: int = int(am.ammoDict.get("grus_ammo", 0))
	var cap: int = int(am.maxNbPerAmmoDict.get("grus_ammo", cur + ammo_amount))
	am.ammoDict["grus_ammo"] = mini(cap, cur + ammo_amount)
	_pickup_count += 1
	if wm.has_method("_refresh_reserve_dependent_weapon_meshes"):
		wm._refresh_reserve_dependent_weapon_meshes()
	if _pickup_count >= max_pickups:
		_player_nearby = null
		var label := get_node_or_null("Label3D") as Label3D
		if label:
			label.visible = false
		queue_free()
