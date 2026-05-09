extends Node

var _event_queue: Array[Array] = []

@onready var action_handler: Node = $"../ActionHandler"
@onready var animation_tracker: Node = $"../AnimationTracker"


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	print('action queue ready');
	animation_tracker.active_animations_changed.connect(_on_active_animations_changed)
	pass # Replace with function body.


func enQueue(events: Array) -> void:
	if not _is_valid_event_batch(events):
		push_error('Invalid action queue events. Expected a non-empty Array[Dictionary] of { eventName: String, payload: Dictionary }.')
		return

	_event_queue.append(events)
	print(_event_queue);
	consume_next()


func _is_valid_event_batch(events: Array) -> bool:
	if events.is_empty():
		return false

	for event: Variant in events:
		if not event is Dictionary:
			return false

		if not _is_valid_event(event):
			return false

	return true


func _is_valid_event(event: Dictionary) -> bool:
	return (
		event.has('eventName')
		and event.has('payload')
		and typeof(event['eventName']) == TYPE_STRING
		and typeof(event['payload']) == TYPE_DICTIONARY
	)


func consume_next() -> void:
	if action_handler.is_consuming() or animation_tracker.has_active_animations() or _event_queue.is_empty():
		return

	var events: Array = _event_queue.pop_front()
	for event: Dictionary in events:
		await action_handler.consume(event)

	consume_next()


func _on_active_animations_changed(active_animation_ids: Array[StringName]) -> void:
	if active_animation_ids.is_empty():
		consume_next()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
