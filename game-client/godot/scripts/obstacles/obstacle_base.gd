## ObstacleBase — Base class for all obstacle types.
## Each obstacle declares its collision bounds, required player action,
## and difficulty tier. Extend this for specific obstacle types.

class_name ObstacleBase
extends Node3D

# ─────────────────────────────────────────────────────────────────────────────
# Obstacle Metadata (set in each subclass or inspector)
# ─────────────────────────────────────────────────────────────────────────────
@export var obstacle_id: String = "unknown"
@export var required_action: String = "JUMP"  # JUMP, SLIDE, LANE_LEFT, LANE_RIGHT, TIMED_SWITCH
@export var difficulty_tier: int = 1           # 1=Easy, 2=Medium, 3=Hard
@export var is_moving: bool = false

# ─────────────────────────────────────────────────────────────────────────────
# Signals
# ─────────────────────────────────────────────────────────────────────────────
signal player_hit(obstacle: ObstacleBase)

# ─────────────────────────────────────────────────────────────────────────────
# Node References
# ─────────────────────────────────────────────────────────────────────────────
@onready var _collision_area: Area3D = $CollisionArea

# ─────────────────────────────────────────────────────────────────────────────
# Godot Lifecycle
# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	if _collision_area:
		_collision_area.body_entered.connect(_on_body_entered)

	add_to_group("obstacles")

# ─────────────────────────────────────────────────────────────────────────────
# Virtual Methods (override in subclasses)
# ─────────────────────────────────────────────────────────────────────────────

## Called by the pool when this obstacle is activated.
func on_pool_get(lane: int, _z_position: float) -> void:
	position.x = GameConstants.LANE_POSITIONS[lane]
	show()


## Called by the pool when this obstacle is returned.
func on_pool_release() -> void:
	hide()

# ─────────────────────────────────────────────────────────────────────────────
# Collision
# ─────────────────────────────────────────────────────────────────────────────

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_hit.emit(self)
		var runner := body as RunnerController
		if runner:
			runner.on_obstacle_hit(obstacle_id)
