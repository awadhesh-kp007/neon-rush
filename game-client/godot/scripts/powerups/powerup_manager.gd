## PowerupManager — Manages active power-up states, durations, and stacking.
##
## Responsibilities:
##   - Tracks which power-ups are currently active and their remaining durations
##   - Applies/removes power-up effects by emitting EventBus signals
##   - Prevents incompatible stacking (e.g., two jetpacks)
##   - Handles power-up pickup via EventBus (powerup_collected)
##   - Stacks duration if same type collected again while active
##
## Add to Autoload as "PowerupManager".

class_name PowerupManager
extends Node

# ─────────────────────────────────────────────────────────────────────────────
# Power-Up Type Registry
# ─────────────────────────────────────────────────────────────────────────────

## Default durations in seconds for each power-up type.
const POWERUP_DURATIONS: Dictionary = {
	"coin_magnet":        10.0,
	"jetpack":            8.0,
	"hoverboard":         5.0,
	"score_multiplier":   12.0,
	"shield":             6.0,
	"speed_boost":        5.0,
}

## Maximum stackable duration (seconds) per type. Prevents indefinite extension.
const MAX_STACK_DURATION: Dictionary = {
	"coin_magnet":        20.0,
	"jetpack":            16.0,
	"hoverboard":         10.0,
	"score_multiplier":   24.0,
	"shield":             12.0,
	"speed_boost":        10.0,
}

## Power-ups that cannot be active at the same time.
const MUTUALLY_EXCLUSIVE: Array[Array] = [
	["jetpack", "hoverboard"],
]

# ─────────────────────────────────────────────────────────────────────────────
# Exported
# ─────────────────────────────────────────────────────────────────────────────

@export var score_multiplier_value: float = 2.0
@export var speed_boost_multiplier: float = 1.3

# ─────────────────────────────────────────────────────────────────────────────
# State
# ─────────────────────────────────────────────────────────────────────────────

## Maps powerup_type -> remaining_duration
var _active: Dictionary = {}
var _is_running: bool = false

# ─────────────────────────────────────────────────────────────────────────────
# Lifecycle
# ─────────────────────────────────────────────────────────────────────────────

func _ready() -> void:
	EventBus.powerup_collected.connect(_on_powerup_collected)
	EventBus.game_state_changed.connect(_on_game_state_changed)
	EventBus.player_died.connect(_on_player_died)
	EventBus.hoverboard_crashed.connect(_on_hoverboard_crashed)


func _process(delta: float) -> void:
	if not _is_running or _active.is_empty():
		return
	_tick_durations(delta)

# ─────────────────────────────────────────────────────────────────────────────
# Public API
# ─────────────────────────────────────────────────────────────────────────────

## Returns true if the given power-up type is currently active.
func is_active(powerup_type: String) -> bool:
	return _active.has(powerup_type) and _active[powerup_type] > 0.0


## Returns remaining duration of a power-up (0 if inactive).
func get_remaining(powerup_type: String) -> float:
	return _active.get(powerup_type, 0.0)


## Activate a power-up programmatically (e.g., from shop/item use).
func activate(powerup_type: String, duration_override: float = -1.0) -> void:
	_do_activate(powerup_type, duration_override)


## Deactivate a power-up early (e.g., hoverboard crash).
func force_deactivate(powerup_type: String) -> void:
	if _active.has(powerup_type):
		_active.erase(powerup_type)
		EventBus.powerup_deactivated.emit(powerup_type)
		_remove_effect(powerup_type)


## Clears all active power-ups without emitting effects (used on hard reset).
func reset() -> void:
	var types_to_clear := _active.keys()
	_active.clear()
	for t in types_to_clear:
		EventBus.powerup_deactivated.emit(t)
		_remove_effect(t)

# ─────────────────────────────────────────────────────────────────────────────
# Internal Logic
# ─────────────────────────────────────────────────────────────────────────────

func _tick_durations(delta: float) -> void:
	var expired: Array[String] = []
	for ptype in _active.keys():
		_active[ptype] -= delta
		if _active[ptype] <= 0.0:
			expired.append(ptype)

	for ptype in expired:
		_active.erase(ptype)
		EventBus.powerup_deactivated.emit(ptype)
		_remove_effect(ptype)
		EventBus.powerup_timer_updated.emit(ptype, 0.0)


func _do_activate(powerup_type: String, duration_override: float) -> void:
	if not POWERUP_DURATIONS.has(powerup_type):
		push_warning("PowerupManager: Unknown power-up type '%s'." % powerup_type)
		return

	# Deactivate conflicting power-ups
	for group in MUTUALLY_EXCLUSIVE:
		if group.has(powerup_type):
			for other in group:
				if other != powerup_type and is_active(other):
					force_deactivate(other)

	var base_duration: float = POWERUP_DURATIONS[powerup_type]
	var duration: float = duration_override if duration_override > 0.0 else base_duration
	var max_dur: float = MAX_STACK_DURATION.get(powerup_type, base_duration * 2.0)

	if _active.has(powerup_type):
		# Stack: add remaining + new duration, capped
		_active[powerup_type] = minf(_active[powerup_type] + duration, max_dur)
		EventBus.powerup_timer_updated.emit(powerup_type, _active[powerup_type])
	else:
		_active[powerup_type] = minf(duration, max_dur)
		EventBus.powerup_activated.emit(powerup_type)
		_apply_effect(powerup_type)

	EventBus.powerup_timer_updated.emit(powerup_type, _active[powerup_type])


func _apply_effect(powerup_type: String) -> void:
	## Emit effect-start signals. Systems (ScoreManager, RunnerController) listen.
	match powerup_type:
		"score_multiplier":
			EventBus.multiplier_changed.emit(score_multiplier_value)
		"speed_boost":
			EventBus.speed_boost_started.emit(speed_boost_multiplier)
		"coin_magnet":
			EventBus.coin_magnet_activated.emit()
		"jetpack":
			EventBus.jetpack_activated.emit()
		"shield":
			EventBus.shield_activated.emit()
		_:
			pass


func _remove_effect(powerup_type: String) -> void:
	## Emit effect-end signals.
	match powerup_type:
		"score_multiplier":
			EventBus.multiplier_changed.emit(1.0)
		"speed_boost":
			EventBus.speed_boost_ended.emit()
		"coin_magnet":
			EventBus.coin_magnet_deactivated.emit()
		"jetpack":
			EventBus.jetpack_deactivated.emit()
		"shield":
			EventBus.shield_deactivated.emit()
		_:
			pass

# ─────────────────────────────────────────────────────────────────────────────
# Event Bus Handlers
# ─────────────────────────────────────────────────────────────────────────────

func _on_powerup_collected(powerup_type: String) -> void:
	_do_activate(powerup_type, -1.0)


func _on_hoverboard_crashed() -> void:
	force_deactivate("hoverboard")


func _on_game_state_changed(new_state: int) -> void:
	match new_state:
		GameManager.GameState.RUNNING:
			_is_running = true
		GameManager.GameState.PAUSED:
			_is_running = false
		GameManager.GameState.GAME_OVER, GameManager.GameState.MAIN_MENU:
			_is_running = false
			reset()
		_:
			pass


func _on_player_died(_position: Vector3) -> void:
	_is_running = false
	reset()
