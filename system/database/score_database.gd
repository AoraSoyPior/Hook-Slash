extends Node
## Autoload: ScoreDatabase
## Gestiona el registro de jugadores y el ranking de puntuaciones.

const DB_PATH := "user://hook_and_slash.db"

var db: SQLite

func _ready() -> void:
	db = SQLite.new()
	db.path = DB_PATH
	db.open_db()
	_create_tables()


func _create_tables() -> void:
	db.query("""
        CREATE TABLE IF NOT EXISTS players (
            id         INTEGER PRIMARY KEY AUTOINCREMENT,
            nick       TEXT    NOT NULL UNIQUE,
            created_at TEXT    NOT NULL DEFAULT (datetime('now'))
        );
	""")
	db.query("""
        CREATE TABLE IF NOT EXISTS scores (
            id              INTEGER PRIMARY KEY AUTOINCREMENT,
            player_id       INTEGER NOT NULL,
            score           INTEGER NOT NULL DEFAULT 0,
            enemies_killed  INTEGER NOT NULL DEFAULT 0,
            time_seconds    REAL    NOT NULL DEFAULT 0,
            played_at       TEXT    NOT NULL DEFAULT (datetime('now')),
            FOREIGN KEY (player_id) REFERENCES players(id)
        );
	""")


## Registra un jugador nuevo. Devuelve su id, o el id existente si ya existe.
func register_or_get_player(nick: String) -> int:
	nick = nick.strip_edges()
	if nick.is_empty():
		return -1

	# Buscar si ya existe
	db.query_with_bindings("SELECT id FROM players WHERE nick = ?;", [nick])
	if db.query_result.size() > 0:
		return db.query_result[0]["id"]

	# Crear nuevo
	db.query_with_bindings("INSERT INTO players (nick) VALUES (?);", [nick])
	db.query("SELECT last_insert_rowid() as id;")
	return db.query_result[0]["id"]


## Guarda una puntuación para un jugador.
func save_score(player_id: int, score: int, enemies_killed: int, time_seconds: float) -> void:
	db.query_with_bindings("""
        INSERT INTO scores (player_id, score, enemies_killed, time_seconds)
        VALUES (?, ?, ?, ?);
	""", [player_id, score, enemies_killed, time_seconds])


## Devuelve el ranking top-N: nick, mejor puntuación, partidas jugadas.
func get_ranking(limit: int = 10) -> Array:
	db.query_with_bindings("""
        SELECT p.nick,
               MAX(s.score)          AS best_score,
               COUNT(s.id)           AS games_played,
               MIN(s.time_seconds)   AS best_time
        FROM scores s
        JOIN players p ON p.id = s.player_id
        GROUP BY s.player_id
        ORDER BY best_score DESC
        LIMIT ?;
	""", [limit])
	return db.query_result


## Puntuación máxima de un jugador concreto.
func get_player_best(player_id: int) -> int:
	db.query_with_bindings("SELECT MAX(score) as best FROM scores WHERE player_id = ?;", [player_id])
	if db.query_result.is_empty() or db.query_result[0]["best"] == null:
		return 0
	return db.query_result[0]["best"]
