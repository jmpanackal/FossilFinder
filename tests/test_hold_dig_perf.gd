extends SceneTree

## Fast hold-to-dig must stay snappy without per-cell juice spam.
## Run: godot --headless --path <project> -s res://tests/test_hold_dig_perf.gd

var _failed: int = 0
var _passed: int = 0
var GS: Node
var TN: Node
var SfxNode: Node


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	GS = root.get_node("GameState")
	TN = root.get_node("Tuning")
	SfxNode = root.get_node("Sfx")
	_test_hold_interval_caps_tiny_ticks()
	_test_max_steady_shoveling_is_faster_than_rank_one()
	_test_wide_scoop_still_covers_a_fat_patch()
	_test_wide_scoop_batches_one_money_float()
	_test_sfx_throttles_hit_spam()
	print("hold_dig_perf %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _reset() -> void:
	GS.pieces.clear()
	GS.money = 0
	GS.precision_on = false
	for item in GS.catalog:
		GS.levels[item["id"]] = 0
	GS.apply_upgrades()


func _test_hold_interval_caps_tiny_ticks() -> void:
	_assert(TN.has_method("hold_interval"), "Tuning.hold_interval caps hold ticks")
	if not TN.has_method("hold_interval"):
		return
	var floor_gap: float = float(TN.hold_min_interval)
	_assert(floor_gap >= 0.05 and floor_gap <= 0.08, "min hold interval sits in the 0.05-0.08s band")
	_assert(is_equal_approx(float(TN.hold_interval(999.0)), floor_gap), "insane tick rates clamp to the floor")
	_assert(float(TN.hold_interval(2.4)) > floor_gap, "rank-1 shovel interval stays above the floor")


func _test_max_steady_shoveling_is_faster_than_rank_one() -> void:
	if not TN.has_method("hold_interval"):
		_assert(false, "max Steady Shoveling is clearly faster than rank 1")
		return
	_reset()
	GS.levels["shovel_click"] = 4
	GS.levels["shovel_hold"] = 1
	GS.apply_upgrades()
	var rank1: float = float(TN.hold_interval(float(TN.shovel_hold_tick_rate)))
	GS.levels["shovel_hold"] = 5
	GS.apply_upgrades()
	var rank5: float = float(TN.hold_interval(float(TN.shovel_hold_tick_rate)))
	_assert(rank5 < rank1, "max Steady Shoveling is clearly faster than rank 1")
	_assert(rank1 >= rank5 * 1.35, "max hold is at least a third quicker than rank 1")
	_assert(rank5 + 0.0001 >= float(TN.hold_min_interval), "max shovel interval never slips under the cap")


func _test_wide_scoop_still_covers_a_fat_patch() -> void:
	_reset()
	GS.levels["shovel_click"] = 4
	GS.levels["shovel_radius"] = 4
	GS.apply_upgrades()
	var hits: int = TN.shovel_hit_cells(Vector2i(4, 4), float(TN.shovel_radius)).size()
	_assert(hits >= 9, "Wider Scoop 4 still hits a wide cell set")


func _test_wide_scoop_batches_one_money_float() -> void:
	_reset()
	GS.levels["shovel_click"] = 4
	GS.levels["shovel_radius"] = 4
	GS.apply_upgrades()
	var script: GDScript = load("res://dig_site.gd") as GDScript
	_assert(script != null, "dig_site.gd loads after autoloads")
	if script == null:
		return
	var site: Node2D = script.new()
	root.add_child(site)
	var emits: Array[int] = []
	site.layer_cleared.connect(func(amount: int, _pos: Vector2) -> void:
		emits.append(amount)
	)
	site.current_tool = TN.TOOL_SHOVEL
	site.call("_apply_shovel", Vector2i(2, 2), 8.0, false)
	var cells: int = TN.shovel_hit_cells(Vector2i(2, 2), float(TN.shovel_radius)).size()
	_assert(cells > 1, "the strike actually covered multiple cells")
	_assert(emits.size() <= 1, "one money float per shovel tick, not one per cell")
	_assert(emits.size() == 1 and emits[0] > 0, "batched payout still pays the full scoop")
	if emits.size() == 1 and cells > 1:
		_assert(emits[0] >= cells, "batched float is the summed scoop, not a single cell")
	site.queue_free()


func _test_sfx_throttles_hit_spam() -> void:
	_assert(SfxNode.has_method("play"), "Sfx.play exists")
	if SfxNode.has_method("reset_throttle"):
		SfxNode.reset_throttle()
	var before: int = int(SfxNode.get("hit_plays")) if "hit_plays" in SfxNode else -1
	_assert(before >= 0, "Sfx counts throttled hit plays")
	if before < 0:
		return
	for _i in 24:
		SfxNode.play("hit_dirt")
	var after: int = int(SfxNode.hit_plays)
	_assert(after - before <= 2, "shovel hit SFX is throttled instead of one voice per cell")


func _assert(ok: bool, label: String) -> void:
	if ok:
		_passed += 1
		print("PASS  %s" % label)
	else:
		_failed += 1
		print("FAIL  %s" % label)
