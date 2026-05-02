extends Button

@onready var action_queue: Node = $"../../ActionQueue"
@onready var state_store: Node = $"../../StateStore"

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	randomize()
	pressed.connect(_on_pressed)


func _on_pressed() -> void:
	var board: Dictionary = state_store.get_value(&"board", {})
	if board.is_empty():
		push_warning("Cannot move character before board is spawned.")
		return

	action_queue.enQueue({
		"eventName": "move_character",
		"payload": {
			"i": randi_range(0, int(board.get(&"cols", 1)) - 1),
			"j": randi_range(0, int(board.get(&"rows", 1)) - 1),
		},
	})


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
