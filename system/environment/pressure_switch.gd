extends Node2D
class_name PressureSwitch

signal activated
signal deactivated

@export var pressed_color := Color(0.3, 1.0, 0.3)
@export var unpressed_color := Color(0.8, 0.8, 0.8)

var is_pressed := false

@onready var detector: Area2D = $Detector
@onready var visual: Sprite2D = $Visual


func _ready() -> void:
	detector.body_entered.connect(_on_body_entered)
	detector.body_exited.connect(_on_body_exited)
	visual.modulate = unpressed_color


func _on_body_entered(body: Node2D) -> void:
	if body is PushableBox and !is_pressed:
		is_pressed = true
		visual.modulate = pressed_color
		activated.emit()


func _on_body_exited(body: Node2D) -> void:
	if body is PushableBox and is_pressed:
		is_pressed = false
		visual.modulate = unpressed_color
		deactivated.emit()
