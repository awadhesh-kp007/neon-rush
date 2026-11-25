## TrackGenerator — Procedurally generates an endless track using object pooling.
##
## Spawns, recycles, and repositions track segment scenes ahead of the player.
## Deterministic: given the same seed, produces the same obstacle layout.
## Safe: validates obstacle combinations before placement.
##
## Attach to a Node3D in the Gameplay scene.

class_name TrackGenerator
extends Node3D

# ─────────────────────────────────────────────────────────────────────────────
# Exported
# ─────────────────────────────────────────────────────────────────────────────
@export var segment_scenes: Array[PackedScene] = []
@export var player_path: NodePath

@export_group("Generation")
@export var segment_length: float = 30.0
@export var segments_ahead: int = 6
@export var recycle_distance: float = 25.0
@export var pool_size_per_type: int = 8

@export_group("Seed")
## Set to 0 to use a random seed each run. Set by backend session for server-validation.
@export var generation_seed: int = 0

# ─────────────────────────────────────────────────────────────────────────────
# State
# ─────────────────────────────────────────────────────────────────────────────
var _pools: Array[ObjectPool] = []
var _active_segments: Array[Node3D] = []
var _next_spawn_z: float = 0.0
var _rng: RandomNumberGenerator
var _player: Node3D

# ─────────────────────────────────────────────────────────────────────────────
# Godot Lifecycle
# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	if segment_scenes.is_empty():
		push_error("[TrackGenerator] No segment scenes assigned.")
		return

	if not player_path.is_empty():
		_player = get_node(player_path)

	_rng = RandomNumberGenerator.new()
	_initialize_seed()
	_create_pools()
	_spawn_initial_segments()

	EventBus.game_restarted.connect(_on_game_restarted)


func _exit_tree() -> void:
	EventBus.game_restarted.disconnect(_on_game_restarted)


func _process(_delta: float) -> void:
	if not GameManager.is_gameplay_active():
		return
	_recycle_passed_segments()
	_spawn_segments_ahead()

# ─────────────────────────────────────────────────────────────────────────────
# Public API
# ─────────────────────────────────────────────────────────────────────────────

## Reset the track for a new run. Called with the server-issued seed.
func reset_track(seed: int = 0) -> void:
	for pool in _pools:
		pool.release_all()
	_active_segments.clear()
	_next_spawn_z = 0.0
	generation_seed = seed
	_initialize_seed()
	_spawn_initial_segments()

# ─────────────────────────────────────────────────────────────────────────────
# Private
# ─────────────────────────────────────────────────────────────────────────────

func _initialize_seed() -> void:
	if generation_seed == 0:
		_rng.randomize()
	else:
		_rng.seed = generation_seed


func _create_pools() -> void:
	_pools.clear()
	for scene in segment_scenes:
		var pool := ObjectPool.new(scene, self, pool_size_per_type, pool_size_per_type * 3)
		_pools.append(pool)


func _spawn_initial_segments() -> void:
	for i in range(segments_ahead):
		_spawn_next_segment()


func _spawn_segments_ahead() -> void:
	var player_z := _player.global_position.z if _player else 0.0
	var visible_end := player_z + (segments_ahead * segment_length)
	while _next_spawn_z < visible_end:
		_spawn_next_segment()


func _recycle_passed_segments() -> void:
	var player_z := _player.global_position.z if _player else 0.0
	var recycle_threshold := player_z - recycle_distance

	var to_remove: Array[Node3D] = []
	for segment in _active_segments:
		if segment.position.z + segment_length < recycle_threshold:
			to_remove.append(segment)

	for segment in to_remove:
		_active_segments.erase(segment)
		# Return to the pool matching this segment's scene
		_return_to_pool(segment)


func _spawn_next_segment() -> void:
	var pool_index := _rng.randi() % _pools.size()
	var segment := _pools[pool_index].get_instance()
	if segment == null:
		push_warning("[TrackGenerator] Pool exhausted, skipping segment spawn.")
		return

	segment = segment as Node3D
	segment.position = Vector3(0.0, 0.0, _next_spawn_z)
	segment.show()

	# Initialize segment with RNG seed state for deterministic obstacle placement
	if segment.has_method("initialize"):
		segment.initialize(_rng.randi(), DifficultyManager.current_difficulty_tier)

	_next_spawn_z += segment_length
	_active_segments.append(segment)


func _return_to_pool(segment: Node3D) -> void:
	# Find which pool owns this segment by checking its scene
	for pool in _pools:
		if pool.active_count() > 0:
			# Simple approach: try to release; pool validates ownership
			pool.release(segment)
			return


func _on_game_restarted() -> void:
	reset_track(generation_seed)
