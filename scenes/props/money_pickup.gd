extends Area3D

var amount: int = 50


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	$Label3D.text = str(amount) + " NOK"


func set_amount(value: int) -> void:
	amount = value
	if $Label3D:
		$Label3D.text = str(amount) + " NOK"


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("PlayerCharacter"):
		GameManager.add_flat_money_reward(amount)
		queue_free()
