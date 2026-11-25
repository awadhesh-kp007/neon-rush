## ObstacleSpawner — Spawns and recycles obstacles within track segments.
##
## Responsibilities:
##   - Reads difficulty tier from DifficultyManager to select obstacle patterns
##   - Uses ObjectPool for zero-allocation spawning
##   - Places obstacles at correct lane positions and heights
##   - Despawns obstacles that have passed the player
##   - Tracks spawn density and respects minimum safe spacing
##
## This is an autoload node — add to Project > Autoload as "ObstacleSpawner".

class_name ObstacleSpawner
extends Node

# ─────────────────────────────────────────────────────────────────────────────
# Obstacle Pattern Definitions
# ─────────────────────────────────────────────────────────────────────────────

## Each pattern defines which lanes are blocked and the obstacle type.
## Lanes: 0 = left, 1 = center, 2 = right
## "type" matches obstacle_base.gd ObstacleType names.

const PATTERNS_BY_TIER: Array[Array] = [
	# Tier 0 (easiest) — single lane blockage
	[
		{"blocked_lanes": [1],      "type": "barrier",   "is_high": false},
		{"blocked_lanes": [0],      "type": "barrier",   "is_high": false},
		{"blocked_lanes": [2],      "type": "barrier",   "is_high": false},
		{"blocked_lanes": [1],      "type": "log",       "is_high": false},
	],
	# Tier 1 — two lane blockage (slide or jump required)
	[
		{"blocked_lanes": [0, 1],   "type": "barrier",   "is_high": false},
		{"blocked_lanes": [1, 2],   "type": "barrier",   "is_high": false},
		{"blocked_lanes": [0, 2],   "type": "barrier",   "is_high": false},
		{"blocked_lanes": [1],      "type": "overhead",  "is_high": true},
	],
	# Tier 2 — force jump + switch, or slide
	[
		{"blocked_lanes": [0, 1],   "type": "train",     "is_high": false},
		{"blocked_lanes": [1, 2],   "type": "train",     "is_high": false},
		{"blocked_lanes": [1],      "type": "overhead",  "is_high": true},
		{"blocked_lanes": [0],      "type": "overhead",  "is_high": true},
		{"blocked_lanes": [2],      "type": "overhead",  "is_high": true},
	],
	# Tier 3 (hardest) — complex combos
	[
		{"blocked_lanes": [0, 1],   "type": "train",     "is_high": false},
		{"blocked_lanes": [1, 2],   "type": "train",     "is_high": false},
		{"blocked_lanes": [0],      "type": "barrier",   "is_high": false},
		{"blocked_lanes": [2],      "type": "overhead",  "is_high": true},
		{"blocked_lanes": [1],      "type": "electric",  "is_high": false},
	],
]

# ─────────────────────────────────────────────────────────────────────────────
# Exported
# ─────────────────────────────────────────────────────────────────────────────

## Scene to use as obstacle template (should have ObstacleBase as root).
@export var obstacle_scene: PackedScene

## Minimum Z-distance (in world units) between consecutive obstacle groups.
@export var min_obstacle_spacing: float = 15.0

## Maximum number of obstacles active at once.
@export var pool_size: int = 24

## Z-coordinate behind player at which obstacles are recycled.
@export var despawn_z_offset: float = 10.0

# ─────────────────────────────────────────────────────────────────────────────
# State
# ─────────────────────────────────────────────────────────────────────────────

var _pool: ObjectPool
var _active_obstacles: Array[Node3D] = []
var _last_spawn_z: float = 0.0
var _player_ref: Node3D
var _is_active: bool = false
var _rng: RandomNumberGenerator

# ─────────────────────────────────────────────────────────────────────────────
# Lifecycle
# ─────────────────────────────────────────────────────────────────────────────

func _ready() -> void:
	_rng = RandomNumberGenerator.new()
	_rng.seed = GameConstants.WORLD_SEED

	if is_instance_valid(obstacle_scene):
		_pool = ObjectPool.new()
		_pool.initialize(obstacle_scene, pool_size, self)
	else:
		push_warning("ObstacleSpawner: obstacle_scene not assigned — spawner inactive.")

	EventBus.game_state_changed.connect(_on_game_state_changed)
	EventBus.player_died.connect(_on_player_died)


func _process(delta: float) -> void:
	if not _is_active or not is_instance_valid(_player_ref):
		return
	_despawn_passed_obstacles()
	_try_spawn_obstacle_group()


# ─────────────────────────────────────────────────────────────────────────────
# Public API
# ─────────────────────────────────────────────────────────────────────────────

## Called by GameplayScene to register the player reference.
func register_player(player: Node3D) -> void:
	_player_ref = player


## Resets spawner state for a new run.
func reset(seed_override: int = -1) -> void:
	_active_obstacles.clear()
	if _pool:
		_pool.release_all()
	_last_spawn_z = -20.0  ## Start spawning 20 units ahead of origin
	if seed_override >= 0:
		_rng.seed = seed_override
	else:
		_rng.randomize()

# ─────────────────────────────────────────────────────────────────────────────
# Spawning Logic
# ─────────────────────────────────────────────────────────────────────────────

func _try_spawn_obstacle_group() -> void:
	if not is_instance_valid(_pool):
		return

	var ahead_z: float = _player_ref.global_position.z - GameConstants.TRACK_SEGMENT_LENGTH
	if _last_spawn_z > ahead_z:
		return  ## Not far enough ahead yet

	var pattern := _pick_pattern()
	_spawn_pattern(pattern, _last_spawn_z - min_obstacle_spacing)
	_last_spawn_z -= min_obstacle_spacing


func _pick_pattern() -> Dictionary:
	var tier: int = DifficultyManager.get_obstacle_tier()
	tier = clampi(tier, 0, PATTERNS_BY_TIER.size() - 1)
	var tier_patterns: Array = PATTERNS_BY_TIER[tier]
	var idx: int = _rng.randi() % tier_patterns.size()
	return tier_patterns[idx]


func _spawn_pattern(pattern: Dictionary, spawn_z: float) -> void:
	var blocked_lanes: Array = pattern.get("blocked_lanes", [1])
	var obs_type: String = pattern.get("type", "barrier")
	var is_high: bool = pattern.get("is_high", false)

	for lane_idx in blocked_lanes:
		var obstacle: Node3D = _pool.get_instance() as Node3D
		if not is_instance_valid(obstacle):
			push_warning("ObstacleSpawner: Pool exhausted — could not spawn obstacle.")
			return

		var lane_x: float = GameConstants.LANE_POSITIONS[lane_idx]
		var spawn_y: float = GameConstants.OBSTACLE_GROUND_Y

		obstacle.global_position = Vector3(lane_x, spawn_y, spawn_z)

		# Configure via ObstacleBase API if script is attached
		if obstacle.has_method("configure"):
			obstacle.configure(obs_type, is_high, lane_idx)

		# Set metadata for collision handler
		obstacle.set_meta("obstacle_type", obs_type)
		obstacle.set_meta("lane", lane_idx)
		obstacle.set_meta("is_high", is_high)

		obstacle.add_to_group(PlayerCollision.GROUP_OBSTACLE)
		_active_obstacles.append(obstacle)

# ─────────────────────────────────────────────────────────────────────────────
# Despawn Logic
# ─────────────────────────────────────────────────────────────────────────────

func _despawn_passed_obstacles() -> void:
	var player_z: float = _player_ref.global_position.z
	var recycle_threshold: float = player_z + despawn_z_offset

	# Iterate in reverse to allow safe removal
	for i in range(_active_obstacles.size() - 1, -1, -1):
		var obs: Node3D = _active_obstacles[i]
		if not is_instance_valid(obs):
			_active_obstacles.remove_at(i)
			continue
		if obs.global_position.z > recycle_threshold:
			_pool.release(obs)
			_active_obstacles.remove_at(i)

# ─────────────────────────────────────────────────────────────────────────────
# Event Bus Handlers
# ─────────────────────────────────────────────────────────────────────────────

func _on_game_state_changed(new_state: int) -> void:
	match new_state:
		GameManager.GameState.RUNNING:
			_is_active = true
		GameManager.GameState.PAUSED:
			_is_active = false
		GameManager.GameState.GAME_OVER, GameManager.GameState.MAIN_MENU:
			_is_active = false
			reset()
		_:
			pass


func _on_player_died(_position: Vector3) -> void:
	_is_active = false
