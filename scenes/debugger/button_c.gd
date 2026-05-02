extends Button

const MIN_BOARD_SIZE := 3
const MAX_BOARD_SIZE := 5

@onready var action_queue: Node = $"../../ActionQueue"


func _ready() -> void:
	randomize()
	pressed.connect(_on_pressed)


func _on_pressed() -> void:
	action_queue.enQueue({
		"eventName": "spawn_board",
		"payload": {
			"i": randi_range(MIN_BOARD_SIZE, MAX_BOARD_SIZE),
			"j": randi_range(MIN_BOARD_SIZE, MAX_BOARD_SIZE),
		},
	})
