extends RigidBody3D

var in_range: bool = false

@onready var pickup_area: Area3D = $PickupArea
@onready var label_3d: Label3D = $Label3D

func _ready() -> void:
	if is_in_group("Carriable"):
		remove_from_group("Carriable")
	if pickup_area:
		pickup_area.body_entered.connect(_on_body_entered)
		pickup_area.body_exited.connect(_on_body_exited)
	label_3d.visible = false


func _input(_event: InputEvent) -> void:
	if not in_range:
		return
	if Input.is_action_just_pressed("interaction") or Input.is_action_just_pressed("carry_object"):
		GameManager.add_item("peak_performance_lua", 1)
		var quest_system: Node = get_node_or_null("/root/QuestSystem")
		if quest_system and quest_system.has_method("on_item_collected"):
			quest_system.call("on_item_collected", "peak_performance_lua")
		queue_free()


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("PlayerCharacter"):
		in_range = true
		label_3d.visible = true


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("PlayerCharacter"):
		in_range = false
		label_3d.visible = false
