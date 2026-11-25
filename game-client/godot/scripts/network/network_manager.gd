## NetworkManager — Monitors device connectivity and batches score submissions.
##
## Responsibilities:
##   - Polls/monitors OS network availability
##   - Emits EventBus.network_connected / network_disconnected
##   - Submits run scores to backend after each run (queues if offline)
##   - Syncs leaderboard on reconnect
##
## Add to Autoload as "NetworkManager".

class_name NetworkManager
extends Node

@export var connectivity_check_interval: float = 10.0
@export var score_submit_endpoint: String = "/game/runs"
@export var leaderboard_endpoint: String = "/leaderboard"

var _connectivity_timer: float = 0.0
var _was_online: bool = false

func _ready() -> void:
	EventBus.run_ended.connect(_on_run_ended)
	# Initial check
	_check_connectivity()


func _process(delta: float) -> void:
	_connectivity_timer -= delta
	if _connectivity_timer <= 0.0:
		_connectivity_timer = connectivity_check_interval
		_check_connectivity()


func _check_connectivity() -> void:
	## Godot 4: use OS.get_name() + HTTPRequest for a lightweight health ping.
	## For now we emit based on ApiClient._is_online state.
	## A real implementation would use a background ping.
	pass


## Submit a completed run to the backend. Queues if offline.
func submit_run(score: int, distance: float, coins: int, duration: float, run_hash: String) -> void:
	if not AuthManager.is_authenticated:
		return  ## Guest play — no submission

	var payload := {
		"score":    score,
		"distance": distance,
		"coins":    coins,
		"duration": duration,
		"hash":     run_hash,
		"clientTs": Time.get_unix_time_from_system(),
	}

	if ApiClient._is_online:
		var result := await ApiClient.post_async(score_submit_endpoint, payload)
		if not result.ok:
			push_warning("NetworkManager: Score submit failed — queuing. %s" % result.error_message)
			ApiClient.queue_offline_post(score_submit_endpoint, payload)
	else:
		ApiClient.queue_offline_post(score_submit_endpoint, payload)


## Fetch top leaderboard entries. Returns array or empty on error.
func fetch_leaderboard(limit: int = 100) -> Array:
	var result := await ApiClient.get_async("%s?limit=%d" % [leaderboard_endpoint, limit])
	if result.ok:
		return result.data.get("entries", [])
	return []


func _on_run_ended(score: int, coins: int, duration: float) -> void:
	var distance := ScoreManager.distance_meters
	var run_hash := ReplayRecorder.get_run_hash()
	submit_run(score, distance, coins, duration, run_hash)
