## ScoreManager — Tracks score, distance, coins, XP for a run.
##
## Server-authoritative design: local values are used for HUD display only.
## Final score is submitted to the backend for server-side validation.
## Register as an Autoload singleton named "ScoreManager".

extends Node

# ─────────────────────────────────────────────────────────────────────────────
# State
# ─────────────────────────────────────────────────────────────────────────────
var current_score: int = 0
var current_distance: float = 0.0
var coins_collected: int = 0
var run_duration_seconds: float = 0.0
var current_multiplier: float = 1.0

var _best_score: int = 0
var _score_emit_cooldown: float = 0.0
const SCORE_EMIT_RATE: float = 0.1  # Emit score change max 10x/sec

# ─────────────────────────────────────────────────────────────────────────────
# Godot Lifecycle
# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	_best_score = ProjectSettings.get_setting("user://best_score", 0)
	# Fallback to PlayerPrefs-style save
	var config := ConfigFile.new()
	if config.load("user://save.cfg") == OK:
		_best_score = config.get_value("score", "best", 0)

	EventBus.game_started.connect(_on_game_started)
	EventBus.game_restarted.connect(_on_game_restarted)
	EventBus.coin_collected.connect(_on_external_coin_signal)


func _exit_tree() -> void:
	EventBus.game_started.disconnect(_on_game_started)
	EventBus.game_restarted.disconnect(_on_game_restarted)


func _process(delta: float) -> void:
	if not GameManager.is_gameplay_active():
		return

	run_duration_seconds += delta
	_score_emit_cooldown -= delta

	# Forward movement score (driven by distance)
	# Distance is updated by DifficultyManager, not here directly.

# ─────────────────────────────────────────────────────────────────────────────
# Public API
# ─────────────────────────────────────────────────────────────────────────────

## Called by TrackGenerator/DifficultyManager each frame with distance delta.
func add_distance(delta_m: float) -> void:
	current_distance += delta_m
	var distance_score := int(delta_m * GameConstants.SCORE_PER_METER * current_multiplier)
	_add_to_score(distance_score)
	EventBus.distance_changed.emit(current_distance)


## Called when the player collects a coin.
func add_coins(count: int) -> void:
	coins_collected += count
	var coin_score := count * GameConstants.SCORE_PER_COIN
	_add_to_score(coin_score)
	EventBus.coin_collected.emit(count, coins_collected)


## Called by PowerUpManager when a multiplier is activated/deactivated.
func set_multiplier(multiplier: float) -> void:
	current_multiplier = multiplier
	EventBus.multiplier_changed.emit(current_multiplier)


## Calculate XP earned from this run.
func calculate_xp() -> int:
	return int(current_score / GameConstants.XP_DIVISOR)


## True if the current score beats the saved best.
func is_new_high_score() -> bool:
	return current_score > _best_score


## Package current run data as a Dictionary for game-over screen and backend.
func capture_run_result() -> Dictionary:
	var new_high := is_new_high_score()
	if new_high:
		_save_best_score(current_score)
		EventBus.new_high_score.emit(current_score)

	return {
		"score": current_score,
		"distance_m": current_distance,
		"coins_collected": coins_collected,
		"duration_seconds": run_duration_seconds,
		"xp_earned": calculate_xp(),
		"is_new_high_score": new_high,
		"multiplier_max": current_multiplier
	}


func get_best_score() -> int:
	return _best_score

# ─────────────────────────────────────────────────────────────────────────────
# Private
# ─────────────────────────────────────────────────────────────────────────────

func _add_to_score(amount: int) -> void:
	current_score += amount
	# Throttle UI updates to max 10x/second to avoid flooding the signal bus
	if _score_emit_cooldown <= 0.0:
		EventBus.score_changed.emit(current_score)
		_score_emit_cooldown = SCORE_EMIT_RATE


func _save_best_score(score: int) -> void:
	_best_score = score
	var config := ConfigFile.new()
	config.load("user://save.cfg")  # Load existing to avoid overwriting other keys
	config.set_value("score", "best", score)
	config.save("user://save.cfg")


func _on_game_started() -> void:
	pass  # Score already reset on game_restarted


func _on_game_restarted() -> void:
	current_score = 0
	current_distance = 0.0
	coins_collected = 0
	run_duration_seconds = 0.0
	current_multiplier = 1.0
	_score_emit_cooldown = 0.0


func _on_external_coin_signal(_amount: int, _total: int) -> void:
	pass  # ScoreManager is the source of coin signals, not a listener
