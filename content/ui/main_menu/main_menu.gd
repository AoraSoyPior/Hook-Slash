extends Control

@onready var nick_input:    LineEdit = $Panel/NickInput
@onready var play_btn:      Button   = $Panel/Button_manager/Jugar
@onready var ranking_btn:   Button   = $Panel/Button_manager/Ranking
@onready var ranking_panel: Control  = $RankingPanel
@onready var ranking_list:  VBoxContainer = $RankingPanel/RankingList
@onready var error_label:   Label    = $Panel/ErrorLabel
@onready var quit_btn: Button = $Panel/Button_manager/Salir


func _ready() -> void:
	error_label.text = ""
	ranking_panel.visible = false
	play_btn.pressed.connect(_on_play)
	ranking_btn.pressed.connect(_on_ranking)
	quit_btn.pressed.connect(on_quit)
	$RankingPanel/CloseButton.pressed.connect(func(): ranking_panel.visible = false)


func _on_play() -> void:
	var nick := nick_input.text.strip_edges()
	if nick.length() < 2:
		error_label.text = "MINIMO   2   CARACTERES"
		return
	if nick.length() > 20:
		error_label.text = "MAXIMO   20   CARACTERES"
		return

	error_label.text = ""
	ScoreManager.start_run(nick)
	get_tree().change_scene_to_file("res://main.tscn")


func _on_ranking() -> void:
	_populate_ranking()
	ranking_panel.visible = true

func on_quit() -> void:
	get_tree().quit()

func _populate_ranking() -> void:
	for child in ranking_list.get_children():
		child.queue_free()

	var rows := ScoreDatabase.get_ranking(10)
	if rows.is_empty():
		var lbl := Label.new()
		lbl.text = "NO   HAY   PUNTUACIONES   REGISTRADAS"
		ranking_list.add_child(lbl)
		return

	# Cabecera
	var header := Label.new()
	header.text = "%-3s   %-16s   %8s   %6s" % ["#", "NICK", "RECORD", "PARTIDAS"]
	ranking_list.add_child(header)

	for i in rows.size():
		var row : Dictionary = rows[i]
		var lbl := Label.new()
		lbl.text = "%-3d       %-16s    %8d                   %6d" % [
			i + 1,
			row["nick"],
			row["best_score"],
			row["games_played"]
		]
		ranking_list.add_child(lbl)
		
