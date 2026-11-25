## EventBus — Global decoupled event system for NEON RUSH.
##
## All game systems communicate through this singleton instead of
## direct node references. Prevents tight coupling and makes systems
## independently testable.
##
## Usage:
##   # Emit from anywhere:
##   EventBus.player_jumped.emit()
##   EventBus.coin_collected.emit(5)
##
##   # Connect from anywhere:
##   EventBus.player_jumped.connect(_on_player_jumped)
##   EventBus.coin_collected.connect(_on_coins_collected)
##
## Register as an Autoload singleton named "EventBus" in Project Settings.

extends Node

# ── Game Lifecycle ─────────────────────────────────────────────────────────────
signal game_state_changed(from_state: String, to_state: String)
signal countdown_tick(seconds_remaining: int)
signal game_started
signal game_paused
signal game_resumed
signal game_over(run_result: Dictionary)
signal game_restarted

# ── Player Movement ───────────────────────────────────────────────────────────
signal player_lane_changed(from_lane: int, to_lane: int)
signal player_jumped
signal player_landed
signal player_slide_started
signal player_slide_ended
signal player_fatal_collision(obstacle_name: String)
signal player_hoverboard_activated
signal player_hoverboard_destroyed

# ── Score & Economy ───────────────────────────────────────────────────────────
signal score_changed(new_score: int)
signal distance_changed(new_distance_m: float)
signal coin_collected(amount: int, new_total: int)
signal multiplier_changed(new_multiplier: float)
signal new_high_score(score: int)
signal xp_gained(amount: int, new_total: int)
signal level_up(new_level: int)

# ── Power-ups ─────────────────────────────────────────────────────────────────
signal powerup_activated(powerup_type: String, duration: float)
signal powerup_ended(powerup_type: String)
signal powerup_collected(powerup_type: String)

# ── Missions ──────────────────────────────────────────────────────────────────
signal mission_progress_updated(mission_id: String, progress: int, target: int)
signal mission_completed(mission_id: String, reward: Dictionary)

# ── Network ───────────────────────────────────────────────────────────────────
signal network_connected
signal network_disconnected
signal auth_success(player_data: Dictionary)
signal auth_failed(error: String)
signal leaderboard_loaded(entries: Array)
signal score_submitted(result: Dictionary)

# ── UI ────────────────────────────────────────────────────────────────────────
signal screen_transition_requested(target_screen: String, data: Dictionary)
signal notification_requested(message: String, duration: float)
signal loading_started(context: String)
signal loading_finished

# ── Audio ─────────────────────────────────────────────────────────────────────
signal music_track_requested(track_name: String, fade: bool)
signal sfx_requested(sfx_name: String, position: Vector3)

# ── Analytics ─────────────────────────────────────────────────────────────────
signal analytics_event(event_name: String, params: Dictionary)
