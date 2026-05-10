extends StaticBody3D

@onready var poster_sprite: Node3D = $Poster
@onready var interaction_area: Area3D = $PosterInteraction
@onready var interaction_label: Label3D = $PosterInteraction/Label3D

var poster_taken: bool = false
var player_nearby: Node = null

func _ready() -> void:
	set_process_input(true)
	interaction_area.body_entered.connect(_on_body_entered)
	interaction_area.body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("PlayerCharacter") and not poster_taken:
		player_nearby = body
		interaction_label.visible = true

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("PlayerCharacter"):
		player_nearby = null
		interaction_label.visible = false

func _input(_event: InputEvent) -> void:
	if poster_taken:
		return
	if player_nearby == null:
		return
	if Input.is_action_just_pressed("interaction"):
		_take_poster()

func _take_poster() -> void:
	poster_taken = true
	interaction_label.visible = false
	interaction_area.monitoring = false
	if poster_sprite:
		poster_sprite.visible = false
	GameManager.add_item("gard_plakat", 1)
	print("📋 Gard-plakat picked up")
