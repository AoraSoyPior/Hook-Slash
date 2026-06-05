extends Character
class_name GiantSlime

# ── Exportaciones ─────────────────────────────────────────────────────────────

@export_group("Vida")
@export var life: ResourceLife

@export_group("Salto")
@export var jump_interval := 3.0
@export var jump_distance := 120.0
@export var jump_duration := 1.1
@export var jump_arc_height := 48.0

@export_group("Aterrizaje")
@export var slam_radius := 52.0
@export var slam_push_force := 320.0
@export var slam_damage: ResourceDamage

@export_group("Referencias")
@export var entrance_door: NodePath
@export var exit_door: NodePath

# ── Nodos ─────────────────────────────────────────────────────────────────────

@onready var hitbox: Hitbox                   = $Hitbox
@onready var detection_area: Area2D           = $DetectionArea
@onready var body_collision: CollisionShape2D = $CollisionShape2D
@onready var anim: AnimatedSprite2D           = $AnimatedSprite2D
@onready var audio: AudioStreamPlayer2D       = $Audio

# ── Estado ────────────────────────────────────────────────────────────────────

var target: Node2D = null
var _active := false
var _is_dead := false
var _is_jumping := false
var _jump_timer := 0.0
var _jump_origin := Vector2.ZERO
var _jump_destination := Vector2.ZERO
var _jump_progress := 0.0

var _entrance_door_node: Node = null
var _exit_door_node: Node = null
var _ready_done := false

# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	super()
	add_to_group("enemy")
	add_to_group("hookable")

	life.life = life.max_life
	life.killed.connect(_on_killed)
	detection_area.body_entered.connect(_on_body_entered_detection)
	await get_tree().process_frame
	await get_tree().process_frame
	hitbox.damage_received.connect(_on_damage_received)
	_ready_done = true

	anim.play("idle")

	if entrance_door:
		_entrance_door_node = get_node_or_null(entrance_door)
	if exit_door:
		_exit_door_node = get_node_or_null(exit_door)


func _physics_process(delta: float) -> void:
	if !_active or _is_dead:
		return

	if being_pulled or state == State.STUNNED:
		super(delta)
		return

	if _is_jumping:
		_advance_jump(delta)
	else:
		_jump_timer -= delta
		if _jump_timer <= 0.0 and target:
			_jump_timer = jump_interval
			_start_jump(target.global_position)

	super(delta)


# ── Activación ────────────────────────────────────────────────────────────────

func _on_body_entered_detection(body: Node2D) -> void:
	if _active or body.is_in_group("enemy"):
		return
	if not body is CharacterBody2D:
		return
	target = body
	_activate()


func _activate() -> void:
	_active = true
	_jump_timer = 1.2

	if _entrance_door_node:
		_entrance_door_node.get_node_or_null("Blocker/CollisionShape2D")\
			.call_deferred("set", "disabled", false)
		if _entrance_door_node.has_node("Visual"):
			_entrance_door_node.get_node("Visual").modulate = Color(0.6, 0.2, 0.2)

	anim.play("idle")


# ── Sistema de salto ──────────────────────────────────────────────────────────

func _start_jump(destination: Vector2) -> void:
	if _is_jumping:
		return

	_is_jumping = true
	_jump_origin = global_position
	var dir := global_position.direction_to(destination)
	var dist := minf(global_position.distance_to(destination), jump_distance)
	_jump_destination = global_position + dir * dist
	_jump_progress = 0.0

	# Sin colisión mientras está en el aire
	body_collision.set_deferred("disabled", true)

	anim.play("jump")


func _advance_jump(delta: float) -> void:
	_jump_progress += delta / jump_duration
	_jump_progress = minf(_jump_progress, 1.0)

	var t := _jump_progress
	var horiz_dir := _jump_origin.direction_to(_jump_destination)
	var horiz_speed := _jump_origin.distance_to(_jump_destination) / jump_duration
	velocity = horiz_dir * horiz_speed
	anim.position.y = -sin(t * PI) * jump_arc_height
	move_vector = horiz_dir

	if _jump_progress >= 1.0:
		_land()


func _land() -> void:
	_is_jumping = false
	anim.position.y = 0.0
	move_vector = Vector2.ZERO
	velocity = Vector2.ZERO

	# Restaurar colisión
	body_collision.set_deferred("disabled", false)

	# Esperar a que termine la animación de salto antes de hacer daño
	await anim.animation_finished

	# Daño al aterrizar
	_do_slam()

	anim.play("idle")


func _do_slam() -> void:
	if !slam_damage:
		return

	for body in get_tree().get_nodes_in_group("player"):
		var dist := global_position.distance_to(body.global_position)
		if dist > slam_radius:
			continue
		for child in body.get_children():
			if child is Hitbox:
				child.take_damage(slam_damage, global_position)
		body.push(global_position, slam_push_force)

	for camera in get_tree().get_nodes_in_group("camera"):
		if camera.has_method("shake"):
			camera.shake(0.3, 6.0)


# ── Daño y muerte ─────────────────────────────────────────────────────────────

func _on_damage_received(damage: ResourceDamage, at_pos: Vector2) -> void:
	if _is_dead:
		return
	audio.play()
	life.damage(damage.amount)
	anim.play("hit")
	push(at_pos, 60.0)
	_flash_hit()


func _flash_hit() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color.WHITE * 3.0, 0.0)
	tween.tween_property(self, "modulate", Color.WHITE, 0.15)


func _on_killed() -> void:
	if _is_dead:
		return
	_is_dead = true
	ScoreManager.add_kill(10000)
	_active = false
	body_collision.set_deferred("disabled", true)

	anim.play("hit")
	await anim.animation_finished

	# Abrir la puerta de salida
	if _exit_door_node and _exit_door_node.has_method("open"):
		_exit_door_node.open()

	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.4, 1.4), 0.2)
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func():
		queue_free()
		# Mostrar pantalla de victoria
		var victory = load("res://content/ui/main_menu/victory_screen.tscn").instantiate()
		get_tree().current_scene.add_child(victory)
	)
