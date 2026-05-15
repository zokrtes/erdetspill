extends StaticBody3D
# tag: world weapon pickup — E / interaction only; not shop wall weapon.

@export var weapon_int_id: int = 6
@export var display_name: String = "Våpen"

var _player_nearby: Node = null
var _picked_up: bool = false


func _ready() -> void:
	var label := get_node_or_null("Label3D") as Label3D
	if label:
		label.text = "E — Ta " + display_name
		label.visible = false
	var area := get_node_or_null("InteractionArea") as Area3D
	if area:
		area.body_entered.connect(_on_entered)
		area.body_exited.connect(_on_exited)


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
	if _picked_up or _player_nearby == null:
		return
	if event.is_action_pressed("interaction"):
		_pick_up()
		get_viewport().set_input_as_handled()


func _pick_up() -> void:
	_picked_up = true
	var player := _player_nearby
	if player == null:
		return
	var wm_path: NodePath = player.get("weapon_controller_path") as NodePath
	var wm: Node = null
	if wm_path != NodePath():
		wm = player.get_node_or_null(wm_path)
	if wm == null:
		wm = player.get_node_or_null("WeaponManager")
	if wm and wm.has_method("acquire_weapon_by_id"):
		if int(weapon_int_id) in wm.weaponStack:
			pass
		else:
			wm.acquire_weapon_by_id(int(weapon_int_id))
	elif wm and "weaponStack" in wm:
		var wid := int(weapon_int_id)
		if not wid in wm.weaponStack:
			wm.weaponStack.append(wid)
	var label := get_node_or_null("Label3D") as Label3D
	if label:
		label.visible = false
	queue_free()
