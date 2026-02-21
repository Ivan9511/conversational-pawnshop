extends Node2D
class_name CashboxNPC

@export var data: NPCData : set = set_data

@onready var sprite: Sprite2D = $Sprite


func _ready() -> void:
	if not data:
		push_error("NPC data is missing")
		return
		
	_apply_data()


func set_data(value: NPCData) -> void:
	data = value
	if not is_node_ready():
		return
	_apply_data()


func _apply_data() -> void:
	if sprite and data.sprite:
		sprite.texture = data.sprite
