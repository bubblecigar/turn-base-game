extends Button

@onready var game_loop: Node = $"../../GameLoop"


func _ready() -> void:
	text = "Start Loop"
	pressed.connect(_on_pressed)


func _on_pressed() -> void:
	game_loop.start()
	disabled = true
