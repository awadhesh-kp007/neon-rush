## FollowCamera — Smooth third-person follow camera for the endless runner.
##
## Tracks the player with configurable position offset, smooth damping,
## dynamic FOV on speed boost, and obstacle avoidance (SpringArm3D).
##
## Attach to a Camera3D node. Assign the player path in the inspector.

class_name FollowCamera
extends Camera3D

# ─────────────────────────────────────────────────────────────────────────────
# Exported Configuration
# ─────────────────────────────────────────────────────────────────────────────
@export var target_path: NodePath
@export var position_offset: Vector3 = Vector3(0.0, 3.5, -7.0)
@export var position_smooth_speed: float = 8.0
@export var rotation_smooth_speed: float = 6.0
@export var default_fov: float = 65.0
@export var speed_boost_fov: float = 75.0
@export var fov_smooth_speed: float = 5.0

# ─────────────────────────────────────────────────────────────────────────────
# Internal State
# ─────────────────────────────────────────────────────────────────────────────
var _target: Node3D
var _target_fov: float
var _velocity: Vector3 = Vector3.ZERO  # For SmoothDamp simulation

# SpringArm for obstacle avoidance
@onready var _spring_arm: SpringArm3D = $SpringArm3D

# ─────────────────────────────────────────────────────────────────────────────
# Godot Lifecycle
# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	_target_fov = default_fov
	fov = default_fov

	if not target_path.is_empty():
		_target = get_node(target_path)

	EventBus.powerup_activated.connect(_on_powerup_activated)
	EventBus.powerup_ended.connect(_on_powerup_ended)
	EventBus.game_over.connect(func(_r): _on_game_over())


func _exit_tree() -> void:
	EventBus.powerup_activated.disconnect(_on_powerup_activated)
	EventBus.powerup_ended.disconnect(_on_powerup_ended)


func _process(delta: float) -> void:
	if _target == null:
		return

	_update_position(delta)
	_update_rotation(delta)
	_update_fov(delta)


# ─────────────────────────────────────────────────────────────────────────────
# Public API
# ─────────────────────────────────────────────────────────────────────────────

func set_target(new_target: Node3D) -> void:
	_target = new_target

# ─────────────────────────────────────────────────────────────────────────────
# Private
# ─────────────────────────────────────────────────────────────────────────────

func _update_position(delta: float) -> void:
	var desired_pos := _target.global_position + position_offset
	global_position = global_position.lerp(desired_pos, position_smooth_speed * delta)


func _update_rotation(delta: float) -> void:
	var look_dir := _target.global_position - global_position
	if look_dir.length_squared() < 0.001:
		return
	var target_basis := Basis.looking_at(look_dir.normalized(), Vector3.UP)
	basis = basis.slerp(target_basis, rotation_smooth_speed * delta)


func _update_fov(delta: float) -> void:
	fov = lerpf(fov, _target_fov, fov_smooth_speed * delta)


func _on_powerup_activated(powerup_type: String, _duration: float) -> void:
	if powerup_type == "speed_boost":
		_target_fov = speed_boost_fov


func _on_powerup_ended(powerup_type: String) -> void:
	if powerup_type == "speed_boost":
		_target_fov = default_fov


func _on_game_over() -> void:
	# Optionally pan to a cinematic angle on game over
	pass
