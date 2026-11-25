## GDScript Style Guide — NEON RUSH: CITY ESCAPE
## All scripts follow these conventions.

# ─────────────────────────────────────────────────────────────────────────────
# FILE: scripts/core/game_constants.gd
# PURPOSE: Central constants. Never hardcode values in gameplay scripts.
# ─────────────────────────────────────────────────────────────────────────────
extends Node

# ── Lane Configuration ────────────────────────────────────────────────────────
const LANE_COUNT: int = 3
const LANE_POSITIONS: Array[float] = [-2.0, 0.0, 2.0]  # World-space X offsets
const LANE_LEFT: int = 0
const LANE_CENTER: int = 1
const LANE_RIGHT: int = 2

# ── Player Physics ────────────────────────────────────────────────────────────
const JUMP_FORCE: float = 12.0
const GRAVITY_MULTIPLIER: float = 2.5     # Applied on top of project gravity
const SLIDE_DURATION: float = 0.8         # Seconds
const LANE_SWITCH_SPEED: float = 10.0     # Lerp factor per second
const MIN_LANE_SWITCH_INTERVAL: float = 0.2  # Seconds (anti-spam)

# ── Speed Progression ─────────────────────────────────────────────────────────
const INITIAL_SPEED: float = 10.0         # m/s at run start
const MAX_SPEED: float = 35.0             # m/s hard cap (anti-cheat bound)
const SPEED_RAMP_PER_METER: float = 0.001 # Speed increase per meter run

# ── Track Generation ──────────────────────────────────────────────────────────
const SEGMENT_LENGTH: float = 30.0
const SEGMENTS_AHEAD: int = 6
const RECYCLE_DISTANCE: float = 25.0
const POOL_SIZE_PER_TYPE: int = 8

# ── Scoring ───────────────────────────────────────────────────────────────────
const SCORE_PER_METER: float = 1.0
const SCORE_PER_COIN: int = 10
const XP_DIVISOR: float = 100.0           # XP = final_score / XP_DIVISOR

# ── Economy ───────────────────────────────────────────────────────────────────
const STARTING_COINS: int = 0
const STARTING_GEMS: int = 0

# ── Power-up Durations (seconds) ─────────────────────────────────────────────
const MAGNET_DURATION: float = 20.0
const JETPACK_DURATION: float = 12.0
const HOVERBOARD_DURATION: float = 30.0   # Or until hit
const MULTIPLIER_DURATION: float = 20.0
const SPEED_BOOST_DURATION: float = 8.0

# ── Input Thresholds ──────────────────────────────────────────────────────────
const SWIPE_MIN_DISTANCE: float = 50.0    # Pixels
const SWIPE_MAX_DURATION: float = 0.5     # Seconds
const SWIPE_DIRECTIONALITY: float = 1.5   # Dominant/minor axis ratio
const DOUBLE_TAP_WINDOW: float = 0.3      # Seconds between taps
const TAP_MAX_MOVEMENT: float = 15.0      # Pixels

# ── Networking ────────────────────────────────────────────────────────────────
const API_TIMEOUT: float = 10.0
const MAX_RETRY_ATTEMPTS: int = 3
const RETRY_DELAY: float = 1.0

# ── Anti-Cheat (must match server) ───────────────────────────────────────────
const MAX_COINS_PER_SECOND: float = 8.0
const MAX_SPEED_SERVER_BOUND: float = 45.0

# ── Save Keys ─────────────────────────────────────────────────────────────────
const SAVE_KEY_BEST_SCORE: String = "best_score"
const SAVE_KEY_TOTAL_COINS: String = "total_coins"
const SAVE_KEY_SELECTED_CHARACTER: String = "selected_character"
const SAVE_KEY_GRAPHICS_QUALITY: String = "graphics_quality"
const SAVE_KEY_MUSIC_VOLUME: String = "music_volume"
const SAVE_KEY_SFX_VOLUME: String = "sfx_volume"
