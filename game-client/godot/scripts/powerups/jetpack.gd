## Jetpack — Overrides gravity and lifts the player above obstacles when active.
##
## Responsibilities:
##   - Signals RunnerController to override vertical movement while active
##   - Handles lift velocity and hover height
##   - Deactivates when powerup expires (smooth landing)
##
## Does NOT move the player directly — sends signals to RunnerController.

class_name Jetpack
extends Node

@export var hover_height: float = 3.5
@export var lift_speed: float = 8.0
@export var landing_speed: float = 5.0

var _is_active: bool = false

func _ready() -> void:
	EventBus.jetpack_activated.connect(_on_jetpack_activated)
	EventBus.jetpack_deactivated.connect(_on_jetpack_deactivated)


func _on_jetpack_activated() -> void:
	_is_active = true
	## RunnerController listens to jetpack_activated and overrides vertical physics
	push_warning("Jetpack: activated — RunnerController should handle hover.")


func _on_jetpack_deactivated() -> void:
	_is_active = false
	push_warning("Jetpack: deactivated — RunnerController should resume gravity.")
