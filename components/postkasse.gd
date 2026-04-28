extends Node3D

func _ready() -> void:
	$Label3D.text = str(GameManager.player_name)
