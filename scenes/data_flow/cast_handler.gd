extends RefCounted

signal cast_performed(caster_id: StringName, args: Dictionary)
signal cast_resolved(caster_id: StringName, args: Dictionary, result: bool)

const CAST_TYPE_FOCUS := &"focus"
const SCHEMAS := {
	"focus": {
		"required": ["type", "value"],
		"fields": {
			"type": TYPE_STRING,
			"value": TYPE_INT,
			"source": TYPE_STRING,
		},
	},
}

var _state_store: Node


func _init(state_store: Node) -> void:
	_state_store = state_store


func perform_cast(payload: Dictionary) -> void:
	if not _is_cast_payload(payload):
		push_warning('Invalid perform_cast payload. Check CastHandler.SCHEMAS for supported cast args.')
		return

	var caster_id := StringName(str(payload["id"]))
	if not _state_store.has_entity(caster_id):
		push_warning("Cannot perform cast with missing entity: %s." % caster_id)
		return

	var args: Dictionary = payload["args"].duplicate(true)
	match StringName(str(args["type"])):
		CAST_TYPE_FOCUS:
			_state_store.start_entity_casting(caster_id, args)
		_:
			push_warning("Unsupported perform_cast type: %s." % args["type"])
			return

	cast_performed.emit(caster_id, args)
	print('performed cast: ', caster_id, ' ', args)


func resolve_cast(payload: Dictionary) -> void:
	if not _is_resolve_cast_payload(payload):
		push_warning('Invalid resolve_cast payload. Expected { entity_id: String, result: bool }.')
		return

	var caster_id := StringName(str(payload["entity_id"]))
	if not _state_store.has_entity(caster_id):
		push_warning("Cannot resolve cast for missing entity: %s." % caster_id)
		return

	var cast_args := _get_entity_cast_args(caster_id)
	if cast_args.is_empty():
		_state_store.resolve_entity_cast(caster_id, bool(payload["result"]))
		return

	var result := bool(payload["result"])
	if result and not _apply_successful_cast_result(caster_id, cast_args):
		return

	_state_store.resolve_entity_cast(caster_id, result)
	cast_resolved.emit(caster_id, cast_args, result)
	print('resolved cast: ', caster_id, ' ', cast_args, ' result=', result)


func _apply_successful_cast_result(caster_id: StringName, args: Dictionary) -> bool:
	match StringName(str(args["type"])):
		CAST_TYPE_FOCUS:
			var focus_gain: int = max(int(args.get("value", 0)), 0)
			_state_store.increase_entity_focus(caster_id, focus_gain)
			return true
		_:
			push_warning("Unsupported cast resolve type: %s." % args["type"])
			return false


func _is_cast_payload(payload: Dictionary) -> bool:
	return (
		payload.has("id")
		and payload.has("args")
		and (typeof(payload["id"]) == TYPE_STRING or typeof(payload["id"]) == TYPE_STRING_NAME)
		and payload["args"] is Dictionary
		and _is_cast_args(payload["args"])
	)


func _is_cast_args(args: Dictionary) -> bool:
	if not args.has("type") or typeof(args["type"]) != TYPE_STRING:
		return false

	var cast_type := str(args["type"])
	if not SCHEMAS.has(cast_type):
		return false

	var schema: Dictionary = SCHEMAS[cast_type]
	var required_fields: Array = schema.get("required", [])
	for field_name: String in required_fields:
		if not args.has(field_name):
			return false

	var fields: Dictionary = schema.get("fields", {})
	for field_name: String in fields:
		if not args.has(field_name):
			continue

		if typeof(args[field_name]) != int(fields[field_name]):
			return false

	return true


func _is_resolve_cast_payload(payload: Dictionary) -> bool:
	return (
		payload.has("entity_id")
		and payload.has("result")
		and (typeof(payload["entity_id"]) == TYPE_STRING or typeof(payload["entity_id"]) == TYPE_STRING_NAME)
		and typeof(payload["result"]) == TYPE_BOOL
	)


func _get_entity_cast_args(entity_id: StringName) -> Dictionary:
	var entities: Dictionary = _state_store.get_value(&"entities", {})
	var entity: Dictionary = entities.get(entity_id, {})
	if entity.is_empty():
		return {}

	return entity.get(&"cast_args", {}).duplicate(true)
