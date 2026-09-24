extends SceneTree

## Lucky strike timing, payout, and miss rules.
## Run: godot --headless --path <project> -s res://tests/test_lucky_strike.gd

var _failed: int = 0
var _passed: int = 0
var GS: Node
var TN: Node
var Lucky: GDScript


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	GS = root.get_node("GameState")
	TN = root.get_node("Tuning")
	Lucky = load("res://lucky_strike.gd") as GDScript
	_test_script_exists()
	_test_not_every_shift()
	_test_never_spawns_in_first_second()
	_test_at_most_twice_and_not_stacked()
	_test_cell_stays_in_grid()
	_test_cash_burst_is_fat()
	_test_hands_and_shovel_can_hit()
	_test_miss_has_no_punish()
	_test_hired_hand_does_not_auto_dig()
	print("lucky_strike %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _test_script_exists() -> void:
	_assert(Lucky != null, "lucky_strike.gd exists")


func _test_not_every_shift() -> void:
	if Lucky == null:
		return
	var saved: float = float(TN.lucky_shift_chance)
	TN.lucky_shift_chance = 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var none: PackedFloat32Array = Lucky.plan_shift(rng, 40.0)
	_assert(none.is_empty(), "a cold shift can spawn nothing")
	TN.lucky_shift_chance = saved


func _test_never_spawns_in_first_second() -> void:
	if Lucky == null:
		return
	var saved_chance: float = float(TN.lucky_shift_chance)
	var saved_second: float = float(TN.lucky_second_chance)
	TN.lucky_shift_chance = 1.0
	TN.lucky_second_chance = 0.0
	var rng := RandomNumberGenerator.new()
	for seed in 24:
		rng.seed = seed
		var times: PackedFloat32Array = Lucky.plan_shift(rng, 40.0)
		_assert(times.size() >= 1, "a guaranteed shift still rolls a strike")
		if times.is_empty():
			continue
		_assert(times[0] >= 6.0, "first strike waits past the opening seconds")
		_assert(times[0] > 1.0, "never flashes on the first second")
	TN.lucky_shift_chance = saved_chance
	TN.lucky_second_chance = saved_second


func _test_at_most_twice_and_not_stacked() -> void:
	if Lucky == null:
		return
	var saved_chance: float = float(TN.lucky_shift_chance)
	var saved_second: float = float(TN.lucky_second_chance)
	var saved_duration: float = float(TN.lucky_duration)
	TN.lucky_shift_chance = 1.0
	TN.lucky_second_chance = 1.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var times: PackedFloat32Array = Lucky.plan_shift(rng, 40.0)
	_assert(times.size() <= 2, "a shift never stacks more than two strikes")
	_assert(times.size() == 2, "a hot shift can roll a second strike")
	if times.size() == 2:
		_assert(times[1] >= times[0] + saved_duration, "second strike waits until the first is gone")
	_assert(is_equal_approx(saved_duration, 8.0), "lucky window is about eight seconds")
	TN.lucky_shift_chance = saved_chance
	TN.lucky_second_chance = saved_second


func _test_cell_stays_in_grid() -> void:
	if Lucky == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var cell: Vector2i = Lucky.pick_cell(rng, 5, 4, [])
	_assert(cell.x >= 0 and cell.x < 5, "lucky cell x stays on a 5-wide pit")
	_assert(cell.y >= 0 and cell.y < 4, "lucky cell y stays on a 4-high pit")
	var dense: Vector2i = Lucky.pick_cell(rng, 16, 10, [])
	_assert(dense.x >= 0 and dense.x < 16, "lucky cell x stays on a dense pit")
	_assert(dense.y >= 0 and dense.y < 10, "lucky cell y stays on a dense pit")
	var blocked: Array[Vector2i] = []
	for x in 5:
		for y in 4:
			if x != 2 or y != 1:
				blocked.append(Vector2i(x, y))
	var only: Vector2i = Lucky.pick_cell(rng, 5, 4, blocked)
	_assert(only == Vector2i(2, 1), "lucky cell skips blocked dirt")


func _test_cash_burst_is_fat() -> void:
	if Lucky == null:
		return
	var dirt: int = int(TN.money_for_layer(0))
	var burst: int = int(Lucky.burst_payout(dirt))
	_assert(burst >= dirt * 12, "lucky cash is a fat burst, not a dirt crumb")
	_assert(burst >= 12, "lucky cash is obviously a prize")


func _test_hands_and_shovel_can_hit() -> void:
	if Lucky == null:
		return
	_assert(bool(Lucky.can_hit_with(TN.TOOL_HANDS)), "hands can hit a lucky cell")
	_assert(bool(Lucky.can_hit_with(TN.TOOL_SHOVEL)), "shovel can hit a lucky cell")
	_assert(bool(Lucky.can_hit_with(TN.TOOL_PICKAXE)), "pick can hit a lucky cell")
	_assert(not bool(Lucky.can_hit_with(TN.TOOL_BRUSH)), "brush does not collect a lucky cell")


func _test_miss_has_no_punish() -> void:
	if Lucky == null:
		return
	_assert(int(Lucky.miss_payout()) == 0, "a missed strike pays nothing and costs nothing")


func _test_hired_hand_does_not_auto_dig() -> void:
	GS.pieces.clear()
	GS.money = 0
	for item in GS.catalog:
		GS.levels[item["id"]] = 0
	GS.levels["passive_miner"] = 1
	GS.apply_upgrades()
	_assert(bool(TN.passive_miner_owned), "owning Hired Hand still only sets the late flag")
	_assert(not Lucky != null or not Lucky.has_method("tick_worker"), "lucky strike is not a hired digger")
	_assert(not GS.has_method("tick_hired_hands"), "no hired-hand auto-dig this pass")


func _assert(ok: bool, label: String) -> void:
	if ok:
		_passed += 1
		print("PASS  %s" % label)
	else:
		_failed += 1
		print("FAIL  %s" % label)
