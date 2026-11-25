## AnalyticsManager — Lightweight client-side analytics event collector.
##
## Responsibilities:
##   - Collects structured game events (run_start, run_end, powerup_use, etc.)
##   - Batches events and sends to backend /analytics endpoint
##   - Respects player privacy — no PII collected; session-scoped IDs only
##   - Falls back gracefully if backend is unavailable
##
## Add to Autoload as "AnalyticsManager".

class_name AnalyticsManager
extends Node

const ANALYTICS_ENDPOINT := "/analytics/events"
const BATCH_SIZE := 20
const FLUSH_INTERVAL := 30.0   ## seconds

var _session_id: String = ""
var _event_queue: Array[Dictionary] = []
var _flush_timer: float = 0.0

func _ready() -> void:
	_session_id = _generate_session_id()
	_connect_events()


func _process(delta: float) -> void:
	_flush_timer -= delta
	if _flush_timer <= 0.0:
		_flush_timer = FLUSH_INTERVAL
		_flush()


## Record a named event with optional properties.
func track(event_name: String, props: Dictionary = {}) -> void:
	var event := {
		"event":      event_name,
		"session_id": _session_id,
		"ts":         Time.get_unix_time_from_system(),
		"props":      props,
	}
	_event_queue.append(event)
	if _event_queue.size() >= BATCH_SIZE:
		_flush()


func _flush() -> void:
	if _event_queue.is_empty():
		return
	var batch := _event_queue.duplicate()
	_event_queue.clear()
	# Fire-and-forget; don't re-queue failed analytics
	ApiClient.post_async(ANALYTICS_ENDPOINT, {"events": batch})


func _connect_events() -> void:
	EventBus.run_started.connect(func(): track("run_start"))
	EventBus.run_ended.connect(func(score, coins, duration):
		track("run_end", {"score": score, "coins": coins, "duration": duration})
	)
	EventBus.powerup_activated.connect(func(t): track("powerup_use", {"type": t}))
	EventBus.player_died.connect(func(_p): track("player_died"))
	EventBus.player_logged_in.connect(func(pid, _u): track("login", {"player_id": pid}))
	EventBus.character_selected.connect(func(cid): track("character_select", {"character": cid}))


func _generate_session_id() -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return "%x%x" % [rng.randi(), rng.randi()]
