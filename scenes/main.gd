extends Node2D

const BASE_SIZE := Vector2(960.0, 540.0)


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	get_viewport().size_changed.connect(_fit_to_viewport)
	_fit_to_viewport()


func _fit_to_viewport() -> void:
	var viewport_size := get_viewport_rect().size
	var fit_scale: float = minf(
		viewport_size.x / BASE_SIZE.x,
		viewport_size.y / BASE_SIZE.y
	)

	scale = Vector2(fit_scale, fit_scale)
	position = (viewport_size - BASE_SIZE * fit_scale) / 2.0


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
