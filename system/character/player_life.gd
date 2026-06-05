extends Node

@export var life: ResourceLife
@export var invincibility_time: float = 1.5
@export var blink_speed: float = 0.08

var _invincible := false

@onready var hitbox: Hitbox = $"../Hitbox"
@onready var sprite: Node2D = $"../Sprite"
@onready var audio: AudioStreamPlayer2D = $AudioLife


func _ready() -> void:
	life.life = life.max_life
	await get_tree().process_frame
	await get_tree().process_frame
	hitbox.damage_received.connect(_on_damage_received)
	get_tree().call_group("player_ui", "set_life", life)


func _on_damage_received(damage: ResourceDamage, _at_pos: Vector2) -> void:
	if _invincible:
		return
	life.damage(damage.amount)
	audio.play()
	if ScoreManager.score >= 0:
		ScoreManager.remove_points(250)
		if ScoreManager.score < 0: ScoreManager.score = 0
	if !life.is_alive():
		var game_over = load("res://content/ui/main_menu/victory_screen.tscn").instantiate()
		get_tree().current_scene.add_child(game_over)
		return
	_start_invincibility()


func _start_invincibility() -> void:
	_invincible = true

	# Parpadeo con Tween — no puede quedarse colgado
	var tween := create_tween().set_loops()
	tween.tween_property(sprite, "modulate:a", 0.0, blink_speed)
	tween.tween_property(sprite, "modulate:a", 1.0, blink_speed)

	await get_tree().create_timer(invincibility_time).timeout

	tween.kill()
	sprite.modulate.a = 1.0
	_invincible = false
