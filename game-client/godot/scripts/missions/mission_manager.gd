## MissionManager — Tracks daily missions and long-term achievements.
##
## Responsibilities:
##   - Loads mission definitions from a JSON data file
##   - Tracks per-mission progress via EventBus (coins, distance, runs, deaths)
##   - Persists progress to ConfigFile
##   - Emits mission_completed when target reached
##   - Resets daily missions at UTC midnight

class_name MissionManager
extends Node

const SAVE_PATH    := "user://missions.cfg"
const SECTION      := "missions"
const MISSIONS_DATA_PATH := "res://resources/data/missions.json"

## Max concurrent active daily missions displayed to the player.
const MAX_DAILY_MISSIONS := 3

signal mission_completed(mission_id: String, reward_coins: int)

# ─────────────────────────────────────────────────────────────────────────────
# State
# ─────────────────────────────────────────────────────────────────────────────

var _missions: Array[Dictionary] = []  ## All mission definitions
var _progress: Dictionary = {}         ## mission_id -> current_value
var _completed: Dictionary = {}        ## mission_id -> bool
var _daily_ids: Array[String] = []     ## Currently active daily mission IDs
var _last_reset_date: String = ""
var _config := ConfigFile.new()

# ─────────────────────────────────────────────────────────────────────────────
# Lifecycle
# ─────────────────────────────────────────────────────────────────────────────

func _ready() -> void:
	_load_definitions()
	_load_progress()
	_check_daily_reset()
	_connect_events()


func _connect_events() -> void:
	EventBus.coin_collected.connect(_on_coin_collected)
	EventBus.run_ended.connect(_on_run_ended)
	EventBus.player_died.connect(_on_player_died)
	EventBus.distance_updated.connect(_on_distance_updated)

# ─────────────────────────────────────────────────────────────────────────────
# Public API
# ─────────────────────────────────────────────────────────────────────────────

## Returns current active daily missions with progress info.
func get_active_missions() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for mission_id in _daily_ids:
		var m := _find_by_id(mission_id)
		if m.is_empty():
			continue
		var copy := m.duplicate()
		copy["progress"] = _progress.get(mission_id, 0)
		copy["completed"] = _completed.get(mission_id, false)
		result.append(copy)
	return result


## Force claim reward for a completed mission.
func claim_mission(mission_id: String) -> bool:
	if not _completed.get(mission_id, false):
		return false
	var m := _find_by_id(mission_id)
	if m.is_empty():
		return false
	var reward: int = m.get("reward_coins", 100)
	CoinManager.earn(reward)
	emit_signal("mission_completed", mission_id, reward)
	EventBus.mission_completed.emit(mission_id)
	# Replace with a new mission
	_replace_mission(mission_id)
	_save()
	return true

# ─────────────────────────────────────────────────────────────────────────────
# Progress Tracking
# ─────────────────────────────────────────────────────────────────────────────

func _increment_mission_progress(mission_type: String, amount: int) -> void:
	for mission_id in _daily_ids:
		var m := _find_by_id(mission_id)
		if m.is_empty() or _completed.get(mission_id, false):
			continue
		if m.get("type") != mission_type:
			continue
		var current: int = _progress.get(mission_id, 0)
		var target: int = m.get("target", 1)
		_progress[mission_id] = mini(current + amount, target)
		if _progress[mission_id] >= target:
			_completed[mission_id] = true
			EventBus.mission_progress_updated.emit(mission_id, _progress[mission_id], target, true)
		else:
			EventBus.mission_progress_updated.emit(mission_id, _progress[mission_id], target, false)
	_save()

# ─────────────────────────────────────────────────────────────────────────────
# Event Handlers
# ─────────────────────────────────────────────────────────────────────────────

func _on_coin_collected(value: int) -> void:
	_increment_mission_progress("collect_coins", value)


func _on_run_ended(score: int, _coins: int, _duration: float) -> void:
	_increment_mission_progress("complete_runs", 1)
	if score >= 10000:
		_increment_mission_progress("score_10k", 1)


func _on_player_died(_position: Vector3) -> void:
	pass  ## Hook for future "survive X runs" missions


func _on_distance_updated(meters: float) -> void:
	_increment_mission_progress("run_distance", int(meters))

# ─────────────────────────────────────────────────────────────────────────────
# Daily Reset Logic
# ─────────────────────────────────────────────────────────────────────────────

func _check_daily_reset() -> void:
	var today := Time.get_date_string_from_system()
	if today != _last_reset_date:
		_last_reset_date = today
		_roll_daily_missions()
		_save()


func _roll_daily_missions() -> void:
	## Pick MAX_DAILY_MISSIONS random uncompleted missions.
	var pool := _missions.filter(func(m): return not _completed.get(m["id"], false))
	pool.shuffle()
	_daily_ids.clear()
	for i in mini(MAX_DAILY_MISSIONS, pool.size()):
		_daily_ids.append(pool[i]["id"])
		if not _progress.has(pool[i]["id"]):
			_progress[pool[i]["id"]] = 0


func _replace_mission(completed_id: String) -> void:
	_daily_ids.erase(completed_id)
	var pool := _missions.filter(func(m):
		return not _completed.get(m["id"], false) and not _daily_ids.has(m["id"])
	)
	if not pool.is_empty():
		pool.shuffle()
		_daily_ids.append(pool[0]["id"])

# ─────────────────────────────────────────────────────────────────────────────
# Data Loading
# ─────────────────────────────────────────────────────────────────────────────

func _load_definitions() -> void:
	if not ResourceLoader.exists(MISSIONS_DATA_PATH):
		push_warning("MissionManager: missions.json not found — using built-in defaults.")
		_missions = _default_missions()
		return
	var file := FileAccess.open(MISSIONS_DATA_PATH, FileAccess.READ)
	if file:
		var json := JSON.new()
		var err := json.parse(file.get_as_text())
		file.close()
		if err == OK:
			_missions = json.data as Array[Dictionary]
		else:
			push_error("MissionManager: JSON parse error — using defaults.")
			_missions = _default_missions()


func _default_missions() -> Array[Dictionary]:
	return [
		{"id": "coins_100",    "type": "collect_coins",  "target": 100,  "reward_coins": 50,   "description": "Collect 100 coins"},
		{"id": "coins_500",    "type": "collect_coins",  "target": 500,  "reward_coins": 200,  "description": "Collect 500 coins"},
		{"id": "run_500m",     "type": "run_distance",   "target": 500,  "reward_coins": 75,   "description": "Run 500 meters"},
		{"id": "run_1km",      "type": "run_distance",   "target": 1000, "reward_coins": 150,  "description": "Run 1 kilometer"},
		{"id": "play_5_runs",  "type": "complete_runs",  "target": 5,    "reward_coins": 100,  "description": "Complete 5 runs"},
		{"id": "score_10k",    "type": "score_10k",      "target": 1,    "reward_coins": 300,  "description": "Score 10,000 in one run"},
	]


func _find_by_id(mission_id: String) -> Dictionary:
	for m in _missions:
		if m["id"] == mission_id:
			return m
	return {}

# ─────────────────────────────────────────────────────────────────────────────
# Persistence
# ─────────────────────────────────────────────────────────────────────────────

func _save() -> void:
	_config.set_value(SECTION, "progress", _progress)
	_config.set_value(SECTION, "completed", _completed)
	_config.set_value(SECTION, "daily_ids", _daily_ids)
	_config.set_value(SECTION, "last_reset", _last_reset_date)
	_config.save(SAVE_PATH)


func _load_progress() -> void:
	if _config.load(SAVE_PATH) == OK:
		_progress = _config.get_value(SECTION, "progress", {})
		_completed = _config.get_value(SECTION, "completed", {})
		_daily_ids = _config.get_value(SECTION, "daily_ids", [])
		_last_reset_date = _config.get_value(SECTION, "last_reset", "")
