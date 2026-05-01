extends Button

const MIN_CHARACTER_X := 0
const MAX_CHARACTER_X := 800
const MIN_CHARACTER_Y := 0
const MAX_CHARACTER_Y := 360

@onready var action_queue: Node = $"../../ActionQueue"

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	randomize()
	pressed.connect(_on_pressed)


func _on_pressed() -> void:
	action_queue.enQueue({
		"eventName": "move_character",
		"payload": {
			"x": randi_range(MIN_CHARACTER_X, MAX_CHARACTER_X),
			"y": randi_range(MIN_CHARACTER_Y, MAX_CHARACTER_Y),
		},
	})


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
