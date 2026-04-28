extends Area3D

@onready var price_label: Label3D = $PriceLabel3D

var items_on_counter: Array[RigidBody3D] = []

func _ready():
	add_to_group("CheckoutZone")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_update_price_label()


func remove_item_if_present(body: RigidBody3D) -> void:
	if items_on_counter.has(body):
		items_on_counter.erase(body)
		_update_price_label()

func _on_body_entered(body: Node3D):
	if not (body is RigidBody3D):
		return
	if not body.is_in_group("ShopItem"):
		return
	var item: RigidBody3D = body as RigidBody3D
	if items_on_counter.has(item):
		return
	items_on_counter.append(item)
	_update_price_label()

func _on_body_exited(body: Node3D):
	if not (body is RigidBody3D):
		return
	if not body.is_in_group("ShopItem"):
		return
	items_on_counter.erase(body)
	_update_price_label()

func _update_price_label():
	items_on_counter = items_on_counter.filter(func(item): return is_instance_valid(item))
	var total: int = _calculate_total()
	if price_label == null:
		return
	if total <= 0:
		price_label.visible = false
		return
	price_label.visible = true
	price_label.text = "%d kr" % total

func _calculate_total() -> int:
	var total: int = 0
	for item in items_on_counter:
		if not is_instance_valid(item):
			continue
		if "item_id" in item and str(item.item_id) == "icecream" and GameManager and GameManager.has_method("get_icecream_price"):
			total += int(GameManager.get_icecream_price())
			continue
		if item.has_method("get_price"):
			total += int(item.get_price())
		elif "price" in item:
			total += int(item.price)
	return total

func get_items() -> Array[RigidBody3D]:
	items_on_counter = items_on_counter.filter(func(item): return is_instance_valid(item))
	return items_on_counter
