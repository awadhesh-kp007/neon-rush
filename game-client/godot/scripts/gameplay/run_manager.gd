## RunManager — Orchestrates the lifecycle of a single game run.
##
## Responsibilities:
##   - Triggers run start sequence (countdown → run)
##   - Handles game over sequence (delay → results)
##   - Coordinates with GameManager state machine
##   - Tracks run start timestamp for session duration
##   - Emits run_started and run_ended events on EventBus

class_name RunManager
extends Node

@export var countdown_duration: float = 3.0
@export var game_over_delay: float = 1.5   ## Delay before showing results screen

var _run_start_time: float = 0.0
var _countdown_timer: float = 0.0
var _game_over_timer: float = -1.0
var _in_countdown: bool = false
var _in_game_over_wait: bool = false

func _ready() -> void:
	EventBus.game_state_changed.connect(_on_game_state_changed)
	EventBus.player_died.connect(_on_player_died)


func _process(delta: float) -> void:
	if _in_countdown:
		_tick_countdown(delta)
	elif _in_game_over_wait:
		_tick_game_over(delta)

# ─────────────────────────────────────────────────────────────────────────────
# Public API
# ─────────────────────────────────────────────────────────────────────────────

## Begin a new run from the main menu.
func begin_run() -> void:
	if GameManager.state != GameManager.GameState.MAIN_MENU:
		push_warning("RunManager: begin_run() called outside MAIN_MENU state.")
		return
	GameManager.change_state(GameManager.GameState.COUNTDOWN)


## Get seconds elapsed since run start (0 if not running).
func get_run_duration() -> float:
	if _run_start_time <= 0.0:
		return 0.0
	return Time.get_unix_time_from_system() - _run_start_time

# ─────────────────────────────────────────────────────────────────────────────
# Internal Tick
# ─────────────────────────────────────────────────────────────────────────────

func _tick_countdown(delta: float) -> void:
	_countdown_timer -= delta
	var remaining := ceilf(_countdown_timer)
	EventBus.countdown_tick.emit(remaining)
	if _countdown_timer <= 0.0:
		_in_countdown = false
		_run_start_time = Time.get_unix_time_from_system()
		GameManager.change_state(GameManager.GameState.RUNNING)
		EventBus.run_started.emit()


func _tick_game_over(delta: float) -> void:
	_game_over_timer -= delta
	if _game_over_timer <= 0.0:
		_in_game_over_wait = false
		GameManager.change_state(GameManager.GameState.RESULTS)

# ─────────────────────────────────────────────────────────────────────────────
# Event Bus Handlers
# ─────────────────────────────────────────────────────────────────────────────

func _on_game_state_changed(new_state: int) -> void:
	match new_state:
		GameManager.GameState.COUNTDOWN:
			_in_countdown = true
			_countdown_timer = countdown_duration
		GameManager.GameState.MAIN_MENU:
			_in_countdown = false
			_in_game_over_wait = false
			_run_start_time = 0.0
		_:
			pass


func _on_player_died(_position: Vector3) -> void:
	var duration := get_run_duration()
	EventBus.run_ended.emit(ScoreManager.score, ScoreManager.total_coins_collected, duration)
	_in_game_over_wait = true
	_game_over_timer = game_over_delay
