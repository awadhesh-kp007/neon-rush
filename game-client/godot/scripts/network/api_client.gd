## ApiClient — Thin HTTP client for communicating with the NEON RUSH backend.
##
## Responsibilities:
##   - Wraps HTTPRequest calls into async helpers
##   - Handles JWT Bearer token injection
##   - Centralizes base URL config (from GameConstants or project settings)
##   - Returns typed Result objects; never crashes on network failure
##   - Respects offline mode — queues requests when offline, flushes on reconnect
##
## Add to Autoload as "ApiClient".

class_name ApiClient
extends Node

# ─────────────────────────────────────────────────────────────────────────────
# Config
# ─────────────────────────────────────────────────────────────────────────────

@export var base_url: String = "https://api.neonrush.game/v1"
@export var timeout_seconds: float = 15.0
@export var max_retries: int = 2
@export var offline_queue_limit: int = 50

## Result wrapper for all API calls.
class ApiResult:
	var ok: bool = false
	var status_code: int = 0
	var data: Dictionary = {}
	var error_message: String = ""

	static func success(code: int, body: Dictionary) -> "ApiResult":
		var r := ApiResult.new()
		r.ok = true
		r.status_code = code
		r.data = body
		return r

	static func failure(code: int, msg: String) -> "ApiResult":
		var r := ApiResult.new()
		r.ok = false
		r.status_code = code
		r.error_message = msg
		return r

# ─────────────────────────────────────────────────────────────────────────────
# State
# ─────────────────────────────────────────────────────────────────────────────

var _auth_token: String = ""
var _refresh_token: String = ""
var _is_online: bool = false
var _offline_queue: Array[Dictionary] = []  ## Queued POST/PUT requests

# ─────────────────────────────────────────────────────────────────────────────
# Lifecycle
# ─────────────────────────────────────────────────────────────────────────────

func _ready() -> void:
	EventBus.network_connected.connect(_on_network_connected)
	EventBus.network_disconnected.connect(_on_network_disconnected)
	EventBus.auth_token_refreshed.connect(_on_token_refreshed)
	_check_connectivity()


func _check_connectivity() -> void:
	## Basic connectivity check — tries a lightweight ping endpoint.
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(result, _code, _headers, _body):
		_is_online = (result == HTTPRequest.RESULT_SUCCESS)
		http.queue_free()
	)
	http.request(base_url + "/health")

# ─────────────────────────────────────────────────────────────────────────────
# Auth Token Management
# ─────────────────────────────────────────────────────────────────────────────

func set_tokens(access_token: String, refresh: String) -> void:
	_auth_token = access_token
	_refresh_token = refresh


func clear_tokens() -> void:
	_auth_token = ""
	_refresh_token = ""

# ─────────────────────────────────────────────────────────────────────────────
# Public HTTP Methods (async — use await)
# ─────────────────────────────────────────────────────────────────────────────

## HTTP GET. Returns ApiResult.
func get_async(endpoint: String) -> ApiResult:
	return await _request_async("GET", endpoint, {})


## HTTP POST with JSON body. Returns ApiResult.
func post_async(endpoint: String, body: Dictionary) -> ApiResult:
	return await _request_async("POST", endpoint, body)


## HTTP PUT with JSON body. Returns ApiResult.
func put_async(endpoint: String, body: Dictionary) -> ApiResult:
	return await _request_async("PUT", endpoint, body)


## HTTP PATCH with JSON body. Returns ApiResult.
func patch_async(endpoint: String, body: Dictionary) -> ApiResult:
	return await _request_async("PATCH", endpoint, body)


## Enqueue a POST for offline scenarios — fires when network reconnects.
func queue_offline_post(endpoint: String, body: Dictionary) -> void:
	if _offline_queue.size() >= offline_queue_limit:
		push_warning("ApiClient: Offline queue full — dropping request to '%s'." % endpoint)
		return
	_offline_queue.append({"method": "POST", "endpoint": endpoint, "body": body})

# ─────────────────────────────────────────────────────────────────────────────
# Internal
# ─────────────────────────────────────────────────────────────────────────────

func _request_async(method: String, endpoint: String, body: Dictionary) -> ApiResult:
	if not _is_online:
		return ApiResult.failure(0, "Device is offline.")

	var url := base_url + endpoint
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Accept: application/json",
	])
	if _auth_token != "":
		headers.append("Authorization: Bearer " + _auth_token)

	var http := HTTPRequest.new()
	http.timeout = timeout_seconds
	add_child(http)

	var method_int := _method_to_int(method)
	var body_json := JSON.stringify(body) if not body.is_empty() else ""
	var err := http.request(url, headers, method_int, body_json)
	if err != OK:
		http.queue_free()
		return ApiResult.failure(-1, "HTTPRequest error: %d" % err)

	var response: Array = await http.request_completed
	http.queue_free()

	var result_code: int = response[0]
	var http_code: int   = response[1]
	var resp_body: PackedByteArray = response[3]

	if result_code != HTTPRequest.RESULT_SUCCESS:
		return ApiResult.failure(http_code, "Network error (code %d)." % result_code)

	var json := JSON.new()
	var parse_err := json.parse(resp_body.get_string_from_utf8())
	if parse_err != OK:
		return ApiResult.failure(http_code, "Invalid JSON response.")

	if http_code == 401:
		## Token expired — attempt refresh
		var refreshed := await _try_refresh_token()
		if refreshed:
			return await _request_async(method, endpoint, body)
		return ApiResult.failure(401, "Unauthorized — please log in again.")

	if http_code >= 400:
		var msg: String = (json.data as Dictionary).get("message", "Server error %d." % http_code)
		return ApiResult.failure(http_code, msg)

	return ApiResult.success(http_code, json.data as Dictionary)


func _method_to_int(method: String) -> int:
	match method:
		"GET":    return HTTPClient.METHOD_GET
		"POST":   return HTTPClient.METHOD_POST
		"PUT":    return HTTPClient.METHOD_PUT
		"PATCH":  return HTTPClient.METHOD_PATCH
		"DELETE": return HTTPClient.METHOD_DELETE
		_:        return HTTPClient.METHOD_GET


func _try_refresh_token() -> bool:
	if _refresh_token.is_empty():
		return false
	var result := await post_async("/auth/refresh", {"refreshToken": _refresh_token})
	if result.ok:
		var new_access := result.data.get("accessToken", "")
		var new_refresh := result.data.get("refreshToken", _refresh_token)
		if new_access != "":
			set_tokens(new_access, new_refresh)
			EventBus.auth_token_refreshed.emit(new_access)
			return true
	clear_tokens()
	EventBus.auth_session_expired.emit()
	return false

# ─────────────────────────────────────────────────────────────────────────────
# Event Handlers
# ─────────────────────────────────────────────────────────────────────────────

func _on_network_connected() -> void:
	_is_online = true
	_flush_offline_queue()


func _on_network_disconnected() -> void:
	_is_online = false


func _on_token_refreshed(new_token: String) -> void:
	_auth_token = new_token


func _flush_offline_queue() -> void:
	var to_flush := _offline_queue.duplicate()
	_offline_queue.clear()
	for item in to_flush:
		## Fire-and-forget retry
		post_async(item["endpoint"], item["body"])
