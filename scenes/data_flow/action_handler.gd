extends Node

signal processing_status_changed(is_processing: bool, event: Dictionary)
signal attack_performed(attacker_id: StringName, args: Dictionary)
signal attack_prepared(attacker_id: StringName, args: Dictionary)
signal cast_resolved(caster_id: StringName, args: Dictionary, result: bool)

const MIN_CONSUME_SECONDS := 0.5
const MAX_CONSUME_SECONDS := 3.0
const MIN_CHARACTER_SIZE := 16
const MAX_CHARACTER_SIZE := 64
const MIN_HEAD_RADIUS := 6
const MAX_HEAD_RADIUS := 14
const MIN_BOARD_SIZE := 1
const MAX_BOARD_SIZE := 99
const AttackHandlerScript := preload("res://scenes/data_flow/attack_handler.gd")
const CastHandlerScript := preload("res://scenes/data_flow/cast_handler.gd")

var _current_event: Dictionary = {}
var _is_consuming := false
var _attack_handler: RefCounted
var _cast_handler: RefCounted

@onready var state_store: Node = $"../StateStore"


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	randomize()
	_attack_handler = AttackHandlerScript.new(state_store)
	_attack_handler.attack_prepared.connect(_on_attack_prepared)
	_attack_handler.attack_performed.connect(_on_attack_performed)
	_cast_handler = CastHandlerScript.new(state_store)
	_cast_handler.cast_resolved.connect(_on_cast_resolved)


func consume(event: Dictionary) -> void:
	if _is_consuming:
		push_error('Action handler is already consuming an event.')
		return

	_current_event = event
	_is_consuming = true
	print('start consume action : ', _current_event)
	processing_status_changed.emit(true, _current_event)


	print('action consumed: ', _current_event)
	_handle_consumed_event(_current_event)
	_current_event = {}
	_is_consuming = false
	processing_status_changed.emit(false, {})


func is_consuming() -> bool:
	return _is_consuming


func _handle_consumed_event(event: Dictionary) -> void:
	match event['eventName']:
		'spawn_board':
			_init_board(event['payload'])
		'spawn_entity':
			_spawn_entity(event['payload'])
		'move_entity':
			_move_entity(event['payload'])
		'perform_cast':
			_cast_handler.perform_cast(event['payload'])
		'resolve_cast':
			_cast_handler.resolve_cast(event['payload'])
		'prepare_attack':
			_attack_handler.prepare_attack(event['payload'])
		'perform_attack':
			_attack_handler.perform_attack(event['payload'])
		'debugger_button_pressed':
			_consume_debugger_button_pressed(event['payload'])
		_:
			push_warning('Unhandled consumed event: %s' % event['eventName'])


func _spawn_entity(payload: Dictionary) -> void:
	if not _is_spawn_entity_payload(payload):
		push_warning('Invalid spawn_entity payload. Expected { type: String, spec: Dictionary }.')
		return

	var entity_type := StringName(str(payload["type"]))
	var entity_spec: Dictionary = payload["spec"]

	if entity_type == &"character" and not _is_character_spec(entity_spec):
		push_warning('Invalid character entity spec.')
		return

	var max_hp := int(payload.get("max_hp", payload.get("hp", _get_default_entity_max_hp(entity_type))))
	var position: Dictionary = payload.get("position", {})
	var i := int(position.get("i", 0))
	var j := int(position.get("j", 0))
	state_store.init_entity(entity_type, entity_spec, max_hp, i, j)
	print('spawned entity: ', entity_type, ' at (', i, ',', j, ')')


func _init_board(payload: Dictionary) -> void:
	var cols := int(payload.get("i", randi_range(MIN_BOARD_SIZE, MAX_BOARD_SIZE)))
	var rows := int(payload.get("j", randi_range(MIN_BOARD_SIZE, MAX_BOARD_SIZE)))

	if not _is_board_size(cols) or not _is_board_size(rows):
		push_warning('Invalid spawn_board payload. Expected { i: int, j: int } between 3 and 5.')
		cols = randi_range(MIN_BOARD_SIZE, MAX_BOARD_SIZE)
		rows = randi_range(MIN_BOARD_SIZE, MAX_BOARD_SIZE)

	state_store.init_board(cols, rows)
	print('initialized board: ', cols, ' x ', rows)


func _is_board_size(value: int) -> bool:
	return value >= MIN_BOARD_SIZE and value <= MAX_BOARD_SIZE


func _random_character_spec() -> Dictionary:
	return {
		"head": {
			"radius": randi_range(MIN_HEAD_RADIUS, MAX_HEAD_RADIUS),
		},
		"neck": _random_part_size(),
		"body": _random_part_size(),
		"arms": _random_part_size(),
		"legs": _random_part_size(),
	}


func _get_default_entity_max_hp(entity_type: StringName) -> int:
	match entity_type:
		&"character":
			return 20
		&"slime":
			return 12
		_:
			return 1


func _random_part_size() -> Dictionary:
	return {
		"width": randi_range(MIN_CHARACTER_SIZE, MAX_CHARACTER_SIZE),
		"height": randi_range(MIN_CHARACTER_SIZE, MAX_CHARACTER_SIZE),
	}


func _is_character_spec(spec: Dictionary) -> bool:
	return (
		_is_head_spec(spec.get("head", {}))
		and _is_part_spec(spec.get("neck", {}))
		and _is_part_spec(spec.get("body", {}))
		and _is_part_spec(spec.get("arms", {}))
		and _is_part_spec(spec.get("legs", {}))
	)


func _is_spawn_entity_payload(payload: Dictionary) -> bool:
	return (
		payload.has("type")
		and payload.has("spec")
		and (typeof(payload["type"]) == TYPE_STRING or typeof(payload["type"]) == TYPE_STRING_NAME)
		and payload["spec"] is Dictionary
		and (not payload.has("max_hp") or typeof(payload["max_hp"]) == TYPE_INT or typeof(payload["max_hp"]) == TYPE_FLOAT)
		and (not payload.has("hp") or typeof(payload["hp"]) == TYPE_INT or typeof(payload["hp"]) == TYPE_FLOAT)
	)


func _is_head_spec(spec: Variant) -> bool:
	return spec is Dictionary and spec.has("radius")


func _is_part_spec(spec: Variant) -> bool:
	return spec is Dictionary and spec.has("width") and spec.has("height")


func _move_entity(payload: Dictionary) -> void:
	if not _is_move_entity_payload(payload):
		push_warning('Invalid move_entity payload. Expected { id: String, vector: Vector2i }.')
		return

	var entity_id := StringName(str(payload["id"]))
	var vector := _get_move_entity_vector(payload["vector"])
	state_store.move_entity_by(entity_id, vector)
	print('moved entity by vector: ', entity_id, ' ', vector)


func _is_move_entity_payload(payload: Dictionary) -> bool:
	return (
		payload.has("id")
		and payload.has("vector")
		and (typeof(payload["id"]) == TYPE_STRING or typeof(payload["id"]) == TYPE_STRING_NAME)
		and _is_move_vector(payload["vector"])
	)


func _is_move_vector(value: Variant) -> bool:
	return value is Vector2i or value is Vector2


func _get_move_entity_vector(value: Variant) -> Vector2i:
	if value is Vector2i:
		return value

	var vector: Vector2 = value
	return Vector2i(int(vector.x), int(vector.y))


func _on_attack_prepared(attacker_id: StringName, args: Dictionary) -> void:
	attack_prepared.emit(attacker_id, args)


func _on_attack_performed(attacker_id: StringName, args: Dictionary) -> void:
	attack_performed.emit(attacker_id, args)


func _on_cast_resolved(caster_id: StringName, args: Dictionary, result: bool) -> void:
	cast_resolved.emit(caster_id, args, result)


func _consume_debugger_button_pressed(payload: Dictionary) -> void:
	print('handled debugger button: ', payload)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
