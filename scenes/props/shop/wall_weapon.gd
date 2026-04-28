extends RigidBody3D
# tag: wall_weapon — ShopItem; Carriable only when affordable; checkout gives weapon via cashier.

@export var weapon_name: String = ""
@export var weapon_price: int = 0
@export var weapon_int_id: int = 0
@export var weapon_color: Color = Color.DARK_GRAY

@onready var price_label: Label3D = $PriceLabel
@onready var weapon_mesh: MeshInstance3D = $WeaponMesh
@onready var interaction_area: Area3D = $InteractionArea

var in_range: bool = false
var is_sold: bool = false

var home_position: Vector3
var home_rotation: Vector3

var _away_timer: float = 0.0
const RETURN_TIMEOUT: float = 30.0


func _ready() -> void:
	freeze = true
	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	gravity_scale = 1.0
	add_to_group("WallWeapon")
	add_to_group("ShopItem")
	set_collision_mask_value(2, true)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = weapon_color
	weapon_mesh.material_override = mat

	interaction_area.body_entered.connect(_on_body_entered)
	interaction_area.body_exited.connect(_on_body_exited)
	if GameManager:
		GameManager.money_changed.connect(_on_money_changed)

	await get_tree().process_frame
	home_position = global_position
	home_rotation = global_rotation

	_update_label()


func get_price() -> int:
	return weapon_price


func _update_label() -> void:
	if is_sold:
		price_label.text = weapon_name + "\nSOLGT"
		price_label.modulate = Color.WHITE
		remove_from_group("Carriable")
		return

	var can_afford := GameManager.player_money >= weapon_price

	if in_range and can_afford:
		price_label.text = weapon_name + "\n" + str(weapon_price) + " kr"
		price_label.modulate = Color.YELLOW
		if not is_sold:
			add_to_group("Carriable")
	elif in_range and not can_afford:
		var diff: int = weapon_price - GameManager.player_money
		price_label.text = weapon_name + "\n" + str(weapon_price) + " kr\nMangler " + str(diff) + " NOK"
		price_label.modulate = Color.RED
		remove_from_group("Carriable")
	else:
		price_label.text = weapon_name + "\n" + str(weapon_price) + " kr"
		price_label.modulate = Color.WHITE
		if can_afford:
			add_to_group("Carriable")
		else:
			remove_from_group("Carriable")


func on_picked_up() -> void:
	_away_timer = 0.0


func _on_money_changed(_new_amount: int) -> void:
	_update_label()


func _process(delta: float) -> void:
	if is_sold:
		return
	if freeze:
		return
	_away_timer += delta
	if _away_timer >= RETURN_TIMEOUT:
		_return_to_wall()


func _return_to_wall() -> void:
	_away_timer = 0.0
	freeze = true
	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	global_position = home_position
	global_rotation = home_rotation
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	_update_label()


func mark_as_sold() -> void:
	is_sold = true
	remove_from_group("Carriable")
	remove_from_group("ShopItem")
	freeze = true
	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.3, 0.3)
	weapon_mesh.material_override = mat
	for zn in get_tree().get_nodes_in_group("CheckoutZone"):
		if zn.has_method("remove_item_if_present"):
			zn.remove_item_if_present(self)
	if interaction_area:
		interaction_area.monitoring = false
	_update_label()


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("PlayerCharacter"):
		in_range = true
		_update_label()


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("PlayerCharacter"):
		in_range = false
		_update_label()
