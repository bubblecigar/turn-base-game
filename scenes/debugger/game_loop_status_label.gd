extends Label

@onready var game_loop: Node = $"../../GameLoop"


func _ready() -> void:
	text = "Game loop: waiting"
	game_loop.status_changed.connect(_on_game_loop_status_changed)


func _on_game_loop_status_changed(status: String) -> void:
	text = "Game loop: %s" % status
