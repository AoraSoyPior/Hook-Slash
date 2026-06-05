extends Node

@export var life: ResourceLife
@onready var hitbox: Hitbox = $"../Hitbox"

func _ready() -> void:
	hitbox.damage_received.connect(_on_damage_received)
	life.killed.connect(_on_death)

func _on_damage_received(damage: ResourceDamage, _at_pos: Vector2) -> void:
	life.damage(damage.amount)

func _on_death() -> void:
	get_tree().reload_current_scene()
