## ReplayRecorder — Records lightweight run events for server-side anti-cheat validation.
##
## Responsibilities:
##   - Records timestamped snapshots: position, speed, lane, score, coin events
##   - Generates a compact HMAC-based hash of the run for backend verification
##   - Does NOT store full replay data (privacy + bandwidth) — only event digest
##   - Snapshots at fixed intervals (every 500ms of game time)
##
## Add to Autoload as "ReplayRecorder".

class_name ReplayRecorder
extends Node

const SNAPSHOT_INTERVAL := 0.5   ## seconds between snapshots
const MAX_EVENTS := 500          ## cap per run

## Minimal snapshot record (kept small for performance)
class RunEvent:
	var ts: float    ## game time
	var score: int
	var speed: float
	var lane: int
	var coins: int

var _events: Array[RunEvent] = []
var _snapshot_timer: float = 0.0
var _is_recording: bool = false
var _run_hash: String = ""
var _hmac_key: String = "neon_rush_local_key_v1"  ## Rotated server-side; placeholder here

func _ready() -> void:
	EventBus.game_state_changed.connect(_on_game_state_changed)
	EventBus.run_ended.connect(_on_run_ended)


func _process(delta: float) -> void:
	if not _is_recording:
		return
	_snapshot_timer -= delta
	if _snapshot_timer <= 0.0:
		_snapshot_timer = SNAPSHOT_INTERVAL
		_take_snapshot()


func _take_snapshot() -> void:
	if _events.size() >= MAX_EVENTS:
		return
	var e := RunEvent.new()
	e.ts    = Time.get_ticks_msec() / 1000.0
	e.score = ScoreManager.score
	e.speed = DifficultyManager.current_speed
	e.lane  = 1  ## TODO: wire RunnerController.current_lane via EventBus
	e.coins = ScoreManager.total_coins_collected
	_events.append(e)


## Returns HMAC digest of the recorded run data for anti-cheat.
func get_run_hash() -> String:
	return _run_hash


func _compute_hash() -> String:
	## Build a canonical string from all events and HMAC it.
	var parts: PackedStringArray = []
	for e in _events:
		parts.append("%.2f:%d:%.1f:%d:%d" % [e.ts, e.score, e.speed, e.lane, e.coins])
	var payload := "|".join(parts)
	## GDScript has no native HMAC — use a simple SHA-256 digest of key+payload.
	## In production: replace with a Godot plugin or server-generated nonce.
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update((_hmac_key + payload).to_utf8_buffer())
	return ctx.finish().hex_encode()


func _on_game_state_changed(new_state: int) -> void:
	match new_state:
		GameManager.GameState.RUNNING:
			_events.clear()
			_run_hash = ""
			_is_recording = true
			_snapshot_timer = SNAPSHOT_INTERVAL
		GameManager.GameState.GAME_OVER:
			_is_recording = false
		GameManager.GameState.MAIN_MENU:
			_is_recording = false
			_events.clear()
		_:
			pass


func _on_run_ended(_score: int, _coins: int, _duration: float) -> void:
	_is_recording = false
	_run_hash = _compute_hash()
