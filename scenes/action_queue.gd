extends Node

var _event_queue: Array[Variant] = []


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	print('action queue ready');
	pass # Replace with function body.


func enQueue(event: Variant) -> void:
	_event_queue.append(event)
	print(_event_queue);


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
