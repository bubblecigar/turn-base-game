extends Node2D

const TURN_SNACKBAR_SIZE := Vector2(240.0, 36.0)
const TURN_SNACKBAR_START_Y := 88.0
const TURN_SNACKBAR_RISE_PIXELS := 24.0
const TURN_SNACKBAR_ANIMATION_SECONDS := 0.85
const TURN_SNACKBAR_FONT_SIZE := 18
const TURN_SNACKBAR_COLOR := Color(1.0, 0.92, 0.42, 1.0)

var _turn_snackbar_label: Label
var _turn_snackbar_tween: Tween

@onready var action_handler: Node = $ActionHandler
@onready var canvas_layer: CanvasLayer = $CanvasLayer


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	action_handler.turn_start.connect(_on_turn_start)
	action_handler.turn_end.connect(_on_turn_end)
	print('scene ready')


func _on_turn_start(event: Dictionary) -> void:
	_show_turn_snackbar(event, "start")


func _on_turn_end(event: Dictionary) -> void:
	_show_turn_snackbar(event, "end")


func _show_turn_snackbar(event: Dictionary, phase: String) -> void:
	if _turn_snackbar_tween:
		_turn_snackbar_tween.kill()

	if _turn_snackbar_label == null:
		_turn_snackbar_label = Label.new()
		_turn_snackbar_label.name = "TurnSnackbarLabel"
		_turn_snackbar_label.add_theme_font_size_override("font_size", TURN_SNACKBAR_FONT_SIZE)
		_turn_snackbar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_turn_snackbar_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_turn_snackbar_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		canvas_layer.add_child(_turn_snackbar_label)

	var payload: Dictionary = event.get("payload", {})
	var turn_index := int(payload.get("turn_index", 0))
	var viewport_size := get_viewport_rect().size
	var start_position := Vector2(
		(viewport_size.x - TURN_SNACKBAR_SIZE.x) / 2.0,
		TURN_SNACKBAR_START_Y
	)

	_turn_snackbar_label.text = "turn %d %s" % [turn_index, phase]
	_turn_snackbar_label.size = TURN_SNACKBAR_SIZE
	_turn_snackbar_label.position = start_position
	_turn_snackbar_label.modulate = TURN_SNACKBAR_COLOR
	_turn_snackbar_label.show()
	_turn_snackbar_label.move_to_front()

	_turn_snackbar_tween = create_tween()
	_turn_snackbar_tween.set_parallel(true)
	_turn_snackbar_tween.tween_property(
		_turn_snackbar_label,
		"position",
		start_position - Vector2(0.0, TURN_SNACKBAR_RISE_PIXELS),
		TURN_SNACKBAR_ANIMATION_SECONDS
	)
	_turn_snackbar_tween.tween_property(
		_turn_snackbar_label,
		"modulate:a",
		0.0,
		TURN_SNACKBAR_ANIMATION_SECONDS
	)
	_turn_snackbar_tween.finished.connect(_on_turn_snackbar_tween_finished)


func _on_turn_snackbar_tween_finished() -> void:
	if _turn_snackbar_label:
		_turn_snackbar_label.hide()

	_turn_snackbar_tween = null


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
