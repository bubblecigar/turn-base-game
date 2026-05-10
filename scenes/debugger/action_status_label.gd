extends Label

@onready var action_queue: Node = $"../../ActionQueue"
@onready var action_handler: Node = $"../../ActionHandler"


func _ready() -> void:
	text = "Action: idle"
	action_queue.batch_enqueued.connect(_on_batch_enqueued)
	action_queue.batch_started.connect(_on_batch_started)
	action_queue.queue_drained.connect(_on_queue_drained)
	action_handler.processing_status_changed.connect(_on_processing_status_changed)


func _on_batch_enqueued(events: Array, pending_batch_count: int) -> void:
	text = "Action queued: %s (%d pending)" % [_summarize_events(events), pending_batch_count]


func _on_batch_started(events: Array, pending_batch_count: int) -> void:
	text = "Action batch: %s (%d pending)" % [_summarize_events(events), pending_batch_count]


func _on_queue_drained() -> void:
	text = "Action: idle"


func _on_processing_status_changed(is_processing: bool, event: Dictionary) -> void:
	if is_processing:
		text = "Action processing: %s" % event.get("eventName", "unknown")


func _summarize_events(events: Array) -> String:
	var event_names: Array[String] = []
	for event: Dictionary in events:
		event_names.append(str(event.get("eventName", "unknown")))

	return ", ".join(event_names)
