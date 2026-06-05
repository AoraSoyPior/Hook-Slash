extends Node2D
class_name PuzzleDoor

@export var switches: Array[NodePath] = []
@export var open_color := Color(0.3, 0.3, 1.0)
@export var closed_color := Color(0.6, 0.2, 0.2)

var _switch_nodes: Array[PressureSwitch] = []

@onready var visual: Sprite2D = $Visual
@onready var blocker: CollisionShape2D = $Blocker/CollisionShape2D 
@onready var audio: AudioStreamPlayer2D = $AudioStreamPlayer2D


func _ready() -> void:
	for path in switches:
		var sw = get_node_or_null(path)
		if sw == null:
			print("PuzzleDoor: no se encontró el switch en la ruta ", path)
			continue
		_switch_nodes.append(sw)
		sw.activated.connect(_check_state)
		sw.deactivated.connect(_check_state)
	print("PuzzleDoor: ", _switch_nodes.size(), " switches conectados")
	_check_state()

func open() -> void:
	blocker.set_deferred("disabled", true)
	visual.modulate = open_color
	audio.play()


func _check_state() -> void:
	var all_pressed := _switch_nodes.all(func(sw): return sw.is_pressed)
	blocker.set_deferred("disabled", all_pressed)  # ← set_deferred para evitar errores de física
	visual.modulate = open_color if all_pressed else closed_color
	if all_pressed: audio.play()
