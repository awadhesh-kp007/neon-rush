## GameplayHUD — In-run heads-up display.
## Shows score, distance, coins, power-up timers, and pause button.
## Reacts only to EventBus signals — zero direct coupling to gameplay nodes.

class_name GameplayHUD
extends CanvasLayer

# ─────────────────────────────────────────────────────────────────────────────
# Node References (assigned in scene)
# ─────────────────────────────────────────────────────────────────────────────
@onready var score_label: Label = $HUDContainer/TopBar/ScoreLabel
@onready var distance_label: Label = $HUDContainer/TopBar/DistanceLabel
@onready var coin_label: Label = $HUDContainer/TopBar/CoinLabel
@onready var multiplier_label: Label = $HUDContainer/TopBar/MultiplierLabel
@onready var countdown_label: Label = $HUDContainer/CountdownLabel
@onready var powerup_container: HBoxContainer = $HUDContainer/PowerUpBar
@onready var pause_button: Button = $HUDContainer/PauseButton

# ─────────────────────────────────────────────────────────────────────────────
# State
# ─────────────────────────────────────────────────────────────────────────────
var _powerup_timers: Dictionary = {}  # powerup_type → ProgressBar node

# ─────────────────────────────────────────────────────────────────────────────
# Godot Lifecycle
# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	_reset_display()

	EventBus.score_changed.connect(_on_score_changed)
	EventBus.distance_changed.connect(_on_distance_changed)
	EventBus.coin_collected.connect(_on_coin_collected)
	EventBus.multiplier_changed.connect(_on_multiplier_changed)
	EventBus.countdown_tick.connect(_on_countdown_tick)
	EventBus.game_started.connect(_on_game_started)
	EventBus.game_restarted.connect(_on_game_restarted)
	EventBus.powerup_activated.connect(_on_powerup_activated)
	EventBus.powerup_ended.connect(_on_powerup_ended)

	pause_button.pressed.connect(func(): GameManager.pause_game())


func _exit_tree() -> void:
	EventBus.score_changed.disconnect(_on_score_changed)
	EventBus.distance_changed.disconnect(_on_distance_changed)
	EventBus.coin_collected.disconnect(_on_coin_collected)
	EventBus.multiplier_changed.disconnect(_on_multiplier_changed)
	EventBus.countdown_tick.disconnect(_on_countdown_tick)
	EventBus.game_started.disconnect(_on_game_started)
	EventBus.game_restarted.disconnect(_on_game_restarted)
	EventBus.powerup_activated.disconnect(_on_powerup_activated)
	EventBus.powerup_ended.disconnect(_on_powerup_ended)

# ─────────────────────────────────────────────────────────────────────────────
# Signal Handlers
# ─────────────────────────────────────────────────────────────────────────────

func _on_score_changed(score: int) -> void:
	score_label.text = _format_score(score)


func _on_distance_changed(distance_m: float) -> void:
	distance_label.text = "%dm" % int(distance_m)


func _on_coin_collected(_amount: int, total: int) -> void:
	coin_label.text = str(total)


func _on_multiplier_changed(multiplier: float) -> void:
	if multiplier > 1.0:
		multiplier_label.text = "x%.0f" % multiplier
		multiplier_label.show()
	else:
		multiplier_label.hide()


func _on_countdown_tick(seconds: int) -> void:
	countdown_label.show()
	countdown_label.text = str(seconds) if seconds > 0 else "GO!"


func _on_game_started() -> void:
	# Hide countdown with a brief delay so "GO!" is visible
	await get_tree().create_timer(0.5).timeout
	countdown_label.hide()


func _on_game_restarted() -> void:
	_reset_display()


func _on_powerup_activated(powerup_type: String, duration: float) -> void:
	# Create a progress bar timer indicator
	var bar := ProgressBar.new()
	bar.name = powerup_type
	bar.min_value = 0.0
	bar.max_value = duration
	bar.value = duration
	bar.custom_minimum_size = Vector2(60, 10)
	powerup_container.add_child(bar)
	_powerup_timers[powerup_type] = {"bar": bar, "remaining": duration, "total": duration}


func _on_powerup_ended(powerup_type: String) -> void:
	if powerup_type in _powerup_timers:
		var data: Dictionary = _powerup_timers[powerup_type]
		data["bar"].queue_free()
		_powerup_timers.erase(powerup_type)


func _process(delta: float) -> void:
	# Update power-up timer bars
	for powerup_type in _powerup_timers.keys():
		var data: Dictionary = _powerup_timers[powerup_type]
		data["remaining"] = maxf(data["remaining"] - delta, 0.0)
		(data["bar"] as ProgressBar).value = data["remaining"]

# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────

func _reset_display() -> void:
	score_label.text = "0"
	distance_label.text = "0m"
	coin_label.text = "0"
	multiplier_label.hide()
	countdown_label.hide()
	for child in powerup_container.get_children():
		child.queue_free()
	_powerup_timers.clear()


func _format_score(score: int) -> String:
	# Format: 1234567 → "1,234,567"
	var s := str(score)
	var result := ""
	for i in range(s.length()):
		if i > 0 and (s.length() - i) % 3 == 0:
			result += ","
		result += s[i]
	return result
