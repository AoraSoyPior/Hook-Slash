extends Character
class_name Slime

## ─────────────────────────────────────────────────────────────────────────────
## Slime — Enemigo universal con comportamiento por tipo
##
## Estructura de escena esperada:
##
##   Slime  (CharacterBody2D + este script)
##   ├── Sprite        (SpriteCharacter)  ← igual que el resto de personajes
##   ├── Shadow        (Sprite2D)
##   ├── Hitbox        (Area2D + Hitbox)  ← recibe daño
##   ├── ContactDamage (Area2D + DamageArea) ← daña al tocar
##   ├── DetectionArea (Area2D)           ← detecta al jugador
##   └── CollisionShape2D
##
## Para el tipo SPLIT añade también:
##   └── SlimeSmall.tscn  (PackedScene en small_slime_scene)
## ─────────────────────────────────────────────────────────────────────────────


# ── Tipos de slime ────────────────────────────────────────────────────────────

enum SlimeType {
	NORMAL,    ## Salta hacia el jugador cada 2 segundos
	EXPLOSIVE, ## Persigue lentamente y explota al morir o estar muy cerca
	STICKY,    ## Deja charcos que ralentizan al pisar; golpea a rango corto
	SPLIT,     ## Al morir se divide en 2 slimes más pequeños
}


# ── Exportaciones ─────────────────────────────────────────────────────────────
@export var life: ResourceLife
@export_group("Tipo")
@export var slime_type: SlimeType = SlimeType.NORMAL

@export_group("Detección")
## Radio en el que detecta al jugador (DetectionArea debe tener el mismo)
@export var detection_radius := 96.0
## Radio mínimo para considerar que está "encima" del objetivo
@export var melee_radius := 16.0

@export_group("Salto (NORMAL / SPLIT)")
## Segundos entre saltos
@export var jump_interval := 2.0
## Píxeles que avanza en cada salto
@export var jump_distance := 64.0
## Duración del vuelo del salto en segundos
@export var jump_duration := 0.35
## Altura máxima del arco (en píxeles, eje Y)
@export var jump_arc_height := 18.0

@export_group("Explosivo (EXPLOSIVE)")
## Radio del área de explosión
@export var explosion_radius := 52.0
## Segundos de alerta antes de explotar por proximidad
@export var fuse_time := 0.9
## Daño de la explosión (usa el ResourceDamage del ContactDamage)
@export var explosion_damage_multiplier := 3

@export_group("Pegajoso (STICKY)")
## Factor de ralentización aplicado al jugador (0 = parado, 1 = normal)
@export var slow_factor := 0.38
## Duración del efecto lento en segundos
@export var slow_duration := 2.2
## Radio del charco que deja tras saltar
@export var puddle_radius := 24.0
## Distancia a la que golpea sin saltar (salpicadura)
@export var splash_range := 20.0

@export_group("División (SPLIT)")
## Escena del slime pequeño que genera al morir
@export var small_slime_scene: PackedScene
## Escena del slime pequeño que genera al morir
@export var split_count := 2
## Escala de los hijos (1 = igual, 0.55 = más pequeños)
@export var child_scale := 0.55


# ── Referencias a nodos hijos ─────────────────────────────────────────────────

@onready var contact_damage: DamageArea = $ContactDamage
@onready var detection_area: Area2D      = $DetectionArea
@onready var hitbox: Hitbox              = $Hitbox
@onready var audio: AudioStreamPlayer2D = $Audio


# ── Estado interno ────────────────────────────────────────────────────────────

var target: Node2D = null          # Jugador detectado
var _jump_timer := 0.0             # Cuenta regresiva hasta el próximo salto
var _is_jumping := false           # ¿Hay un salto activo?
var _jump_origin := Vector2.ZERO
var _jump_destination := Vector2.ZERO
var _jump_progress := 0.0          # 0..1 durante el arco del salto

var _fuse_active := false          # EXPLOSIVE: mecha encendida
var _fuse_timer := 0.0
var _is_dead := false              # Evita doble muerte
var _ready_done := false


# ─────────────────────────────────────────────────────────────────────────────
# Modificar _ready() para conectar la vida
func _ready() -> void:
	super()
	add_to_group("enemy")
	add_to_group("hookable")
	detection_area.body_entered.connect(_on_body_entered)
	detection_area.body_exited.connect(_on_body_exited)
	life.life = life.max_life        # resetear al instanciar
	life.killed.connect(on_killed)   # conectar muerte
	_jump_timer = randf_range(0.3, jump_interval)
	await get_tree().process_frame
	await get_tree().process_frame
	hitbox.damage_received.connect(_on_damage_received)
	_ready_done = true


func _physics_process(delta: float) -> void:
	# La clase base gestiona el movimiento si being_pulled o GRAPPLING
	if being_pulled or state == State.STUNNED:
		super(delta)
		return

	if _is_dead:
		return

	match slime_type:
		SlimeType.NORMAL:    _tick_normal(delta)
		SlimeType.EXPLOSIVE: _tick_explosive(delta)
		SlimeType.STICKY:    _tick_sticky(delta)
		SlimeType.SPLIT:     _tick_split(delta)

	super(delta)


# ─────────────────────────────────────────────────────────────────────────────
# COMPORTAMIENTOS POR TIPO

# ── NORMAL ────────────────────────────────────────────────────────────────────
func _tick_normal(delta: float) -> void:
	if _is_jumping:
		_advance_jump(delta)
		return

	if !target:
		move_vector = Vector2.ZERO
		return

	_jump_timer -= delta
	if _jump_timer <= 0.0:
		_jump_timer = jump_interval
		_start_jump(target.global_position)


# ── EXPLOSIVE ─────────────────────────────────────────────────────────────────
func _tick_explosive(delta: float) -> void:
	if _fuse_active:
		_fuse_timer -= delta
		# Parpadeo rápido para indicar que va a explotar
		modulate = Color.RED if fmod(_fuse_timer, 0.18) > 0.09 else Color.WHITE
		if _fuse_timer <= 0.0:
			_explode()
		return

	if !target:
		move_vector = Vector2.ZERO
		return

	# Persecución lenta continua (sin saltar, desliza)
	var dist := global_position.distance_to(target.global_position)
	if dist > melee_radius:
		move_vector = global_position.direction_to(target.global_position)
	else:
		move_vector = Vector2.ZERO
		# Está encima del jugador: encender la mecha
		if !_fuse_active:
			_light_fuse()


func _light_fuse() -> void:
	_fuse_active = true
	_fuse_timer = fuse_time


func _explode() -> void:
	if _is_dead:
		return
	_is_dead = true

	# Dañar todo lo que esté en el radio de explosión
	var bodies := detection_area.get_overlapping_bodies()
	for body in bodies:
		if body == self:
			continue
		# Buscar hitbox en el cuerpo colisionado
		for child in body.get_children():
			if child is Hitbox and contact_damage.damage:
				var boosted_damage := ResourceDamage.new()
				boosted_damage.amount = contact_damage.damage.amount * explosion_damage_multiplier
				boosted_damage.push_force = contact_damage.damage.push_force * 2
				child.take_damage(boosted_damage, global_position)
		# Knockback incluso si no hay hitbox (jugadores con push)
		if body is Character:
			body.push(global_position, 280.0)

	queue_free()


# ── STICKY ────────────────────────────────────────────────────────────────────
func _tick_sticky(delta: float) -> void:
	if _is_jumping:
		_advance_jump(delta)
		return

	if !target:
		move_vector = Vector2.ZERO
		return

	var dist := global_position.distance_to(target.global_position)

	if dist <= splash_range:
		# Golpe de salpicadura de corto rango: ralentizar sin necesidad de saltar
		_apply_slow_to_target()
		_jump_timer = jump_interval  # Reiniciar timer para no saltar también

	_jump_timer -= delta
	if _jump_timer <= 0.0:
		_jump_timer = jump_interval
		_start_jump(target.global_position)


func _apply_slow_to_target() -> void:
	if !target:
		return
	if target is Character:
		# Modifica la velocidad base temporalmente mediante un Tween
		var original_speed: float = target.speed
		target.speed *= slow_factor
		var tw := create_tween()
		tw.tween_interval(slow_duration)
		tw.tween_callback(func(): if is_instance_valid(target): target.speed = original_speed)


func _on_jump_landed_sticky() -> void:
	# Deja un charco en el punto de aterrizaje
	_apply_slow_to_target()

	# Efecto visual del charco (círculo semitransparente, desaparece solo)
	var puddle := ColorRect.new()
	puddle.color = Color(0.2, 0.7, 0.15, 0.45)
	puddle.size = Vector2(puddle_radius * 2.0, puddle_radius * 2.0)
	puddle.position = global_position - Vector2(puddle_radius, puddle_radius)
	get_parent().add_child(puddle)

	var tw := create_tween()
	tw.tween_property(puddle, "modulate:a", 0.0, slow_duration)
	tw.tween_callback(puddle.queue_free)


# ── SPLIT ─────────────────────────────────────────────────────────────────────
func _tick_split(delta: float) -> void:
	# Comportamiento idéntico al NORMAL (salta hacia el jugador)
	if _is_jumping:
		_advance_jump(delta)
		return

	if !target:
		move_vector = Vector2.ZERO
		return

	_jump_timer -= delta
	if _jump_timer <= 0.0:
		_jump_timer = jump_interval
		_start_jump(target.global_position)


func _spawn_children() -> void:
	if !small_slime_scene:
		return

	for i in split_count:
		var child: Slime = small_slime_scene.instantiate()
		get_parent().add_child(child)
		# Posición ligeramente desplazada
		var offset := Vector2(randf_range(-14.0, 14.0), randf_range(-14.0, 14.0))
		child.global_position = global_position + offset
		child.scale = Vector2.ONE * child_scale
		# El hijo hereda el tipo SPLIT pero sin volver a dividirse (para no ser infinito)
		child.slime_type = SlimeType.NORMAL
		# Pasar el target si existe
		if target and is_instance_valid(target):
			child.target = target


# ─────────────────────────────────────────────────────────────────────────────
# SISTEMA DE SALTO (compartido por NORMAL, STICKY y SPLIT)

func _start_jump(destination: Vector2) -> void:
	if _is_jumping:
		return

	_is_jumping = true
	_jump_origin = global_position
	# Limitar el salto a jump_distance para no atravesar paredes lejanas
	var dir := global_position.direction_to(destination)
	var dist := minf(global_position.distance_to(destination), jump_distance)
	_jump_destination = global_position + dir * dist
	_jump_progress = 0.0
	move_vector = Vector2.ZERO


func _advance_jump(delta: float) -> void:
	_jump_progress += delta / jump_duration
	_jump_progress = minf(_jump_progress, 1.0)

	var t := _jump_progress

	# Velocidad horizontal directa hacia el destino
	var horiz_dir := _jump_origin.direction_to(_jump_destination)
	var horiz_speed := _jump_origin.distance_to(_jump_destination) / jump_duration
	velocity = horiz_dir * horiz_speed

	# Arco visual en el sprite (no afecta al hitbox)
	sprite.position.y = -sin(t * PI) * jump_arc_height

	# Actualizar dirección del sprite
	move_vector = horiz_dir

	if _jump_progress >= 1.0:
		_end_jump()


func _end_jump() -> void:
	_is_jumping = false
	sprite.position.y = 0.0
	move_vector = Vector2.ZERO
	velocity = Vector2.ZERO

	if slime_type == SlimeType.STICKY:
		_on_jump_landed_sticky()

	# Aplicar daño al aterrizar si el jugador está cerca
	_try_deal_landing_damage()


func _try_deal_landing_damage() -> void:
	if !contact_damage.damage:
		return
	for body in detection_area.get_overlapping_bodies():
		if body == self:
			continue
		if body.is_in_group("enemy"):  # ← añadir esto
			continue
		var dist := global_position.distance_to(body.global_position)
		if dist > melee_radius * 2.0:
			continue
		for child in body.get_children():
			if child is Hitbox:
				if child.team and contact_damage.team:
					if child.team == contact_damage.team or child.team.is_ally(contact_damage.team):
						continue
				child.take_damage(contact_damage.damage, global_position)
				if body is Character:
					body.push(global_position, 120.0)


# ─────────────────────────────────────────────────────────────────────────────
# SEÑALES

func _on_body_entered(body: Node2D) -> void:
	if body == self:
		return
	if body.is_in_group("enemy"):  # ← ignorar otros slimes
		return
	if body is CharacterBody2D and !target:
		target = body


func _on_body_exited(body: Node2D) -> void:
	if body == target:
		target = null
		move_vector = Vector2.ZERO


func _on_damage_received(damage: ResourceDamage, at_pos: Vector2) -> void:
	if _is_dead or !_ready_done:
		return
	life.damage(damage.amount)
	push(at_pos, 90.0)
	audio.play()
	if slime_type == SlimeType.EXPLOSIVE and !_fuse_active:
		_light_fuse()
	_flash_hit()


func _flash_hit() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color.WHITE * 3.0, 0.0)
	tween.tween_property(self, "modulate", Color.WHITE, 0.12)



## Llamar este método desde la señal `killed` del ResourceLife
## (conéctala en el Inspector o desde el nodo padre).
func on_killed() -> void:
	if _is_dead:
		return
	_is_dead = true
	ScoreManager.add_kill(1000)

	match slime_type:
		SlimeType.EXPLOSIVE:
			_explode()
			return           # _explode() llama a queue_free
		SlimeType.SPLIT:
			_spawn_children()

	queue_free()
