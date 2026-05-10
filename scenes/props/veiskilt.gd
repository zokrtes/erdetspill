extends Node3D

@export var gate_navn = "gateutennavn"

func _ready() -> void:
	$Label3D.text = gate_navn
	$Label3D2.text = gate_navn
