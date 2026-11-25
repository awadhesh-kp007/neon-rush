## RunnerController — Controls the player character's 3-lane movement.
##
## Responsibilities:
##   - Three-lane lateral movement with smooth lerp transitions
##   - Physics-based jump (CharacterBody3D + gravity override)
##   - Timed slide
##   - Ground detection
##   - Forward run speed (driven by DifficultyManager)
##   - Collision handling (delegates to PlayerCollision)
##   - Communicates exclusively through EventBus (no direct references)
##
## Attach to the Player CharacterBody3D root node.

class_name RunnerController
extends CharacterBody3D

# ─────────────────────────────────────────────────────────────────────────────
# Exported (Designer-Tunable)
# ─────────────────────────────────────────────────────────────────────────────
@export_group("Lanes")
@export var lane_positions: Array[float] = [-2.0, 0.0, 2.0]
@export var lane_switch_speed: float = 10.0

@export_group("Jump")
@export var jump_force: float = 12.0
@export var gravity_multiplier: float = 2.5

@export_group("Slide")
@export var slide_duration: float = 0.8

@export_group("Speed")
@export var initial_run_speed: float = 10.0

# ─────────────────────────────────────────────────────────────────────────────
# State
# ─────────────────────────────────────────────────────────────────────────────
enum RunnerState { IDLE, RUNNING, JUMPING, SLIDING, DEAD }

var runner_state: RunnerState = RunnerState.IDLE
var current_lane: int = GameConstants.LANE_CENTER
var run_speed: float = 0.0  # Set each frame by DifficultyManager via EventBus

var _target_x: float = 0.0
var _vertical_velocity: float = 0.0
var _slide_timer: float = 0.0
var _last_lane_switch_time: float = 0.0
var _is_grounded: bool = false
var _hoverboard_active: bool = false
var _jump_buffered: bool = false

# Cache
@onready var _collision_handler: Node = $PlayerCollision
@onready var _animator: Node = $PlayerAnimator

# ─────────────────────────────────────────────────────────────────────────────
# Godot Lifecycle
# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	_target_x = lane_positions[current_lane]
	run_speed = initial_run_speed

	# Subscribe to EventBus
	EventBus.game_started.connect(_on_game_started)
	EventBus.game_restarted.connect(_on_game_restarted)
	EventBus.game_paused.connect(_on_game_paused)
	EventBus.game_resumed.connect(_on_game_resumed)
	EventBus.powerup_activated.connect(_on_powerup_activated)
	EventBus.powerup_ended.connect(_on_powerup_ended)


func _exit_tree() -> void:
	# Always disconnect to avoid dangling connections
	EventBus.game_started.disconnect(_on_game_started)
	EventBus.game_restarted.disconnect(_on_game_restarted)
	EventBus.game_paused.disconnect(_on_game_paused)
	EventBus.game_resumed.disconnect(_on_game_resumed)
	EventBus.powerup_activated.disconnect(_on_powerup_activated)
	EventBus.powerup_ended.disconnect(_on_powerup_ended)


func _physics_process(delta: float) -> void:
	if not GameManager.is_gameplay_active():
		return

	_update_ground_state()
	_process_jump_buffer()
	_apply_gravity(delta)
	_apply_lateral_movement(delta)
	_process_slide_timer(delta)
	_apply_forward_movement(delta)

	move_and_slide()

# ─────────────────────────────────────────────────────────────────────────────
# Public API (called by SwipeInputController)
# ─────────────────────────────────────────────────────────────────────────────

## Request a lane change to the left. Ignored at left boundary or on cooldown.
func request_lane_left() -> void:
	if runner_state == RunnerState.DEAD:
		return
	if current_lane <= 0:
		return
	if not _can_switch_lane():
		return

	var from_lane := current_lane
	current_lane -= 1
	_target_x = lane_positions[current_lane]
	_last_lane_switch_time = Time.get_ticks_msec() / 1000.0
	EventBus.player_lane_changed.emit(from_lane, current_lane)


## Request a lane change to the right. Ignored at right boundary or on cooldown.
func request_lane_right() -> void:
	if runner_state == RunnerState.DEAD:
		return
	if current_lane >= lane_positions.size() - 1:
		return
	if not _can_switch_lane():
		return

	var from_lane := current_lane
	current_lane += 1
	_target_x = lane_positions[current_lane]
	_last_lane_switch_time = Time.get_ticks_msec() / 1000.0
	EventBus.player_lane_changed.emit(from_lane, current_lane)


## Request a jump. Only valid when grounded or with buffering.
func request_jump() -> void:
	if runner_state == RunnerState.DEAD:
		return
	if runner_state == RunnerState.SLIDING:
		return  # Cannot jump while sliding

	if _is_grounded:
		_execute_jump()
	else:
		# Buffer the jump for 100ms — improves control feel
		_jump_buffered = true
		get_tree().create_timer(0.1).timeout.connect(func(): _jump_buffered = false)


## Request a slide. Valid while running or jumping.
func request_slide() -> void:
	if runner_state == RunnerState.DEAD:
		return
	if runner_state == RunnerState.SLIDING:
		return

	# In the air: fast-fall into slide
	if not _is_grounded:
		_vertical_velocity = minf(_vertical_velocity, -4.0)

	_slide_timer = slide_duration
	_set_state(RunnerState.SLIDING)
	EventBus.player_slide_started.emit()


## Activate or deactivate hoverboard shield.
func set_hoverboard_active(active: bool) -> void:
	_hoverboard_active = active


## Called by PlayerCollision when the player hits an obstacle.
func on_obstacle_hit(obstacle_name: String) -> void:
	if _hoverboard_active:
		_hoverboard_active = false
		EventBus.player_hoverboard_destroyed.emit()
		return

	if runner_state == RunnerState.DEAD:
		return

	_set_state(RunnerState.DEAD)
	GameManager.trigger_game_over(obstacle_name)

# ─────────────────────────────────────────────────────────────────────────────
# Physics Helpers
# ─────────────────────────────────────────────────────────────────────────────

func _update_ground_state() -> void:
	var was_grounded := _is_grounded
	_is_grounded = is_on_floor()

	if not was_grounded and _is_grounded:
		# Just landed
		if runner_state == RunnerState.JUMPING:
			_set_state(RunnerState.RUNNING)
		EventBus.player_landed.emit()


func _process_jump_buffer() -> void:
	if _jump_buffered and _is_grounded:
		_jump_buffered = false
		_execute_jump()


func _apply_gravity(delta: float) -> void:
	if _is_grounded and _vertical_velocity < 0.0:
		_vertical_velocity = -0.5  # Small constant keeps CharacterBody3D grounded
	else:
		_vertical_velocity -= ProjectSettings.get_setting("physics/3d/default_gravity") \
			* gravity_multiplier * delta


func _apply_lateral_movement(delta: float) -> void:
	var current_x := position.x
	var smooth_x := lerpf(current_x, _target_x, lane_switch_speed * delta)
	velocity.x = (smooth_x - current_x) / delta


func _apply_forward_movement(delta: float) -> void:
	velocity.z = run_speed  # Positive Z is forward in this project
	velocity.y = _vertical_velocity


func _process_slide_timer(delta: float) -> void:
	if runner_state != RunnerState.SLIDING:
		return
	_slide_timer -= delta
	if _slide_timer <= 0.0:
		_set_state(RunnerState.RUNNING)
		EventBus.player_slide_ended.emit()


func _execute_jump() -> void:
	_vertical_velocity = jump_force
	_set_state(RunnerState.JUMPING)
	EventBus.player_jumped.emit()


func _can_switch_lane() -> bool:
	var now := Time.get_ticks_msec() / 1000.0
	return (now - _last_lane_switch_time) >= GameConstants.MIN_LANE_SWITCH_INTERVAL


func _set_state(new_state: RunnerState) -> void:
	runner_state = new_state

# ─────────────────────────────────────────────────────────────────────────────
# Event Handlers
# ─────────────────────────────────────────────────────────────────────────────

func _on_game_started() -> void:
	_set_state(RunnerState.RUNNING)
	run_speed = initial_run_speed


func _on_game_restarted() -> void:
	current_lane = GameConstants.LANE_CENTER
	_target_x = lane_positions[current_lane]
	position = Vector3(_target_x, position.y, 0.0)
	_vertical_velocity = 0.0
	_slide_timer = 0.0
	_hoverboard_active = false
	run_speed = initial_run_speed
	_set_state(RunnerState.IDLE)


func _on_game_paused() -> void:
	set_physics_process(false)


func _on_game_resumed() -> void:
	set_physics_process(true)


func _on_powerup_activated(powerup_type: String, _duration: float) -> void:
	if powerup_type == "hoverboard":
		_hoverboard_active = true


func _on_powerup_ended(powerup_type: String) -> void:
	if powerup_type == "hoverboard":
		_hoverboard_active = false
