extends RigidBody3D

@export var item_id: String = ""
@export var display_name: String = ""
@export var price: int = 0
@export var ammo_type: String = ""
@export var ammo_amount: int = 0

func _ready():
	CarriablePickup.register(self)
	if not is_in_group("ShopItem"):
		add_to_group("ShopItem")
	if item_id == "icecream" and not is_in_group("IceCream"):
		add_to_group("IceCream")

func get_price() -> int:
	return price

func on_picked_up():
	for section in get_tree().get_nodes_in_group("ShopShelfSection"):
		if section.has_method("on_item_removed"):
			section.on_item_removed(self)
