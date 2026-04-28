extends Area3D

## Shop anti-theft: if unpaid ShopItem leaves bounds or player exits carrying one, notify turret (signals only).

signal alarm_triggered
signal alarm_cancelled

var alarm_active: bool = false


func _ready() -> void:
	monitoring = true
	body_exited.connect(_on_body_exited)
	body_entered.connect(_on_body_entered)


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("ShopItem"):
		if _should_ignore_shop_item_exit(body):
			return
		_trigger_alarm()
	if body.is_in_group("PlayerCharacter"):
		var player := body
		if player.has_method("has_carried_object") and player.has_carried_object():
			var obj = player.get_carried_object() if player.has_method("get_carried_object") else null
			if obj and obj.is_in_group("ShopItem"):
				_trigger_alarm()


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("ShopItem") and alarm_active:
		if _all_items_inside():
			_cancel_alarm()


func _should_ignore_shop_item_exit(body: Node3D) -> bool:
	if not is_instance_valid(body):
		return true
	if body.is_queued_for_deletion():
		return true
	if body is RigidBody3D:
		var rb := body as RigidBody3D
		if rb.collision_layer == 0:
			return true
	return false


func _trigger_alarm() -> void:
	if alarm_active:
		return
	alarm_active = true
	alarm_triggered.emit()


func _cancel_alarm() -> void:
	alarm_active = false
	alarm_cancelled.emit()


func _all_items_inside() -> bool:
	for item in get_tree().get_nodes_in_group("ShopItem"):
		if not item is Node3D:
			continue
		if not is_instance_valid(item):
			continue
		if not overlaps_body(item as Node3D):
			return false
	return true
