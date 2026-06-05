extends Control

var paused: bool

func resume():
	self.hide()
	Engine.time_scale = 1

func pause_menu():
	if Input.is_action_just_pressed("esc"):
		if paused:
			resume()
		else:
			self.show()
			Engine.time_scale = 0
		paused = !paused

func _on_reanudar_pressed() -> void:
	resume()


func _on_reiniciar_pressed() -> void:
	get_tree().reload_current_scene()
	resume()


func _on_salir_pressed() -> void:
	get_tree().quit()
