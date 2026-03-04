extends EntityData
class_name ActorData

@export var display_name: String = "Actor"
@export var timeline_name: String = "guard_encounter"  # первый диалог
@export var repeat_timeline_name: String = ""          # диалог при повторе (если пусто - использовать первый)
@export var physical_defense: int = 5
@export var magical_defense: int = 5
