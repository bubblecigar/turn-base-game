# Dot Turn

Dot Turn is a small Godot 4 turn/action prototype. The project is organized around
queued game actions, a central state store, and visuals that react to state signals.

## Run

Open this folder in Godot 4.6 or run:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path .
```

## Architecture

The main gameplay scene is `scenes/TurnBaseScene.tscn`. It owns the root systems:

- `ActionQueue`: accepts event dictionaries and consumes them in order.
- `ActionHandler`: validates and applies each event.
- `StateStore`: owns board/entity state and emits state-change signals.
- `AnimationTracker`: tracks active visual animations so queued actions wait for them.
- `View`: contains `BoardView` and `EntitiesLayer`.
- `StageController`: loads an initial stage template and enqueues spawn actions.
- `Debugger`: UI buttons for spawning, moving, and printing state.

## Action Flow

Game changes are requested as batches of action dictionaries:

```gdscript
[
	{
		"eventName": "move_entity",
		"payload": {
			"id": &"character_1",
			"vector": Vector2i(1, 0),
		},
	},
]
```

`ActionQueue.enQueue()` stores action batches and only consumes the next batch when:

- `ActionHandler` is not already consuming an action.
- `AnimationTracker` has no active animations.
- The queue is not empty.

Every action in the same batch is consumed before the queue waits for animations
again.

`ActionHandler.consume()` dispatches by `eventName`. Current actions include:

- `spawn_board`
- `spawn_entity`
- `move_entity`
- `perform_cast`
- `resolve_cast`
- `perform_attack`

The handler should stay thin: validate payloads, normalize values, and call the
appropriate `StateStore` function or emit a transient action signal.

## State Model

`StateStore` is the source of truth. Its default state is:

```gdscript
{
	&"board": {},
	&"entities": {},
}
```

The board is a dictionary with `cols`, `rows`, `cell_size`, and `cells`. Each cell
stores its board index and an `entity_ids` array, so several entities can occupy
the same board cell.

Entities are stored separately by id:

```gdscript
{
	&"character_1": {
		&"id": &"character_1",
		&"type": &"character",
		&"max_hp": 20,
		&"current_hp": 20,
		&"focus": 0,
		&"state": &"idle",
		&"cast_args": {},
		&"spec": {...},
	},
}
```

State changes are announced with signals:

- `entities_updated`
- `board_init`
- `entity_moved`
- `entity_focus_changed`
- `cast_resolved`
- generic `state_changed` and `value_changed`

## Visual Layer

`BoardView` listens for `board_init` and redraws the grid.

`EntitiesLayer` listens for `entities_updated`. It instantiates the correct visual
scene for each entity type:

- `CharacterScene.tscn`
- `SlimeScene.tscn`

Each entity visual extends `entity_base.gd`. The base script resolves references
to `StateStore`, `AnimationTracker`, and `BoardView` through exported `NodePath`s
assigned by `EntitiesLayer`.

Entity visuals update their board position from state. They also react to signals:

- `entity_moved`: tween to the new cell.
- `entity_focus_changed`: pop the focus display above the HP bar.

Move animations register with `AnimationTracker`. This keeps the action queue from
consuming the next action before the current visual reaction is finished.

## Stage Initialization

`StageController` loads `scenes/stage_control/stage_templates.json`. It chooses a
stage by `stage_key` when provided, otherwise it picks one template key at random.
The template is converted into queued actions:

1. `spawn_board`
2. one `spawn_entity` action per entity in the template

This keeps startup behavior on the same action path as debugger/user-triggered
changes.

## Debugger

`scenes/debugger/Debugger.tscn` contains development buttons. Each button has a
small script that calls `ActionQueue.enQueue()` or reads `StateStore` directly.

Examples:

- spawn a random board
- spawn a character using the spinbox values
- spawn a slime
- move the latest entity
- attack with a random attacker/receiver pair
- print the full `StateStore` state to the console
