extends Node
## Autoload: ScoreManager
## Acumula puntos durante la partida y los guarda al terminar.

var current_player_id := -1
var current_nick      := ""
var score             := 0
var enemies_killed    := 0
var _start_time       := 0.0


func start_run(nick: String) -> void:
	current_nick      = nick
	current_player_id = ScoreDatabase.register_or_get_player(nick)
	score             = 0
	enemies_killed    = 0
	_start_time       = Time.get_unix_time_from_system()


func add_kill(points: int = 100) -> void:
	enemies_killed += 1
	score          += points


func add_points(points: int) -> void:
	score += points

func remove_points(points: int) -> void:
	score -= points

func finish_run() -> void:
	if current_player_id < 0:
		return
	var elapsed := Time.get_unix_time_from_system() - _start_time
	ScoreDatabase.save_score(current_player_id, score, enemies_killed, elapsed)
