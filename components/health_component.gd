extends Node
# tag: HealthComponent — take_damage(), heal(), death signals (shop turret / combat).

class_name HealthComponent

signal on_death()
signal on_damage_taken(current_health: float, damage_taken: float)

@export var max_health : float = 100.0
var current_health : float
var is_dead : bool = false

func _ready():
	current_health = max_health

func take_damage(amount: float):
	if is_dead:
		return

	print("DAMAGE TAKEN: ", amount)
	var hp_before := current_health
	var hp_after := current_health - amount
	print("HP before: ", hp_before, " damage: ", amount, " HP after: ", hp_after)

	current_health -= amount
	on_damage_taken.emit(current_health, amount)
	
	print(get_parent().name, " took ", amount, " damage. Health: ", current_health)
	
	if current_health <= 0:
		is_dead = true
		on_death.emit()

func heal(amount: float):
	if is_dead:
		return
	current_health = min(current_health + amount, max_health)
