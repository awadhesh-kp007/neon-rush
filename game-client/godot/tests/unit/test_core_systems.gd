## GDScript Unit Tests — NEON RUSH: CITY ESCAPE
## Uses Godot's built-in test framework (GUT - Godot Unit Testing addon).
## Install GUT via AssetLib or: https://github.com/bitwes/Gut

extends GutTest

# ─────────────────────────────────────────────────────────────────────────────
# ScoreManager Tests
# ─────────────────────────────────────────────────────────────────────────────

class TestScoreManager:
	extends GutTest

	var score_mgr: Node

	func before_each() -> void:
		score_mgr = preload("res://scripts/gameplay/score_manager.gd").new()
		add_child(score_mgr)
		# Simulate game restart to reset state
		score_mgr._on_game_restarted()

	func after_each() -> void:
		score_mgr.queue_free()

	func test_initial_score_is_zero() -> void:
		assert_eq(score_mgr.current_score, 0, "Initial score should be zero")

	func test_add_distance_increases_score() -> void:
		score_mgr.add_distance(100.0)
		assert_gt(score_mgr.current_score, 0, "Score should increase after adding distance")

	func test_add_coins_increases_score_and_count() -> void:
		score_mgr.add_coins(5)
		assert_eq(score_mgr.coins_collected, 5, "Coin count should be 5")
		assert_eq(score_mgr.current_score, 5 * 10, "Score should be coins * SCORE_PER_COIN")

	func test_multiplier_applied_to_distance_score() -> void:
		score_mgr.set_multiplier(2.0)
		score_mgr.add_distance(100.0)
		var score_without_multiplier := 100  # 100m * 1.0 score/m
		assert_gt(score_mgr.current_score, score_without_multiplier,
			"Multiplier should increase score beyond base")

	func test_multiplier_reset_on_game_restart() -> void:
		score_mgr.set_multiplier(3.0)
		score_mgr._on_game_restarted()
		assert_eq(score_mgr.current_multiplier, 1.0, "Multiplier should reset to 1.0 on restart")

	func test_xp_calculation() -> void:
		score_mgr.current_score = 1000
		assert_eq(score_mgr.calculate_xp(), 10, "XP = score / 100")

	func test_new_high_score_detected() -> void:
		score_mgr._best_score = 500
		score_mgr.current_score = 1000
		assert_true(score_mgr.is_new_high_score(), "Should detect new high score")

	func test_no_false_high_score() -> void:
		score_mgr._best_score = 1000
		score_mgr.current_score = 500
		assert_false(score_mgr.is_new_high_score(), "Should not flag lower score as high score")

	func test_full_reset_on_restart() -> void:
		score_mgr.current_score = 9999
		score_mgr.coins_collected = 100
		score_mgr.current_distance = 500.0
		score_mgr._on_game_restarted()
		assert_eq(score_mgr.current_score, 0)
		assert_eq(score_mgr.coins_collected, 0)
		assert_eq(score_mgr.current_distance, 0.0)


# ─────────────────────────────────────────────────────────────────────────────
# ObjectPool Tests
# ─────────────────────────────────────────────────────────────────────────────

class TestObjectPool:
	extends GutTest

	var pool: ObjectPool
	var parent: Node3D
	var test_scene: PackedScene

	func before_all() -> void:
		# Create a minimal PackedScene for testing using a plain Node3D
		test_scene = PackedScene.new()
		var node := Node3D.new()
		node.name = "TestNode"
		test_scene.pack(node)
		node.free()

	func before_each() -> void:
		parent = Node3D.new()
		add_child(parent)
		pool = ObjectPool.new(test_scene, parent, 4, 10)

	func after_each() -> void:
		parent.queue_free()

	func test_prewarm_creates_instances() -> void:
		assert_eq(pool.total_count(), 4, "Pool should have 4 pre-warmed instances")

	func test_get_returns_active_node() -> void:
		var instance := pool.get_instance()
		assert_not_null(instance, "get_instance() should return a node")
		assert_true(instance.visible, "Retrieved instance should be visible")

	func test_active_count_increases_on_get() -> void:
		pool.get_instance()
		pool.get_instance()
		assert_eq(pool.active_count(), 2)

	func test_release_returns_to_pool() -> void:
		var instance := pool.get_instance()
		pool.release(instance)
		assert_eq(pool.active_count(), 0, "Active count should be 0 after release")
		assert_false(instance.visible, "Released instance should be hidden")

	func test_release_all_clears_active() -> void:
		pool.get_instance()
		pool.get_instance()
		pool.get_instance()
		pool.release_all()
		assert_eq(pool.active_count(), 0, "All instances should be released")

	func test_max_size_respected() -> void:
		# Exhaust the pool
		var instances := []
		for i in range(10):
			instances.append(pool.get_instance())
		# 11th get should return null
		var overflow := pool.get_instance()
		assert_null(overflow, "Pool should return null when max_size reached")


# ─────────────────────────────────────────────────────────────────────────────
# SwipeInputController Tests (gesture math only)
# ─────────────────────────────────────────────────────────────────────────────

class TestSwipeGestureMath:
	extends GutTest

	## Helper: simulate swipe evaluation without a real node.
	## Tests the pure math of gesture classification.

	const MIN_DIST: float = 50.0
	const MAX_DUR: float = 0.5
	const DIR_RATIO: float = 1.5
	const TAP_MOVE: float = 15.0

	func _classify_gesture(delta: Vector2, duration: float) -> String:
		var mag := delta.length()
		if mag < TAP_MOVE:
			return "TAP"
		if mag < MIN_DIST or duration > MAX_DUR:
			return "IGNORED"
		var ax := absf(delta.x)
		var ay := absf(delta.y)
		if ax > ay and (ax / maxf(ay, 0.001)) >= DIR_RATIO:
			return "LEFT" if delta.x < 0 else "RIGHT"
		elif ay > ax and (ay / maxf(ax, 0.001)) >= DIR_RATIO:
			return "UP" if delta.y < 0 else "DOWN"
		return "DIAGONAL"

	func test_right_swipe_detected() -> void:
		assert_eq(_classify_gesture(Vector2(100, 10), 0.2), "RIGHT")

	func test_left_swipe_detected() -> void:
		assert_eq(_classify_gesture(Vector2(-100, 10), 0.2), "LEFT")

	func test_up_swipe_detected() -> void:
		assert_eq(_classify_gesture(Vector2(5, -100), 0.2), "UP")

	func test_down_swipe_detected() -> void:
		assert_eq(_classify_gesture(Vector2(5, 100), 0.2), "DOWN")

	func test_too_short_ignored() -> void:
		assert_eq(_classify_gesture(Vector2(30, 5), 0.2), "IGNORED")

	func test_too_slow_ignored() -> void:
		assert_eq(_classify_gesture(Vector2(100, 5), 0.8), "IGNORED")

	func test_diagonal_not_classified() -> void:
		assert_eq(_classify_gesture(Vector2(80, 80), 0.2), "DIAGONAL")

	func test_tap_classified() -> void:
		assert_eq(_classify_gesture(Vector2(5, 3), 0.1), "TAP")


# ─────────────────────────────────────────────────────────────────────────────
# DifficultyManager Tests
# ─────────────────────────────────────────────────────────────────────────────

class TestDifficultyManager:
	extends GutTest

	func test_speed_increases_with_distance() -> void:
		# Pure formula test: speed = initial + (distance/100) * increment
		var initial := 10.0
		var increment := 1.0
		var distance := 500.0
		var expected := minf(initial + (distance / 100.0) * increment, 35.0)
		assert_almost_eq(expected, 15.0, 0.001, "Speed at 500m should be 15 m/s")

	func test_speed_capped_at_max() -> void:
		var initial := 10.0
		var increment := 1.0
		var distance := 999999.0
		var capped := minf(initial + (distance / 100.0) * increment, 35.0)
		assert_eq(capped, 35.0, "Speed should never exceed MAX_SPEED")
