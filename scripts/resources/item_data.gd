class_name ItemData
extends Resource

enum Category {
	CONSUMABLE,
	AMMO,
	QUEST_ITEM
}

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var category: Category = Category.CONSUMABLE
@export var icon: Texture2D
@export var stackable: bool = true
@export var max_stack: int = 99
