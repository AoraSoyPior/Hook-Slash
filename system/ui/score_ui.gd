extends Label

func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_update()

func _process(_delta: float) -> void:
	_update()

func _update() -> void:
	text = "%d" % ScoreManager.score
