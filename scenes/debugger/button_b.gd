extends Button

@onready var action_queue: Node = get_parent().get_parent()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pressed.connect(_on_pressed)


func _on_pressed() -> void:
	action_queue.enQueue({
		"eventName": "debugger_button_pressed",
		"payload": {
			"source": name,
			"text": text,
		},
	})


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
