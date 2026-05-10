extends Button

@onready var game_loop: Node = $"../../GameLoop"


func _ready() -> void:
	toggle_mode = true
	text = "Start Loop"
	pressed.connect(_on_pressed)


func _on_pressed() -> void:
	if button_pressed:
		text = "Stop Loop"
		game_loop.start()
	else:
		text = "Start Loop"
		game_loop.stop()
