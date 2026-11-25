## AuthManager — Handles player authentication with the backend.
##
## Responsibilities:
##   - Guest play (no account required for core gameplay)
##   - Register / Login / Logout flows via ApiClient
##   - Persists tokens and user info to ConfigFile (encrypted)
##   - Emits EventBus signals for auth state changes
##   - Provides player profile summary to other systems
##
## Add to Autoload as "AuthManager".

class_name AuthManager
extends Node

const SAVE_PATH  := "user://auth.cfg"
const SECTION    := "auth"

## Emitted when user successfully authenticates.
signal logged_in(player_id: String, username: String)
## Emitted on logout or token expiry.
signal logged_out()

# ─────────────────────────────────────────────────────────────────────────────
# State
# ─────────────────────────────────────────────────────────────────────────────

var is_authenticated: bool = false
var player_id: String = ""
var username: String = ""
var _config := ConfigFile.new()

# ─────────────────────────────────────────────────────────────────────────────
# Lifecycle
# ─────────────────────────────────────────────────────────────────────────────

func _ready() -> void:
	_load_persisted_session()
	EventBus.auth_session_expired.connect(_on_session_expired)

# ─────────────────────────────────────────────────────────────────────────────
# Public API
# ─────────────────────────────────────────────────────────────────────────────

## Attempt login with email/password. Returns true on success.
func login(email: String, password: String) -> bool:
	var result := await ApiClient.post_async("/auth/login", {
		"email": email,
		"password": password,
	})
	if not result.ok:
		push_warning("AuthManager: Login failed — %s" % result.error_message)
		EventBus.auth_error.emit(result.error_message)
		return false
	return _apply_auth_response(result.data)


## Register a new account. Returns true on success.
func register(email: String, password: String, display_name: String) -> bool:
	var result := await ApiClient.post_async("/auth/register", {
		"email": email,
		"password": password,
		"displayName": display_name,
	})
	if not result.ok:
		push_warning("AuthManager: Register failed — %s" % result.error_message)
		EventBus.auth_error.emit(result.error_message)
		return false
	return _apply_auth_response(result.data)


## Logout: clear tokens and local session.
func logout() -> void:
	if not is_authenticated:
		return
	# Best-effort server logout
	ApiClient.post_async("/auth/logout", {})
	_clear_session()
	emit_signal("logged_out")
	EventBus.player_logged_out.emit()


## True if the player can play (even as guest).
func can_play() -> bool:
	return true  ## Game is always playable offline/as guest


## True if scores/purchases will be synced to backend.
func is_synced() -> bool:
	return is_authenticated

# ─────────────────────────────────────────────────────────────────────────────
# Internal
# ─────────────────────────────────────────────────────────────────────────────

func _apply_auth_response(data: Dictionary) -> bool:
	var access := data.get("accessToken", "")
	var refresh := data.get("refreshToken", "")
	var pid := data.get("playerId", "")
	var uname := data.get("username", "")
	if access.is_empty() or pid.is_empty():
		push_warning("AuthManager: Unexpected auth response structure.")
		return false

	ApiClient.set_tokens(access, refresh)
	player_id = pid
	username = uname
	is_authenticated = true
	_save_session(access, refresh, pid, uname)
	emit_signal("logged_in", player_id, username)
	EventBus.player_logged_in.emit(player_id, username)
	return true


func _clear_session() -> void:
	ApiClient.clear_tokens()
	player_id = ""
	username = ""
	is_authenticated = false
	_config.set_value(SECTION, "access_token", "")
	_config.set_value(SECTION, "refresh_token", "")
	_config.save(SAVE_PATH)


func _save_session(access: String, refresh: String, pid: String, uname: String) -> void:
	_config.set_value(SECTION, "access_token", access)
	_config.set_value(SECTION, "refresh_token", refresh)
	_config.set_value(SECTION, "player_id", pid)
	_config.set_value(SECTION, "username", uname)
	_config.save(SAVE_PATH)


func _load_persisted_session() -> void:
	if _config.load(SAVE_PATH) != OK:
		return
	var access := _config.get_value(SECTION, "access_token", "")
	var refresh := _config.get_value(SECTION, "refresh_token", "")
	player_id = _config.get_value(SECTION, "player_id", "")
	username = _config.get_value(SECTION, "username", "")
	if access != "" and player_id != "":
		ApiClient.set_tokens(access, refresh)
		is_authenticated = true
		# Token will be validated on first API call; refresh if 401


func _on_session_expired() -> void:
	_clear_session()
	emit_signal("logged_out")
	EventBus.player_logged_out.emit()
