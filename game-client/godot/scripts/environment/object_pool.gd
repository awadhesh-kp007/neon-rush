## ObjectPool — Generic object pool for Godot 4.
##
## Recycles PackedScene instances to avoid runtime Instantiate/free calls
## which cause frame spikes. Use for: track segments, obstacles, coins,
## particles, and any frequently spawned nodes.
##
## Usage:
##   var pool = ObjectPool.new(preload("res://scenes/obstacles/barrier.tscn"), parent_node, 10)
##   var instance = pool.get_instance()
##   pool.release(instance)

class_name ObjectPool
extends RefCounted

# ─────────────────────────────────────────────────────────────────────────────
# State
# ─────────────────────────────────────────────────────────────────────────────
var _scene: PackedScene
var _parent: Node
var _pool: Array[Node] = []
var _active: Array[Node] = []
var _max_size: int

# ─────────────────────────────────────────────────────────────────────────────
# Constructor
# ─────────────────────────────────────────────────────────────────────────────

## @param scene: PackedScene to instantiate
## @param parent: Node to parent instances to
## @param initial_size: Number of instances to pre-create
## @param max_size: Hard cap; additional Get() calls beyond this return null
func _init(scene: PackedScene, parent: Node, initial_size: int = 8, max_size: int = 32) -> void:
	assert(scene != null, "ObjectPool: scene must not be null")
	assert(parent != null, "ObjectPool: parent must not be null")
	_scene = scene
	_parent = parent
	_max_size = max_size
	_prewarm(initial_size)

# ─────────────────────────────────────────────────────────────────────────────
# Public API
# ─────────────────────────────────────────────────────────────────────────────

## Get a pooled instance. Returns null if max_size is reached.
func get_instance() -> Node:
	var instance: Node
	if _pool.is_empty():
		if (_pool.size() + _active.size()) >= _max_size:
			push_warning("[ObjectPool] Pool exhausted for scene: %s" % _scene.resource_path)
			return null
		instance = _create_instance()
	else:
		instance = _pool.pop_back()

	instance.show()
	_active.append(instance)
	return instance


## Return an instance to the pool. Hides and resets it.
func release(instance: Node) -> void:
	var idx := _active.find(instance)
	if idx == -1:
		push_warning("[ObjectPool] Tried to release an instance not owned by this pool.")
		return

	_active.remove_at(idx)
	instance.hide()
	# Reset position so the next Get() starts clean
	if instance is Node3D:
		(instance as Node3D).position = Vector3.ZERO
	_pool.append(instance)


## Release all currently active instances back to the pool.
func release_all() -> void:
	for instance in _active.duplicate():
		release(instance)


## Total number of instances managed by this pool.
func total_count() -> int:
	return _pool.size() + _active.size()


## Number of currently active (in-use) instances.
func active_count() -> int:
	return _active.size()


## Number of instances available in the pool.
func available_count() -> int:
	return _pool.size()

# ─────────────────────────────────────────────────────────────────────────────
# Private
# ─────────────────────────────────────────────────────────────────────────────

func _prewarm(count: int) -> void:
	for i in range(count):
		var instance := _create_instance()
		instance.hide()
		_pool.append(instance)


func _create_instance() -> Node:
	var instance := _scene.instantiate()
	_parent.add_child(instance)
	return instance
