extends Node

signal processing_status_changed(is_processing: bool, event: Dictionary)
signal attack_performed(attacker_id: StringName, args: Dictionary)
signal attack_prepared(attacker_id: StringName, args: Dictionary)
signal cast_performed(caster_id: StringName, args: Dictionary)
signal cast_resolved(caster_id: StringName, args: Dictionary, result: bool)
signal event_performed(event: Dictionary)
signal turn_start(event: Dictionary)
signal turn_end(event: Dictionary)
signal check_for_winner(event: Dictionary)
signal end_battle(event: Dictionary)

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
const CardPoolServiceScript := preload("res://scenes/gui/card_pool_service.gd")

var _current_event: Dictionary = {}
var _is_consuming := false
var _attack_handler: RefCounted
var _cast_handler: RefCounted
var _card_pool_service: RefCounted
var _global_selected_entity_loaded := false

@onready var state_store: Node = $"../BattleStateStore"
@onready var global_state_store: Node = $"../GlobalStateStore"


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	randomize()
	_attack_handler = AttackHandlerScript.new(state_store)
	_attack_handler.attack_prepared.connect(_on_attack_prepared)
	_attack_handler.attack_performed.connect(_on_attack_performed)
	_cast_handler = CastHandlerScript.new(state_store)
	_cast_handler.cast_performed.connect(_on_cast_performed)
	_cast_handler.cast_resolved.connect(_on_cast_resolved)
	_card_pool_service = CardPoolServiceScript.new(state_store)


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
	event_performed.emit(_current_event)
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
		'update_entity_card_pool':
			_update_entity_card_pool(event['payload'])
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
		'turn_start':
			turn_start.emit(event)
		'turn_end':
			turn_end.emit(event)
		'check_for_winner':
			check_for_winner.emit(event)
		'end_battle':
			_end_battle(event['payload'])
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

	var global_selected_entity := _get_global_selected_entity_for_type(entity_type)
	var entity_overrides: Dictionary = global_selected_entity.get(&"data", {})
	var saved_card_pool: Array[Dictionary] = _get_global_selected_entity_card_pool(global_selected_entity)
	var max_hp := int(entity_overrides.get(&"max_hp", payload.get("max_hp", payload.get("hp", _get_default_entity_max_hp(entity_type)))))
	var position: Dictionary = payload.get("position", {})
	var i := int(position.get("i", 0))
	var j := int(position.get("j", 0))
	var entity_id: StringName = state_store.init_entity(entity_type, entity_spec, max_hp, i, j, entity_overrides)
	if not entity_overrides.is_empty():
		_global_selected_entity_loaded = true
		print("loaded global selected entity into battle state: ", entity_overrides)
	if not saved_card_pool.is_empty():
		state_store.set_entity_card_pool(entity_id, saved_card_pool)
	elif payload.has("cards") and payload["cards"] is Array:
		state_store.set_entity_card_pool(entity_id, _card_pool_service.get_cards_by_ids(payload["cards"]))
	else:
		push_warning("spawn_entity: missing 'cards' in payload for entity '%s'. Card pool not initialized." % entity_type)
	print('spawned entity: ', entity_type, ' at (', i, ',', j, ')')


func _get_global_selected_entity_for_type(entity_type: StringName) -> Dictionary:
	if _global_selected_entity_loaded or global_state_store == null:
		return {}

	var selected_entity: Dictionary = global_state_store.get_selected_entity()
	var data: Dictionary = selected_entity.get(&"data", {})
	if data.is_empty():
		return {}
	if StringName(str(data.get(&"type", &""))) != entity_type:
		return {}

	return selected_entity


func _get_global_selected_entity_card_pool(selected_entity: Dictionary) -> Array[Dictionary]:
	var card_pool: Array[Dictionary] = []
	var raw_card_pool: Array = selected_entity.get(&"card_pool", [])
	for raw_card: Variant in raw_card_pool:
		if raw_card is Dictionary:
			card_pool.append(raw_card.duplicate(true))

	return card_pool


func _end_battle(payload: Dictionary) -> void:
	print("battle ended: %s" % str(payload.get("result", "unknown result")))
	_save_selected_entity_to_global_state(payload)
	end_battle.emit({
		"eventName": "end_battle",
		"payload": payload,
	})


func _save_selected_entity_to_global_state(payload: Dictionary) -> void:
	if state_store == null or global_state_store == null:
		return

	var selected_entity_id: StringName = state_store.get_selected_entity_id()
	if selected_entity_id == &"":
		print("global state store: no selected entity to save")
		return

	var entities: Dictionary = state_store.get_value(&"entities", {})
	var selected_entity: Dictionary = entities.get(selected_entity_id, {})
	if selected_entity.is_empty():
		print("global state store: selected entity missing: %s" % selected_entity_id)
		return

	var defeated_entity_ids: Array = payload.get("defeated_entity_ids", [])
	if _entity_id_array_has(defeated_entity_ids, selected_entity_id):
		global_state_store.clear_selected_entity()
		print("global state store: selected entity defeated; cleared selected entity")
		print("global state store: ", global_state_store.get_state())
		return

	var winner_entity_ids: Array = payload.get("winner_entity_ids", [])
	if not _entity_id_array_has(winner_entity_ids, selected_entity_id):
		print("global state store: selected entity is not a winner; skipped selected entity save")
		return

	var card_pool: Array[Dictionary] = state_store.get_entity_card_pool(selected_entity_id)
	var reward_card: Dictionary = {}
	if _card_pool_service != null:
		reward_card = _card_pool_service.get_random_card()
	if not reward_card.is_empty():
		card_pool.append(reward_card)
		print("global state store: added winner card: ", reward_card)

	global_state_store.save_selected_entity(selected_entity_id, selected_entity, card_pool)
	print("global state store: ", global_state_store.get_state())


func _entity_id_array_has(entity_ids: Array, entity_id: StringName) -> bool:
	for raw_entity_id: Variant in entity_ids:
		if StringName(str(raw_entity_id)) == entity_id:
			return true

	return false


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


func _update_entity_card_pool(payload: Dictionary) -> void:
	if not _is_entity_card_pool_write_payload(payload):
		push_warning('Invalid update_entity_card_pool payload. Expected { id: String, cards: Array[Dictionary] }.')
		return

	var entity_id := StringName(str(payload["id"]))
	state_store.set_entity_card_pool(entity_id, _get_card_pool_cards(payload["cards"]))
	print("updated entity card pool: %s" % entity_id)


func _is_entity_card_pool_id_payload(payload: Dictionary) -> bool:
	return (
		payload.has("id")
		and (typeof(payload["id"]) == TYPE_STRING or typeof(payload["id"]) == TYPE_STRING_NAME)
		and StringName(str(payload["id"])) != &""
	)


func _is_entity_card_pool_write_payload(payload: Dictionary) -> bool:
	return (
		_is_entity_card_pool_id_payload(payload)
		and payload.has("cards")
		and payload["cards"] is Array
		and _is_card_pool_cards(payload["cards"])
	)


func _is_card_pool_cards(raw_cards: Array) -> bool:
	for raw_card: Variant in raw_cards:
		if not raw_card is Dictionary:
			return false

	return true


func _get_card_pool_cards(raw_cards: Array) -> Array[Dictionary]:
	var cards: Array[Dictionary] = []
	for raw_card: Variant in raw_cards:
		if raw_card is Dictionary:
			cards.append(raw_card.duplicate(true))

	return cards


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


func _on_cast_performed(caster_id: StringName, args: Dictionary) -> void:
	cast_performed.emit(caster_id, args)


func _on_cast_resolved(caster_id: StringName, args: Dictionary, result: bool) -> void:
	cast_resolved.emit(caster_id, args, result)


func _consume_debugger_button_pressed(payload: Dictionary) -> void:
	print('handled debugger button: ', payload)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
