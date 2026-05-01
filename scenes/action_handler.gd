extends Node

const MIN_CONSUME_SECONDS := 0.5
const MAX_CONSUME_SECONDS := 3.0


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	randomize()
	pass # Replace with function body.


func consume(event: Dictionary) -> void:
	print('start consume: ', event)

	var consume_seconds := randf_range(MIN_CONSUME_SECONDS, MAX_CONSUME_SECONDS)
	await get_tree().create_timer(consume_seconds).timeout

	print('consumed: ', event, ' in ', consume_seconds, 's')


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
