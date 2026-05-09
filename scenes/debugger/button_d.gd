extends Button

const MIN_RADIUS := 10
const MAX_RADIUS := 40

@onready var action_queue: Node = $"../../ActionQueue"


func _ready() -> void:
	randomize()
	pressed.connect(_on_pressed)


func _on_pressed() -> void:
	action_queue.enQueue([{
		"eventName": "spawn_entity",
		"payload": {
			"type": "slime",
			"max_hp": 12,
			"spec": {
				"radius": randi_range(MIN_RADIUS, MAX_RADIUS),
			},
		},
	}])
