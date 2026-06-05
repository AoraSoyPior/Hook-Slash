extends CanvasLayer

@onready var nick_label:    Label  = $Panel/NickLabel
@onready var score_label:   Label  = $Panel/ScoreLabel
@onready var kills_label:   Label  = $Panel/KillsLabel
@onready var best_label:    Label  = $Panel/BestLabel
@onready var menu_btn:      Button = $Panel/MenuButton
@onready var restart_btn:   Button = $Panel/RestartButton
@onready var audio: AudioStreamPlayer2D = $AudioStreamPlayer2D


func _ready() -> void:
	# Guardar puntuación al aparecer la pantalla
	get_tree().paused = true
	audio.play()
	ScoreManager.finish_run()

	# Mostrar datos
	nick_label.text   = "JUGADOR:   %s"    % ScoreManager.current_nick
	score_label.text  = "PUNTUACIÓN:   %d" % ScoreManager.score
	kills_label.text  = "ENEMIGOS   ELIMINADOS:   %d" % ScoreManager.enemies_killed

	var best := ScoreDatabase.get_player_best(ScoreManager.current_player_id)
	best_label.text = "TU   MEJOR   PUNTUACIÓN:   %d" % best

	menu_btn.pressed.connect(func():
		get_tree().paused = false
		get_tree().change_scene_to_file("res://content/ui/main_menu/main_menu.tscn")
	)
	restart_btn.pressed.connect(func():
		get_tree().paused = false
		get_tree().change_scene_to_file("res://main.tscn")
	)
