## PlayerCollision — Fine-grained Area3D collision detection for the player.
##
## Responsibilities:
##   - Detects overlaps with Obstacles, Coins, and PowerUps via Area3D
##   - Applies one-frame immunity after hoverboard activation (crash immunity)
##   - Emits EventBus signals; never modifies game state directly
##   - Works alongside CharacterBody3D physics (not instead of it)
##
## Attach as a child of the Player CharacterBody3D.
## Expects child nodes: CollisionDetector (Area3D), BodyCollisionShape (CollisionShape3D)

class_name PlayerCollision
extends Node

# ─────────────────────────────────────────────────────────────────────────────
# Groups (all collidable objects must add themselves to these groups)
# ─────────────────────────────────────────────────────────────────────────────

const GROUP_OBSTACLE  := "obstacle"
const GROUP_COIN      := "coin"
const GROUP_POWERUP   := "powerup"
const GROUP_TRAIN     := "train"

# ─────────────────────────────────────────────────────────────────────────────
# Exported
# ─────────────────────────────────────────────────────────────────────────────

## Path to the Area3D used for overlap detection.
@export var detector_path: NodePath = NodePath("CollisionDetector")

## Duration (seconds) of invincibility after hoverboard activation or revive.
@export var invincibility_duration: float = 1.5

## Cooldown between consecutive coin collections (seconds) — prevents double-collect.
@export var coin_collect_cooldown: float = 0.05

# ─────────────────────────────────────────────────────────────────────────────
# State
# ─────────────────────────────────────────────────────────────────────────────

var _area: Area3D
var _is_dead: bool = false
var _is_invincible: bool = false
var _invincibility_timer: float = 0.0
var _coin_cooldown_timer: float = 0.0
var _hoverboard_active: bool = false

# ─────────────────────────────────────────────────────────────────────────────
# Lifecycle
# ─────────────────────────────────────────────────────────────────────────────

func _ready() -> void:
	_area = get_node_or_null(detector_path) as Area3D
	if not is_instance_valid(_area):
		push_error("PlayerCollision: Area3D not found at path '%s'. Check detector_path." % str(detector_path))
		return

	_area.body_entered.connect(_on_body_entered)
	_area.area_entered.connect(_on_area_entered)

	_connect_event_bus()


func _process(delta: float) -> void:
	if _invincibility_timer > 0.0:
		_invincibility_timer -= delta
		if _invincibility_timer <= 0.0:
			_is_invincible = false

	if _coin_cooldown_timer > 0.0:
		_coin_cooldown_timer -= delta


func _connect_event_bus() -> void:
	EventBus.player_died.connect(_on_player_died)
	EventBus.powerup_activated.connect(_on_powerup_activated)
	EventBus.powerup_deactivated.connect(_on_powerup_deactivated)
	EventBus.game_state_changed.connect(_on_game_state_changed)
	EventBus.player_revived.connect(_on_player_revived)

# ─────────────────────────────────────────────────────────────────────────────
# Public API
# ─────────────────────────────────────────────────────────────────────────────

## Grant temporary invincibility (e.g., during revive animation).
func grant_invincibility(duration: float = -1.0) -> void:
	_is_invincible = true
	_invincibility_timer = duration if duration > 0.0 else invincibility_duration


## Remove invincibility immediately.
func revoke_invincibility() -> void:
	_is_invincible = false
	_invincibility_timer = 0.0

# ─────────────────────────────────────────────────────────────────────────────
# Area/Body Overlap Handlers
# ─────────────────────────────────────────────────────────────────────────────

func _on_body_entered(body: Node3D) -> void:
	## Handles PhysicsBody3D entering our detector (e.g., train cars as RigidBody3D).
	if _is_dead or _is_invincible:
		return

	if body.is_in_group(GROUP_TRAIN) or body.is_in_group(GROUP_OBSTACLE):
		_handle_obstacle_hit(body)


func _on_area_entered(area: Area3D) -> void:
	## Handles Area3D overlaps (coins, power-ups, trigger obstacles).
	if _is_dead:
		return

	if area.is_in_group(GROUP_COIN):
		_handle_coin_collect(area)
		return

	if area.is_in_group(GROUP_POWERUP):
		_handle_powerup_collect(area)
		return

	if area.is_in_group(GROUP_OBSTACLE) and not _is_invincible:
		_handle_obstacle_hit(area)

# ─────────────────────────────────────────────────────────────────────────────
# Collision Logic
# ─────────────────────────────────────────────────────────────────────────────

func _handle_obstacle_hit(source: Node) -> void:
	## Obstacle hit: hoverboard absorbs first hit, otherwise → death.
	if _hoverboard_active:
		# Hoverboard crashes, grants brief invincibility
		EventBus.emit_signal("hoverboard_crashed")
		grant_invincibility(invincibility_duration)
		push_warning("PlayerCollision: Hoverboard absorbed crash from '%s'." % source.name)
		return

	var player_pos: Vector3 = get_parent().global_position
	_is_dead = true
	EventBus.player_died.emit(player_pos)


func _handle_coin_collect(coin: Node) -> void:
	## Coin collected: debounce to prevent duplicate signals.
	if _coin_cooldown_timer > 0.0:
		return
	_coin_cooldown_timer = coin_collect_cooldown

	# Read coin value from metadata (set by CoinSpawner)
	var value: int = 1
	if coin.has_meta("coin_value"):
		value = coin.get_meta("coin_value") as int

	EventBus.coin_collected.emit(value)
	coin.queue_free()


func _handle_powerup_collect(powerup_node: Node) -> void:
	## Power-up collected: read type from metadata and emit signal.
	var powerup_type: String = "unknown"
	if powerup_node.has_meta("powerup_type"):
		powerup_type = powerup_node.get_meta("powerup_type") as String

	EventBus.powerup_collected.emit(powerup_type)
	powerup_node.queue_free()

# ─────────────────────────────────────────────────────────────────────────────
# EventBus Handlers
# ─────────────────────────────────────────────────────────────────────────────

func _on_player_died(_position: Vector3) -> void:
	_is_dead = true


func _on_player_revived() -> void:
	_is_dead = false
	grant_invincibility(invincibility_duration)


func _on_powerup_activated(powerup_type: String) -> void:
	if powerup_type == "hoverboard":
		_hoverboard_active = true
		grant_invincibility(0.1)   ## Brief immunity on activation frame


func _on_powerup_deactivated(powerup_type: String) -> void:
	if powerup_type == "hoverboard":
		_hoverboard_active = false


func _on_game_state_changed(new_state: int) -> void:
	match new_state:
		GameManager.GameState.RUNNING:
			_is_dead = false
		GameManager.GameState.MAIN_MENU:
			_is_dead = false
			_is_invincible = false
			_hoverboard_active = false
		_:
			pass
