extends CharacterBody2D
class_name PushableBox

@export var tile_size: float = 16.0
@export var move_duration: float = 0.18

var _moving := false

@onready var hitbox: Hitbox = $Hitbox
@onready var shape_cast: ShapeCast2D = $ShapeCast


func _ready() -> void:
	hitbox.damage_received.connect(_on_damage_received)
	# Snappear al grid al colocar en el editor
	global_position = global_position.snapped(Vector2.ONE * tile_size)


func _on_damage_received(_damage: ResourceDamage, at_pos: Vector2) -> void:
	if _moving:
		return
	var dir := _snap_to_4dir(global_position.direction_to(at_pos) * -1)
	_push(dir)


func _push(dir: Vector2) -> void:
	if _moving:
		return

	shape_cast.target_position = dir * tile_size
	shape_cast.collision_mask = 1 | 8  # capa 1 (paredes) + capa 4 (cajas), valores correctos
	shape_cast.exclude_parent = true
	
	# Excluir al jugador y otros no-obstáculos
	shape_cast.clear_exceptions()
	shape_cast.add_exception(self)
	for body in get_tree().get_nodes_in_group("player"):
		shape_cast.add_exception(body)
	for body in get_tree().get_nodes_in_group("enemy"):
		shape_cast.add_exception(body)

	shape_cast.force_shapecast_update()

	if shape_cast.is_colliding():
		return

	_moving = true
	var destination := global_position + dir * tile_size
	var tween := create_tween()
	tween.tween_property(self, "global_position", destination, move_duration)\
		.set_ease(Tween.EASE_OUT)
	tween.tween_callback(func():
		global_position = global_position.snapped(Vector2.ONE * tile_size)
		_moving = false
	)
func _snap_to_4dir(dir: Vector2) -> Vector2:
	if abs(dir.x) >= abs(dir.y):
		return Vector2(sign(dir.x), 0)
	else:
		return Vector2(0, sign(dir.y))
