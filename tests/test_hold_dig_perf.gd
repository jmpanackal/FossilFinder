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
	_test_strike_punches_damaged_cells()
	_test_hold_refreshes_one_punch()
	_test_punch_profiles_by_material()
	_test_hands_aim_is_todays_fat_punch()
	_test_wide_scoop_aim_stays_at_least_as_fat_as_hands()
	_test_neighbors_echo_smaller_and_shorter()
	_test_huge_scoop_echoes_all_with_falloff()
	_test_hold_refreshes_aim_echoes_stay_cheap()
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


func _make_site() -> Node2D:
	var script: GDScript = load("res://dig_site.gd") as GDScript
	_assert(script != null, "dig_site.gd loads for punch tests")
	if script == null:
		return null
	var site: Node2D = script.new()
	root.add_child(site)
	return site


func _blank_site() -> Node2D:
	var site := _make_site()
	if site == null:
		return null
	site.fossil_cells.clear()
	site.finds.clear()
	site.exposed_cells.clear()
	site.cleanliness.clear()
	return site


func _punch_weight(rec: Variant) -> float:
	if rec is Vector3:
		return float(rec.z)
	return 1.0


func _test_strike_punches_damaged_cells() -> void:
	_reset()
	GS.levels["shovel_click"] = 4
	GS.levels["shovel_radius"] = 1
	GS.apply_upgrades()
	var site := _blank_site()
	if site == null:
		return
	site.current_tool = TN.TOOL_SHOVEL
	var center := Vector2i(2, 2)
	site.call("_apply_shovel", center, 8.0, false)
	var cells: int = TN.shovel_hit_cells(center, float(TN.shovel_radius)).size()
	var punches: Variant = site.get("_punches")
	_assert(punches is Dictionary and punches.size() > 1, "small scoop neighbors still get an echo punch")
	if punches is Dictionary:
		_assert(punches.size() <= cells, "punch count never exceeds the cells that were struck")
		_assert(punches.has(center), "the aimed cell always punches")
	site.queue_free()


func _test_hold_refreshes_one_punch() -> void:
	var site := _make_site()
	if site == null:
		return
	_assert(site.has_method("_begin_punch") and site.has_method("_tick_punches"), "hold refresh uses one punch timer")
	if not site.has_method("_begin_punch"):
		site.queue_free()
		return
	site.call("_begin_punch", Vector2i(1, 1), 0)
	site.call("_tick_punches", 0.05)
	var punches: Dictionary = site.get("_punches")
	_assert(punches.size() == 1, "one cell keeps one punch record")
	if punches.size() == 1:
		var aged: float = float(punches[Vector2i(1, 1)].x)
		_assert(aged >= 0.049, "the punch ages while you wait")
	site.call("_begin_punch", Vector2i(1, 1), 0)
	punches = site.get("_punches")
	_assert(punches.size() == 1, "hold refresh does not stack punch records")
	if punches.size() == 1:
		var restarted: float = float(punches[Vector2i(1, 1)].x)
		_assert(restarted < 0.001, "hold refresh restarts the same punch timer")
	site.call("_tick_punches", 0.25)
	punches = site.get("_punches")
	_assert(punches.is_empty(), "the punch dies after the short squash")
	site.queue_free()


func _test_punch_profiles_by_material() -> void:
	var site := _make_site()
	if site == null:
		return
	_assert(site.has_method("_punch_scale"), "punch scale lives on the dig site")
	if not site.has_method("_punch_scale"):
		site.queue_free()
		return
	var dirt: Vector2 = site.call("_punch_scale", 0, 0.02)
	var firm: Vector2 = site.call("_punch_scale", 1, 0.02)
	var bone: Vector2 = site.call("_punch_scale", 2, 0.02)
	_assert(dirt.y < firm.y, "dirt squashes softer than packed/rock")
	_assert(dirt.x > firm.x, "dirt stretches wider than packed/rock")
	_assert(absf(1.0 - bone.y) > 0.01, "bone flinches immediately")
	_assert(site.call("_punch_scale", 2, 0.08) == Vector2.ONE, "bone flinch is over by 80ms")
	_assert(site.call("_punch_scale", 0, 0.08) != Vector2.ONE, "dirt is still springing at 80ms")
	site.call("_begin_punch", Vector2i(0, 0), 2)
	var punches: Dictionary = site.get("_punches")
	_assert(punches.has(Vector2i(0, 0)) and int(punches[Vector2i(0, 0)].y) == 2, "bone uses the sharp punch kind")
	site.queue_free()


func _test_hands_aim_is_todays_fat_punch() -> void:
	_reset()
	var site := _blank_site()
	if site == null:
		return
	site.current_tool = TN.TOOL_HANDS
	var center := Vector2i(2, 2)
	site.call("_apply_shovel", center, 8.0, true)
	var punches: Dictionary = site.get("_punches")
	_assert(punches.size() == 1 and punches.has(center), "hands punch only the aimed cell")
	if punches.has(center):
		_assert(_punch_weight(punches[center]) >= 0.99, "hands keep today's full-strength punch")
	site.call("_tick_punches", 0.02)
	var rect: Rect2 = site.call("_punched_rect", Rect2(0, 0, 64, 64), center)
	_assert(rect.size.y < 64.0 * 0.92, "hands squash is still the fat cookie punch")
	site.queue_free()


func _test_wide_scoop_aim_stays_at_least_as_fat_as_hands() -> void:
	_reset()
	var hands := _blank_site()
	if hands == null:
		return
	hands.current_tool = TN.TOOL_HANDS
	hands.call("_apply_shovel", Vector2i(2, 2), 8.0, true)
	hands.call("_tick_punches", 0.02)
	var hands_rect: Rect2 = hands.call("_punched_rect", Rect2(0, 0, 64, 64), Vector2i(2, 2))
	hands.queue_free()
	GS.levels["shovel_click"] = 4
	GS.levels["shovel_radius"] = 4
	GS.apply_upgrades()
	var scoop := _blank_site()
	if scoop == null:
		return
	scoop.current_tool = TN.TOOL_SHOVEL
	var center := Vector2i(2, 2)
	scoop.call("_apply_shovel", center, 8.0, false)
	var punches: Dictionary = scoop.get("_punches")
	_assert(punches.has(center), "wide scoop still punches the aimed cell")
	if punches.has(center):
		_assert(_punch_weight(punches[center]) >= 0.99, "max scoop aim is not scaled down with the crowd")
	scoop.call("_tick_punches", 0.02)
	var aim_rect: Rect2 = scoop.call("_punched_rect", Rect2(0, 0, 64, 64), center)
	_assert(aim_rect.size.y <= hands_rect.size.y + 0.25, "max scoop aim stays at least as fat as hands")
	scoop.queue_free()


func _test_neighbors_echo_smaller_and_shorter() -> void:
	_reset()
	GS.levels["shovel_click"] = 4
	GS.levels["shovel_radius"] = 1
	GS.apply_upgrades()
	var site := _blank_site()
	if site == null:
		return
	site.current_tool = TN.TOOL_SHOVEL
	var center := Vector2i(2, 2)
	var neighbor := Vector2i(3, 2)
	site.call("_apply_shovel", center, 8.0, false)
	var punches: Dictionary = site.get("_punches")
	_assert(punches.has(center) and punches.has(neighbor), "a plus-scoop still echoes the adjacent cell")
	if punches.has(center) and punches.has(neighbor):
		var aim_w: float = _punch_weight(punches[center])
		var echo_w: float = _punch_weight(punches[neighbor])
		_assert(echo_w < aim_w * 0.7, "neighbor echo is clearly smaller than the aim punch")
	site.call("_tick_punches", 0.02)
	var aim_rect: Rect2 = site.call("_punched_rect", Rect2(0, 0, 64, 64), center)
	var echo_rect: Rect2 = site.call("_punched_rect", Rect2(0, 0, 64, 64), neighbor)
	_assert(aim_rect.size.y + 0.4 < echo_rect.size.y, "aim squashes harder than the neighbor echo")
	site.call("_tick_punches", 0.05)
	punches = site.get("_punches")
	_assert(punches.has(center), "aim is still springing after the echo dies")
	_assert(not punches.has(neighbor), "neighbor echo is shorter than the aim punch")
	site.queue_free()


func _test_huge_scoop_echoes_all_with_falloff() -> void:
	_reset()
	GS.levels["shovel_click"] = 4
	GS.levels["shovel_radius"] = 4
	GS.apply_upgrades()
	var site := _blank_site()
	if site == null:
		return
	site.current_tool = TN.TOOL_SHOVEL
	var center := Vector2i(2, 2)
	var neighbor := Vector2i(3, 2)
	var hits: Array = TN.shovel_hit_cells(center, float(TN.shovel_radius))
	_assert(hits.size() > 9, "max scoop covers more than nine cells")
	site.call("_apply_shovel", center, 8.0, false)
	var punches: Dictionary = site.get("_punches")
	_assert(punches.has(center), "huge scoop still punches the aimed cell")
	var grounded: int = 0
	var far := Vector2i(-1, -1)
	var far_dist: float = 0.0
	for cell in hits:
		if cell.x < 0 or cell.x >= int(TN.grid_w) or cell.y < 0 or cell.y >= int(TN.grid_h):
			continue
		grounded += 1
		var dist: float = Vector2(cell).distance_to(Vector2(center))
		if dist > far_dist:
			far_dist = dist
			far = cell
	_assert(far_dist > 1.5, "max scoop has cells past the adjacent ring")
	_assert(punches.size() == grounded, "every damaged scoop cell echoes, not just four neighbors")
	_assert(punches.has(neighbor) and punches.has(far), "close and far scoop cells both punch")
	if punches.has(center):
		_assert(_punch_weight(punches[center]) >= 0.99, "aimed cell keeps the fat punch")
	var near_w: float = 0.0
	var far_w: float = 0.0
	if punches.has(neighbor):
		near_w = _punch_weight(punches[neighbor])
		_assert(near_w < 0.7, "adjacent echo stays clearly smaller than the aim")
		_assert(near_w > 0.22, "adjacent echo is a medium ripple, not a rim tick")
	if punches.has(far):
		far_w = _punch_weight(punches[far])
		_assert(far_w > 0.0, "the scoop rim still gets a punch record")
		_assert(far_w < near_w * 0.55, "rim echo is much weaker than the adjacent echo")
		_assert(far_w < 0.16, "rim of a huge scoop is a tiny tick")
	site.call("_tick_punches", 0.02)
	var aim_rect: Rect2 = site.call("_punched_rect", Rect2(0, 0, 64, 64), center)
	var far_rect: Rect2 = site.call("_punched_rect", Rect2(0, 0, 64, 64), far)
	_assert(aim_rect.size.y + 1.2 < far_rect.size.y, "aim squash is obviously fatter than the rim tick")
	site.call("_apply_shovel", center, 8.0, false)
	punches = site.get("_punches")
	_assert(punches.has(center) and float(punches[center].x) < 0.001, "hold refresh restarts the aim punch")
	if punches.has(far):
		_assert(_punch_weight(punches[far]) < near_w * 0.55 + 0.001, "hold refresh keeps the same distance falloff")
	site.queue_free()


func _test_hold_refreshes_aim_echoes_stay_cheap() -> void:
	_reset()
	GS.levels["shovel_click"] = 4
	GS.levels["shovel_radius"] = 1
	GS.apply_upgrades()
	var site := _blank_site()
	if site == null:
		return
	site.current_tool = TN.TOOL_SHOVEL
	var center := Vector2i(2, 2)
	var neighbor := Vector2i(3, 2)
	site.call("_apply_shovel", center, 8.0, false)
	site.call("_tick_punches", 0.03)
	site.call("_apply_shovel", center, 8.0, false)
	var punches: Dictionary = site.get("_punches")
	_assert(punches.has(center), "hold refresh keeps the aim punch")
	if punches.has(center):
		_assert(float(punches[center].x) < 0.001, "hold refresh restarts the aim punch each tick")
		_assert(_punch_weight(punches[center]) >= 0.99, "hold refresh keeps the fat aim punch")
	if punches.has(neighbor):
		_assert(_punch_weight(punches[neighbor]) < 0.7, "hold echoes stay cheap instead of matching aim")
	else:
		_assert(false, "hold still echoes the adjacent cell on a small scoop")
	site.queue_free()


func _assert(ok: bool, label: String) -> void:
	if ok:
		_passed += 1
		print("PASS  %s" % label)
	else:
		_failed += 1
		print("FAIL  %s" % label)
