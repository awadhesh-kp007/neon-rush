## Hoverboard — Provides one-crash immunity and speed boost.
##
## The hoverboard is a defensive power-up:
##   - When active, the player rides visually on a board mesh
##   - On crash: hoverboard is destroyed (absorbed), grants 1.5s invincibility
##   - RunnerController and PlayerCollision both listen to hoverboard events
##
## This script controls the visual board object that appears under the player.

class_name Hoverboard
extends Node3D

@export var board_mesh_path: NodePath = NodePath("BoardMesh")
@export var activate_tween_duration: float = 0.25
@export var deactivate_tween_duration: float = 0.3

var _mesh: MeshInstance3D
var _is_active: bool = false

func _ready() -> void:
	_mesh = get_node_or_null(board_mesh_path) as MeshInstance3D
	visible = false
	EventBus.powerup_activated.connect(_on_powerup_activated)
	EventBus.powerup_deactivated.connect(_on_powerup_deactivated)
	EventBus.hoverboard_crashed.connect(_on_crashed)


func _on_powerup_activated(powerup_type: String) -> void:
	if powerup_type != "hoverboard":
		return
	_is_active = true
	visible = true
	# Animate board appearing from below
	var tween := create_tween()
	position.y = -1.0
	tween.tween_property(self, "position:y", 0.0, activate_tween_duration)
	tween.set_ease(Tween.EASE_OUT)


func _on_powerup_deactivated(powerup_type: String) -> void:
	if powerup_type != "hoverboard":
		return
	_do_deactivate()


func _on_crashed() -> void:
	_do_deactivate()
	# Visual: flash effect before hiding
	if is_instance_valid(_mesh):
		var tween := create_tween()
		tween.tween_property(_mesh, "transparency", 1.0, deactivate_tween_duration)


func _do_deactivate() -> void:
	_is_active = false
	var tween := create_tween()
	tween.tween_property(self, "position:y", -1.5, deactivate_tween_duration)
	tween.set_ease(Tween.EASE_IN)
	await tween.finished
	visible = false
	if is_instance_valid(_mesh):
		_mesh.transparency = 0.0
