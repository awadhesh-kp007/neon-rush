## SwipeInputController — Touch gesture recognizer for NEON RUSH.
##
## Detects swipe direction and double-tap from screen touch events,
## then calls the RunnerController's public API methods.
##
## All gesture thresholds are exported for designer tuning.
## Also supports keyboard input in the editor for rapid iteration.
##
## Attach to the Player node (sibling of RunnerController).

class_name SwipeInputController
extends Node

# ─────────────────────────────────────────────────────────────────────────────
# Exported Configuration
# ─────────────────────────────────────────────────────────────────────────────
@export_group("Swipe")
@export var min_swipe_distance: float = 50.0
@export var max_swipe_duration: float = 0.5
@export var directionality_ratio: float = 1.5

@export_group("Tap")
@export var double_tap_window: float = 0.3
@export var tap_max_movement: float = 15.0

# ─────────────────────────────────────────────────────────────────────────────
# State
# ─────────────────────────────────────────────────────────────────────────────
var _runner: RunnerController
var _input_enabled: bool = false

var _touch_start_pos: Vector2 = Vector2.ZERO
var _touch_start_time: float = 0.0
var _is_touching: bool = false
var _last_tap_time: float = -1.0

# ─────────────────────────────────────────────────────────────────────────────
# Godot Lifecycle
# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	_runner = get_parent() as RunnerController
	assert(_runner != null, "SwipeInputController must be a child of RunnerController")

	EventBus.game_started.connect(func(): _input_enabled = true)
	EventBus.game_paused.connect(func(): _input_enabled = false)
	EventBus.game_resumed.connect(func(): _input_enabled = true)
	EventBus.game_over.connect(func(_r): _input_enabled = false)
	EventBus.game_restarted.connect(func(): _input_enabled = false)


func _exit_tree() -> void:
	# Signals connected with lambdas are auto-disconnected when node exits tree.
	pass


func _input(event: InputEvent) -> void:
	if not _input_enabled:
		return

	# ── Touch Input (device) ──────────────────────────────────────────────────
	if event is InputEventScreenTouch:
		_handle_touch(event)
		return

	if event is InputEventScreenDrag:
		# We use Touch Begin/End only for swipe detection
		return

	# ── Keyboard Fallback (editor / desktop testing) ──────────────────────────
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_LEFT:  _runner.request_lane_left()
			KEY_RIGHT: _runner.request_lane_right()
			KEY_UP:    _runner.request_jump()
			KEY_DOWN:  _runner.request_slide()
			KEY_SPACE: _runner.request_jump()

# ─────────────────────────────────────────────────────────────────────────────
# Touch Handling
# ─────────────────────────────────────────────────────────────────────────────

func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		# Touch began
		_touch_start_pos = event.position
		_touch_start_time = Time.get_ticks_msec() / 1000.0
		_is_touching = true
	else:
		# Touch released
		if not _is_touching:
			return
		_is_touching = false
		_evaluate_gesture(event.position)


func _evaluate_gesture(end_pos: Vector2) -> void:
	var delta := end_pos - _touch_start_pos
	var magnitude := delta.length()
	var duration := (Time.get_ticks_msec() / 1000.0) - _touch_start_time

	# Short movement = tap (check for double-tap)
	if magnitude < tap_max_movement:
		_handle_tap()
		return

	# Check swipe validity
	if magnitude < min_swipe_distance or duration > max_swipe_duration:
		return

	var abs_x := absf(delta.x)
	var abs_y := absf(delta.y)

	# Require dominant axis to avoid diagonal ambiguity
	if abs_x > abs_y and (abs_x / maxf(abs_y, 0.001)) >= directionality_ratio:
		# Horizontal swipe
		if delta.x > 0.0:
			_runner.request_lane_right()
		else:
			_runner.request_lane_left()

	elif abs_y > abs_x and (abs_y / maxf(abs_x, 0.001)) >= directionality_ratio:
		# Vertical swipe
		if delta.y < 0.0:  # Godot screen Y: up = negative
			_runner.request_jump()
		else:
			_runner.request_slide()


func _handle_tap() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if _last_tap_time > 0.0 and (now - _last_tap_time) <= double_tap_window:
		# Double-tap → activate hoverboard
		_last_tap_time = -1.0
		EventBus.powerup_collected.emit("hoverboard")
	else:
		_last_tap_time = now
