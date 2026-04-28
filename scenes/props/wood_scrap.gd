extends RigidBody3D

@onready var pickup_label: Label3D = $Label3D

var _player_in_range: bool = false

func _ready() -> void:
	if not is_in_group("Carriable"):
		add_to_group("Carriable")
	if not is_in_group("WoodScrap"):
		add_to_group("WoodScrap")
	CarriablePickup.register(self)
	pickup_label.hide()

func on_picked_up() -> void:
	var tree := get_tree()
	if tree == null:
		return
	for zone in tree.get_nodes_in_group("LemonadeBuildZone"):
		if zone and zone.has_method("activate_from_scrap_pickup"):
			zone.call("activate_from_scrap_pickup")

#func _physics_process(_delta: float) -> void:
	#var player := get_tree().get_first_node_in_group("PlayerCharacter") as Node3D
	#if player == null:
		#pickup_label.hide()
		#return
	#_player_in_range = global_position.distance_to(player.global_position) <= 2.6
	#pickup_label.visible = _player_in_range
