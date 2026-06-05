extends Area2D

@export var heal_amount: int = 1
@onready var audio : AudioStreamPlayer2D = $AudioStreamPlayer2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_bob()


func _on_body_entered(body: Node2D) -> void:
	if !body.is_in_group("player"):
		return

	# Curar antes de desaparecer
	var life_node := body.get_node_or_null("Life")
	if life_node and life_node.life:
		life_node.life.heal(heal_amount)

	# Ocultar el sprite mientras suena el audio
	$Sprite2D.visible = false
	set_deferred("monitoring", false)

	audio.play()
	await audio.finished
	queue_free()


func _bob() -> void:
	var tween := create_tween().set_loops()
	tween.tween_property($Sprite2D, "position:y", -3.0, 0.6).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property($Sprite2D, "position:y", 3.0, 0.6).set_ease(Tween.EASE_IN_OUT)
