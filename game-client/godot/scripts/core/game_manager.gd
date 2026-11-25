## GameManager — Central state machine for NEON RUSH.
##
## Manages the game session lifecycle as a hierarchical state machine.
## All other systems react to EventBus signals; they never call GameManager
## directly. This keeps the game architecture decoupled and testable.
##
## States: INITIALIZING → MAIN_MENU → COUNTDOWN → RUNNING → PAUSED
##         → REVIVING → GAME_OVER → RESULTS
##
## Register as an Autoload singleton named "GameManager".

extends Node

# ─────────────────────────────────────────────────────────────────────────────
# State Enum
# ─────────────────────────────────────────────────────────────────────────────
enum GameState {
	INITIALIZING,
	MAIN_MENU,
	COUNTDOWN,
	RUNNING,
	PAUSED,
	REVIVING,
	GAME_OVER,
	RESULTS
}

# ─────────────────────────────────────────────────────────────────────────────
# Exported Configuration
# ─────────────────────────────────────────────────────────────────────────────
@export var countdown_duration: float = 3.0
@export var revive_invincibility_duration: float = 3.0

# ─────────────────────────────────────────────────────────────────────────────
# State
# ─────────────────────────────────────────────────────────────────────────────
var current_state: GameState = GameState.INITIALIZING
var previous_state: GameState = GameState.INITIALIZING
var _countdown_timer: float = 0.0
var _revive_timer: float = 0.0
var _run_start_time: float = 0.0

# ─────────────────────────────────────────────────────────────────────────────
# Godot Lifecycle
# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	# Wait one frame for all autoloads to initialize before transitioning
	await get_tree().process_frame
	_transition_to(GameState.MAIN_MENU)


func _process(delta: float) -> void:
	match current_state:
		GameState.COUNTDOWN:
			_process_countdown(delta)
		GameState.REVIVING:
			_process_revive(delta)

# ─────────────────────────────────────────────────────────────────────────────
# Public API
# ─────────────────────────────────────────────────────────────────────────────

## Begin a new run from the main menu or results screen.
func start_run() -> void:
	if current_state not in [GameState.MAIN_MENU, GameState.RESULTS]:
		push_warning("[GameManager] start_run() called in invalid state: %s" % GameState.keys()[current_state])
		return
	_transition_to(GameState.COUNTDOWN)


## Pause the running game. Only valid while RUNNING.
func pause_game() -> void:
	if current_state != GameState.RUNNING:
		return
	get_tree().paused = true
	_transition_to(GameState.PAUSED)


## Resume from pause.
func resume_game() -> void:
	if current_state != GameState.PAUSED:
		return
	get_tree().paused = false
	_transition_to(GameState.RUNNING)


## Called by the player collision system when a fatal hit occurs.
## @param obstacle_name: The name/type of obstacle that was hit.
func trigger_game_over(obstacle_name: String = "") -> void:
	if current_state in [GameState.GAME_OVER, GameState.REVIVING]:
		return
	get_tree().paused = false  # Unblock physics for death animation
	_transition_to(GameState.GAME_OVER)
	EventBus.player_fatal_collision.emit(obstacle_name)


## Grant the player a revive (called after watching a rewarded ad or spending gems).
func trigger_revive() -> void:
	if current_state != GameState.GAME_OVER:
		push_warning("[GameManager] trigger_revive() called outside GAME_OVER state")
		return
	_revive_timer = revive_invincibility_duration
	_transition_to(GameState.REVIVING)


## Fully restart the run from scratch. Can be called from GAME_OVER or RESULTS.
func restart_run() -> void:
	if current_state not in [GameState.GAME_OVER, GameState.RESULTS, GameState.PAUSED]:
		push_warning("[GameManager] restart_run() called in invalid state: %s" % GameState.keys()[current_state])
		return
	get_tree().paused = false
	_transition_to(GameState.COUNTDOWN)


## Return to the main menu.
func go_to_main_menu() -> void:
	get_tree().paused = false
	_transition_to(GameState.MAIN_MENU)


## Check whether gameplay systems (physics, spawning, scoring) should be active.
func is_gameplay_active() -> bool:
	return current_state in [GameState.RUNNING, GameState.REVIVING]


## Human-readable name of the current state.
func state_name() -> String:
	return GameState.keys()[current_state]

# ─────────────────────────────────────────────────────────────────────────────
# State Processing
# ─────────────────────────────────────────────────────────────────────────────

func _process_countdown(delta: float) -> void:
	_countdown_timer -= delta
	var secs_remaining: int = ceili(_countdown_timer)
	EventBus.countdown_tick.emit(secs_remaining)

	if _countdown_timer <= 0.0:
		_transition_to(GameState.RUNNING)


func _process_revive(delta: float) -> void:
	_revive_timer -= delta
	if _revive_timer <= 0.0:
		_transition_to(GameState.RUNNING)

# ─────────────────────────────────────────────────────────────────────────────
# State Machine
# ─────────────────────────────────────────────────────────────────────────────

func _transition_to(new_state: GameState) -> void:
	if current_state == new_state:
		return

	previous_state = current_state
	current_state = new_state

	var from_name: String = GameState.keys()[previous_state]
	var to_name: String = GameState.keys()[current_state]
	print("[GameManager] %s → %s" % [from_name, to_name])

	# Emit lifecycle events
	EventBus.game_state_changed.emit(from_name, to_name)

	match current_state:
		GameState.COUNTDOWN:
			_countdown_timer = countdown_duration
			EventBus.game_restarted.emit()

		GameState.RUNNING:
			if previous_state == GameState.COUNTDOWN:
				_run_start_time = Time.get_unix_time_from_system()
				EventBus.game_started.emit()
			elif previous_state == GameState.PAUSED:
				EventBus.game_resumed.emit()

		GameState.PAUSED:
			EventBus.game_paused.emit()

		GameState.GAME_OVER:
			var run_result := _build_run_result()
			EventBus.game_over.emit(run_result)

		GameState.MAIN_MENU:
			pass  # Main menu handles its own presentation


func _build_run_result() -> Dictionary:
	# ScoreManager is queried via its own singleton; we just package the result.
	var score_mgr = get_node_or_null("/root/ScoreManager")
	if score_mgr == null:
		return {}

	return {
		"score": score_mgr.current_score,
		"distance_m": score_mgr.current_distance,
		"coins_collected": score_mgr.coins_collected,
		"duration_seconds": Time.get_unix_time_from_system() - _run_start_time,
		"is_new_high_score": score_mgr.is_new_high_score()
	}
