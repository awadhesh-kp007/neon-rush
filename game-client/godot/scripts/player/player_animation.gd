## PlayerAnimation — Bridges RunnerController state to AnimationTree/AnimationPlayer.
##
## Responsibilities:
##   - Drives an AnimationTree (state machine) or falls back to AnimationPlayer directly
##   - Reacts to RunnerController state changes via EventBus signals
##   - Exposes a simple API: play_state(name) used by RunnerController
##   - Handles blend times, speed scale, and transition guards
##
## Attach to the same CharacterBody3D as RunnerController, or a child AnimationPlayer node.
##
## AnimationTree Layout (expected):
##   Root → StateMachine → states: idle, run, jump, slide, dead, revive
##   Parameters: conditions/triggers for each transition

class_name PlayerAnimation
extends Node

# ─────────────────────────────────────────────────────────────────────────────
# Node References
# ─────────────────────────────────────────────────────────────────────────────

## Path to the AnimationTree node (preferred).
@export var animation_tree_path: NodePath = NodePath("../AnimationTree")

## Path to the AnimationPlayer node (fallback if no AnimationTree).
@export var animation_player_path: NodePath = NodePath("../AnimationPlayer")

## Speed scale applied to all running animations.
@export var run_speed_scale_min: float = 1.0

## Speed scale at maximum game speed.
@export var run_speed_scale_max: float = 1.8

# ─────────────────────────────────────────────────────────────────────────────
# Animation State Names
# ─────────────────────────────────────────────────────────────────────────────

const ANIM_IDLE    := "idle"
const ANIM_RUN     := "run"
const ANIM_JUMP    := "jump"
const ANIM_SLIDE   := "slide"
const ANIM_DEAD    := "dead"
const ANIM_REVIVE  := "revive"
const ANIM_DASH    := "dash"      ## Used when hoverboard is active

# AnimationTree parameter paths (StateMachine)
const PARAM_STATE  := "parameters/playback"

# ─────────────────────────────────────────────────────────────────────────────
# Internal State
# ─────────────────────────────────────────────────────────────────────────────

var _animation_tree: AnimationTree
var _animation_player: AnimationPlayer
var _state_machine: AnimationNodeStateMachinePlayback
var _current_anim: String = ""
var _use_tree: bool = false

# ─────────────────────────────────────────────────────────────────────────────
# Lifecycle
# ─────────────────────────────────────────────────────────────────────────────

func _ready() -> void:
	_resolve_animation_nodes()
	_connect_event_bus()
	play_state(ANIM_IDLE)


func _resolve_animation_nodes() -> void:
	## Try AnimationTree first; fall back to raw AnimationPlayer.
	if not animation_tree_path.is_empty():
		_animation_tree = get_node_or_null(animation_tree_path)
	if not animation_player_path.is_empty():
		_animation_player = get_node_or_null(animation_player_path)

	if is_instance_valid(_animation_tree):
		_animation_tree.active = true
		_state_machine = _animation_tree.get(PARAM_STATE) as AnimationNodeStateMachinePlayback
		_use_tree = _state_machine != null
		if _use_tree:
			push_warning("PlayerAnimation: AnimationTree state machine found — using tree mode.")
		else:
			push_warning("PlayerAnimation: AnimationTree found but no state machine at '%s'. Falling back to AnimationPlayer." % PARAM_STATE)
	elif is_instance_valid(_animation_player):
		push_warning("PlayerAnimation: No AnimationTree — using AnimationPlayer directly.")
	else:
		push_error("PlayerAnimation: Neither AnimationTree nor AnimationPlayer found! Check node paths.")


func _connect_event_bus() -> void:
	## Listen to relevant EventBus signals.
	EventBus.player_jumped.connect(_on_player_jumped)
	EventBus.player_landed.connect(_on_player_landed)
	EventBus.player_slid.connect(_on_player_slid)
	EventBus.player_died.connect(_on_player_died)
	EventBus.game_state_changed.connect(_on_game_state_changed)
	EventBus.powerup_activated.connect(_on_powerup_activated)
	EventBus.powerup_deactivated.connect(_on_powerup_deactivated)
	EventBus.speed_updated.connect(_on_speed_updated)

# ─────────────────────────────────────────────────────────────────────────────
# Public API
# ─────────────────────────────────────────────────────────────────────────────

## Play a named animation state. Guards against redundant transitions.
func play_state(anim_name: String) -> void:
	if _current_anim == anim_name:
		return
	_current_anim = anim_name

	if _use_tree and is_instance_valid(_state_machine):
		if _state_machine.get_current_node() != anim_name:
			_state_machine.travel(anim_name)
	elif is_instance_valid(_animation_player):
		if _animation_player.has_animation(anim_name):
			_animation_player.play(anim_name)
		else:
			# Graceful fallback: play closest available animation
			var fallback := _find_fallback(anim_name)
			if fallback != "":
				_animation_player.play(fallback)
			else:
				push_warning("PlayerAnimation: No animation named '%s' and no fallback found." % anim_name)


## Adjust animation playback speed (synced with game speed).
func set_run_speed_scale(normalized_speed: float) -> void:
	## normalized_speed: 0.0 = initial speed, 1.0 = max speed
	var scale := lerp(run_speed_scale_min, run_speed_scale_max, normalized_speed)
	if _use_tree and is_instance_valid(_animation_tree):
		# Apply speed scale on the run animation via AnimationTree
		_animation_tree.set("parameters/TimeScale/scale", scale)
	elif is_instance_valid(_animation_player):
		_animation_player.speed_scale = scale

# ─────────────────────────────────────────────────────────────────────────────
# Event Bus Handlers
# ─────────────────────────────────────────────────────────────────────────────

func _on_player_jumped() -> void:
	play_state(ANIM_JUMP)


func _on_player_landed() -> void:
	play_state(ANIM_RUN)


func _on_player_slid() -> void:
	play_state(ANIM_SLIDE)


func _on_player_died(_position: Vector3) -> void:
	play_state(ANIM_DEAD)


func _on_game_state_changed(new_state: int) -> void:
	match new_state:
		GameManager.GameState.RUNNING:
			play_state(ANIM_RUN)
		GameManager.GameState.MAIN_MENU:
			play_state(ANIM_IDLE)
		GameManager.GameState.GAME_OVER:
			play_state(ANIM_DEAD)
		_:
			pass


func _on_powerup_activated(powerup_type: String) -> void:
	if powerup_type == "hoverboard":
		play_state(ANIM_DASH)


func _on_powerup_deactivated(powerup_type: String) -> void:
	if powerup_type == "hoverboard":
		play_state(ANIM_RUN)


func _on_speed_updated(current_speed: float) -> void:
	var max_speed: float = GameConstants.MAX_RUN_SPEED
	var initial: float = GameConstants.INITIAL_RUN_SPEED
	var normalized := clampf((current_speed - initial) / (max_speed - initial), 0.0, 1.0)
	set_run_speed_scale(normalized)

# ─────────────────────────────────────────────────────────────────────────────
# Private Helpers
# ─────────────────────────────────────────────────────────────────────────────

func _find_fallback(anim_name: String) -> String:
	## Returns the best available fallback animation name.
	var fallback_map: Dictionary = {
		ANIM_JUMP:   ANIM_RUN,
		ANIM_SLIDE:  ANIM_RUN,
		ANIM_DASH:   ANIM_RUN,
		ANIM_REVIVE: ANIM_IDLE,
		ANIM_DEAD:   ANIM_IDLE,
	}
	if fallback_map.has(anim_name):
		var fb: String = fallback_map[anim_name]
		if _animation_player.has_animation(fb):
			return fb
	if _animation_player.has_animation(ANIM_RUN):
		return ANIM_RUN
	if _animation_player.has_animation(ANIM_IDLE):
		return ANIM_IDLE
	return ""
