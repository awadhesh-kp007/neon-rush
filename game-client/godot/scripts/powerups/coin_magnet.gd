## CoinMagnet — Pulls nearby coins toward the player when active.
##
## Responsibilities:
##   - Uses a large Area3D (magnet radius) to detect coin nodes
##   - Tweens coin positions toward the player's CollisionDetector
##   - Deactivates gracefully when powerup expires
##
## Attach as child of the Player CharacterBody3D.
## Expects a child Area3D named "MagnetRadius" with a SphereShape3D.

class_name CoinMagnet
extends Node

@export var magnet_radius: float = 6.0
@export var attract_speed: float = 20.0

var _magnet_area: Area3D
var _player: Node3D
var _is_active: bool = false
var _attracted_coins: Array[Node3D] = []

func _ready() -> void:
	_player = get_parent() as Node3D
	_setup_magnet_area()
	EventBus.coin_magnet_activated.connect(_on_magnet_activated)
	EventBus.coin_magnet_deactivated.connect(_on_magnet_deactivated)


func _setup_magnet_area() -> void:
	_magnet_area = Area3D.new()
	var shape_node := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = magnet_radius
	shape_node.shape = sphere
	_magnet_area.add_child(shape_node)
	add_child(_magnet_area)
	_magnet_area.collision_layer = 0
	_magnet_area.collision_mask = GameConstants.COLLISION_LAYER_COIN
	_magnet_area.area_entered.connect(_on_coin_entered_range)
	_magnet_area.monitoring = false  ## Off by default


func _process(delta: float) -> void:
	if not _is_active or not is_instance_valid(_player):
		return
	# Move all attracted coins toward player
	for i in range(_attracted_coins.size() - 1, -1, -1):
		var coin: Node3D = _attracted_coins[i]
		if not is_instance_valid(coin):
			_attracted_coins.remove_at(i)
			continue
		var dir := (_player.global_position - coin.global_position)
		var dist := dir.length()
		if dist < 0.5:
			# Close enough — trigger collect and remove from tracking
			EventBus.coin_collected.emit(_get_coin_value(coin))
			coin.queue_free()
			_attracted_coins.remove_at(i)
		else:
			coin.global_position += dir.normalized() * attract_speed * delta


func _on_coin_entered_range(area: Area3D) -> void:
	if not _is_active:
		return
	if area.is_in_group(PlayerCollision.GROUP_COIN) and not _attracted_coins.has(area):
		_attracted_coins.append(area)


func _get_coin_value(coin: Node3D) -> int:
	if coin.has_meta("coin_value"):
		return coin.get_meta("coin_value") as int
	return 1


func _on_magnet_activated() -> void:
	_is_active = true
	_magnet_area.monitoring = true


func _on_magnet_deactivated() -> void:
	_is_active = false
	_magnet_area.monitoring = false
	_attracted_coins.clear()
