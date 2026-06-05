@icon("../character/icon_character.png")
extends CharacterBody2D
class_name Character


## ─────────────────────────────────────────────────────────────────────────────
## Character — Base de todos los personajes (jugador y enemigos)
##
## Modificado para soportar:
##   • Estado GRAPPLING  → el GrappleHook controla la velocidad
##   • being_pulled      → enemigos arrastrados por el gancho
##   • push()            → golpes con físicas / knockback
##   • apply_stun()      → aturdimiento temporal
## ─────────────────────────────────────────────────────────────────────────────

enum State { IDLE, GRAPPLING, STUNNED }

signal teleported

@export_category("physics")
@export var speed: float = 100.0
@export var acceleration: float = 1000.0
@export var deceleration: float = 800.0


@export var team: ResourceDamageTeam:
	set(v):
		team = v

# ── Variables de estado ───────────────────────────────────────────────────────

var move_vector := Vector2.ZERO:
	set(v):
		move_vector = v
		if sprite and move_vector.length():
			sprite.direction = move_vector.normalized()

var state: State
var just_teleport := false

## Indica que otro nodo (GrappleHook) controla la velocidad del personaje.
## Mientras sea true, la IA / input no sobreescribe velocity.
var being_pulled := false

# Timer de aturdimiento
var _stun_timer := 0.0

@onready var sprite: Node2D = get_node_or_null("Sprite")


# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	pass

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	if _stun_timer > 0.0:
		_stun_timer -= delta
		if _stun_timer <= 0.0 and state == State.STUNNED:
			state = State.IDLE

	if being_pulled:
		if sprite: sprite.anim = SpriteCharacter.Anim.ABILITY
		move_and_slide()
		return

	match state:
		State.IDLE:
			if move_vector.length():
				if sprite: sprite.anim = SpriteCharacter.Anim.MOVING
				velocity = velocity.move_toward(move_vector * speed, acceleration * delta)
			else:
				if sprite: sprite.anim = SpriteCharacter.Anim.IDLE
				velocity = velocity.move_toward(Vector2.ZERO, deceleration * delta)
		State.GRAPPLING:
			if move_vector.length() > 0.1:
				var steering := move_vector * (speed * 0.28)
				velocity += steering * delta * acceleration * 0.4
				if sprite: sprite.anim = SpriteCharacter.Anim.MOVING
			else:
				if sprite: sprite.anim = SpriteCharacter.Anim.ABILITY
		State.STUNNED:
			velocity = velocity.move_toward(Vector2.ZERO, deceleration * 1.5 * delta)
			if sprite: sprite.anim = SpriteCharacter.Anim.ABILITY_2

	move_and_slide()


# ─────────────────────────────────────────────────────────────────────────────
# API publica para el GrappleHook y el sistema de dano

## Inicia el estado de grappling (llamado por GrappleHook cuando se engancha)
func start_grapple() -> void:
	state = State.GRAPPLING


## Termina el estado de grappling (llamado por GrappleHook al soltar)
func end_grapple() -> void:
	if state == State.GRAPPLING:
		state = State.IDLE


## Aplica un impulso desde una posicion externa (knockback de armas, explosiones...)
func push(from: Vector2, force: float) -> void:
	var dir := from.direction_to(global_position)
	velocity += dir * force


## Aturde al personaje durante 'duration' segundos
func apply_stun(duration: float) -> void:
	if duration <= 0.0:
		return
	_stun_timer = max(_stun_timer, duration)
	state = State.STUNNED


## El personaje puede moverse ahora mismo?
func can_move() -> bool:
	return state == State.IDLE and !being_pulled


# ─────────────────────────────────────────────────────────────────────────────
func teleport(target_teleporter: Teleporter, offset_position: Vector2):
	if just_teleport:
		return
	global_position = target_teleporter.global_position + offset_position + (target_teleporter.direction * Vector2(25, 25))
	just_teleport = true
	for camera in get_tree().get_nodes_in_group("camera"):
		camera.teleport_to(global_position)
	await get_tree().create_timer(0.1, false).timeout
	just_teleport = false
	teleported.emit()
