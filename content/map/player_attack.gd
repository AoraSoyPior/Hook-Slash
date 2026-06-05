extends Area2D

@export var damage: ResourceDamage
@export var team: ResourceDamageTeam
@export var attack_duration: float = 0.15
@export var attack_cooldown: float = 0.4
@export var sword_offset: float = 14.0

var _cooling := false

@onready var shape: CollisionShape2D = $CollisionShape2D
@onready var character: Character = get_parent()
@onready var slash_visual: Polygon2D = $SlashVisual
@onready var audio_slash: AudioStreamPlayer2D = $AudioSlash


func _ready() -> void:
	monitoring = false
	shape.disabled = true
	collision_layer = 0
	collision_mask = 0
	set_collision_mask_value(3, true)
	area_entered.connect(_on_area_entered)
	slash_visual.visible = false
	slash_visual.color = Color(1.0, 1.0, 0.8, 0.7)
	# Arco en forma de sector
	slash_visual.polygon = _build_arc_polygon(12.0, 24.0, -50.0, 50.0, 8)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("attack") and !_cooling:
		_do_attack()

func _process(_delta: float) -> void:
	position = character.sprite.direction * sword_offset


func _build_arc_polygon(inner: float, outer: float, angle_from: float, angle_to: float, steps: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in steps + 1:
		var a := deg_to_rad(lerp(angle_from, angle_to, float(i) / steps))
		points.append(Vector2(cos(a), sin(a)) * outer)
	for i in steps + 1:
		var a := deg_to_rad(lerp(angle_to, angle_from, float(i) / steps))
		points.append(Vector2(cos(a), sin(a)) * inner)
	return points


func _do_attack() -> void:
	_cooling = true
	shape.disabled = false
	await get_tree().process_frame
	monitoring = true
	_show_slash()

	await get_tree().create_timer(attack_duration).timeout
	monitoring = false
	shape.disabled = true

	await get_tree().create_timer(attack_cooldown - attack_duration).timeout
	_cooling = false

func _show_slash() -> void:
	slash_visual.visible = true
	slash_visual.rotation = character.sprite.direction.angle()
	slash_visual.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_property(slash_visual, "modulate:a", 0.0, 0.12)
	tween.tween_callback(func(): slash_visual.visible = false)
	audio_slash.play()


func _on_area_entered(area: Area2D) -> void:
	if not area is Hitbox:
		return
	# Ignorar el hitbox del propio jugador
	if area.get_parent() == character:
		return
	# Comprobar equipos
	if area.team and team:
		if area.team == team or area.team.is_ally(team):
			return
	area.take_damage(damage, global_position)
	# Push solo al enemigo, nunca al jugador
	var target := area.get_parent()
	if target is Character and target != character:
		target.push(global_position, damage.push_force)
