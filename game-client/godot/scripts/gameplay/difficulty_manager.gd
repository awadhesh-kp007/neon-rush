## DifficultyManager — Controls run speed and obstacle density over time.
##
## Speed increases as the player runs further. Obstacle difficulty tiers
## are unlocked progressively. All values are configurable via a Resource.
##
## Register as an Autoload singleton named "DifficultyManager".

extends Node

# ─────────────────────────────────────────────────────────────────────────────
# Exported
# ─────────────────────────────────────────────────────────────────────────────
@export var initial_speed: float = 10.0
@export var max_speed: float = 35.0
## Speed gained per 100 meters of distance.
@export var speed_per_hundred_meters: float = 1.0
## Obstacle difficulty tier unlocks at these distances (meters).
@export var difficulty_thresholds: Array[float] = [0.0, 500.0, 1500.0, 3000.0]

# ─────────────────────────────────────────────────────────────────────────────
# State
# ─────────────────────────────────────────────────────────────────────────────
var current_speed: float = 10.0
var current_difficulty_tier: int = 0  # 0=Easy, 1=Medium, 2=Hard, 3=Expert
var _runner: RunnerController

# ─────────────────────────────────────────────────────────────────────────────
# Godot Lifecycle
# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	current_speed = initial_speed
	EventBus.game_started.connect(_on_game_started)
	EventBus.game_restarted.connect(_on_game_restarted)
	EventBus.distance_changed.connect(_on_distance_updated)


func _exit_tree() -> void:
	EventBus.game_started.disconnect(_on_game_started)
	EventBus.game_restarted.disconnect(_on_game_restarted)
	EventBus.distance_changed.disconnect(_on_distance_updated)

# ─────────────────────────────────────────────────────────────────────────────
# Private
# ─────────────────────────────────────────────────────────────────────────────

func _on_game_started() -> void:
	_runner = get_tree().get_first_node_in_group("player") as RunnerController


func _on_game_restarted() -> void:
	current_speed = initial_speed
	current_difficulty_tier = 0
	_runner = null


func _on_distance_updated(distance_m: float) -> void:
	# Recalculate speed from distance
	current_speed = minf(
		initial_speed + (distance_m / 100.0) * speed_per_hundred_meters,
		max_speed
	)

	# Push speed to runner
	if _runner:
		_runner.run_speed = current_speed

	# Advance difficulty tier
	for i in range(difficulty_thresholds.size() - 1, -1, -1):
		if distance_m >= difficulty_thresholds[i]:
			if current_difficulty_tier != i:
				current_difficulty_tier = i
			break
