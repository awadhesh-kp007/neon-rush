## CoinManager — Tracks the player's coin wallet (soft currency).
##
## Responsibilities:
##   - Persistent coin balance via ConfigFile
##   - Atomic spend/earn operations (never negative)
##   - Emits EventBus signals on balance change
##   - Run-session coin collection tracked separately (synced to persistent on run end)
##
## Add to Autoload as "CoinManager".

class_name CoinManager
extends Node

const SAVE_PATH := "user://economy.cfg"
const SECTION   := "wallet"

signal balance_changed(new_balance: int)

var _coins: int = 0
var _session_coins: int = 0
var _config := ConfigFile.new()

func _ready() -> void:
	_load()
	EventBus.coin_collected.connect(_on_coin_collected)
	EventBus.run_ended.connect(_on_run_ended)
	EventBus.game_state_changed.connect(_on_game_state_changed)


# ─────────────────────────────────────────────────────────────────────────────
# Public API
# ─────────────────────────────────────────────────────────────────────────────

## Total persistent coin balance.
var balance: int:
	get: return _coins


## Coins collected in the current run (not yet saved to wallet).
var session_coins: int:
	get: return _session_coins


## Add coins to the persistent wallet (e.g., IAP, mission reward).
func earn(amount: int) -> void:
	if amount <= 0:
		return
	_coins += amount
	_save()
	emit_signal("balance_changed", _coins)
	EventBus.wallet_updated.emit(_coins)


## Deduct coins from wallet. Returns false if insufficient funds.
func spend(amount: int) -> bool:
	if amount <= 0:
		return true
	if _coins < amount:
		return false
	_coins -= amount
	_save()
	emit_signal("balance_changed", _coins)
	EventBus.wallet_updated.emit(_coins)
	return true


## Returns true if player can afford the given amount.
func can_afford(amount: int) -> bool:
	return _coins >= amount


## Reset session coins (called at run start).
func reset_session() -> void:
	_session_coins = 0

# ─────────────────────────────────────────────────────────────────────────────
# Event Handlers
# ─────────────────────────────────────────────────────────────────────────────

func _on_coin_collected(value: int) -> void:
	_session_coins += value
	EventBus.session_coins_updated.emit(_session_coins)


func _on_run_ended(_score: int, _coins_collected: int, _duration: float) -> void:
	# Commit session coins to persistent wallet
	earn(_session_coins)
	_session_coins = 0


func _on_game_state_changed(new_state: int) -> void:
	if new_state == GameManager.GameState.RUNNING:
		reset_session()

# ─────────────────────────────────────────────────────────────────────────────
# Persistence
# ─────────────────────────────────────────────────────────────────────────────

func _save() -> void:
	_config.set_value(SECTION, "coins", _coins)
	_config.save(SAVE_PATH)


func _load() -> void:
	if _config.load(SAVE_PATH) == OK:
		_coins = _config.get_value(SECTION, "coins", 0)
	else:
		_coins = 0
