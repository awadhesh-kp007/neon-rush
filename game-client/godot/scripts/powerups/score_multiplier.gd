## ScoreMultiplier — Manages the active score multiplier visual/audio feedback.
##
## The multiplier value itself is handled in ScoreManager (listens to multiplier_changed).
## This script drives the UI glow effect and announcer feedback.

class_name ScoreMultiplier
extends Node

@export var multiplier_label_path: NodePath  ## Optional: Label3D or Control node

var _label: Node
var _current_multiplier: float = 1.0

func _ready() -> void:
	if not multiplier_label_path.is_empty():
		_label = get_node_or_null(multiplier_label_path)
	EventBus.multiplier_changed.connect(_on_multiplier_changed)


func _on_multiplier_changed(value: float) -> void:
	_current_multiplier = value
	_update_label()
	if value > 1.0:
		EventBus.ui_feedback_requested.emit("x%.0f SCORE!" % value, 1.5)


func _update_label() -> void:
	if not is_instance_valid(_label):
		return
	if _label is Label:
		(_label as Label).text = "x%d" % int(_current_multiplier) if _current_multiplier > 1.0 else ""
