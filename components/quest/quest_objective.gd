# quest_objective.gd
extends Resource
class_name QuestObjective

enum ObjectiveType { 
	GATHER_ITEM, TALK_TO_NPC, VISIT_LOCATION, SPEND_MONEY, 
	EARN_XP, CUSTOM_ACTION, FILL_FORM, PURCHASE_ITEM, DELIVER, MINIGAME
}

@export var objective_id: String = ""
@export var description: String = ""
@export var type: ObjectiveType = ObjectiveType.GATHER_ITEM
@export var target_id: String = ""
@export var target_amount: int = 1
@export var progress_flavor: String = ""
