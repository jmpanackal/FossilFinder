extends SceneTree

## Early-game start + long shop ladder.
## Run: godot --headless --path <project> -s res://tests/test_early_game_scaling.gd

var _failed: int = 0
var _passed: int = 0
var GS: Node
var TN: Node


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	GS = root.get_node("GameState")
	TN = root.get_node("Tuning")
	_test_starts_with_hands_only()
	_test_hold_starts_locked()
	_test_starting_pit_is_tiny()
	_test_shovel_is_first_rank_purchase()
	_test_pick_and_brush_require_prior_tools()
	_test_skull_locked_until_rich_bed()
	_test_scrap_income_cannot_print_midgame()
	_test_super_shovel_is_a_wall()
	_test_passive_miner_is_catalogued()
	print("early_game_scaling %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _reset() -> void:
	GS.pieces.clear()
	GS.money = 0
	GS.featured_stand_id = ""
	GS.pending_unveils.clear()
	GS.unveil_spike_left = 0.0
	GS._income_accum = 0.0
	for item in GS.catalog:
		GS.levels[item["id"]] = 0
	GS.apply_upgrades()


func _item(id: String) -> Dictionary:
	for item in GS.catalog:
		if str(item["id"]) == id:
			return item
	return {}


func _test_starts_with_hands_only() -> void:
	_reset()
	_assert(not bool(GS.owns_tool(TN.TOOL_SHOVEL)), "shovel is not owned at start")
	_assert(not bool(GS.owns_tool(TN.TOOL_PICKAXE)), "pick is not owned at start")
	_assert(not bool(GS.owns_tool(TN.TOOL_BRUSH)), "brush is not owned at start")
	var tools: Array = GS.owned_tool_ids()
	_assert(tools.size() == 1 and int(tools[0]) == int(TN.TOOL_SHOVEL), "only the hands slot is available")


func _test_hold_starts_locked() -> void:
	_reset()
	_assert(not bool(GS.hold_unlocked()), "hold-to-dig starts locked")
	GS.money = 500
	_assert(bool(GS.buy("hands_hold")), "Steady Hands can be bought")
	_assert(bool(GS.hold_unlocked()), "first hold rank unlocks holding")


func _test_starting_pit_is_tiny() -> void:
	_reset()
	_assert(int(TN.site_size_rank) == 0, "site rank starts at 0")
	var layout: Vector2i = TN.site_layout_for_rank(0)
	_assert(layout.x * layout.y <= 4, "starting pit is 1x1 or 2x2")
	_assert(layout.x <= 2 and layout.y <= 2, "starting pit is no wider than 2")


func _test_shovel_is_first_rank_purchase() -> void:
	_reset()
	var item: Dictionary = _item("shovel_click")
	_assert(not item.is_empty(), "shovel click exists")
	_assert(str(item.get("unlock_name", "")) == "Shovel", "first rank is Buy Shovel")
	_assert(int(item.get("cost", 999)) <= 30, "first shovel is cheap")
	GS.money = int(GS.cost_of("shovel_click"))
	_assert(bool(GS.buy("shovel_click")), "shovel can be bought on the first ranks of money")
	_assert(bool(GS.owns_tool(TN.TOOL_SHOVEL)), "buying rank 1 grants the shovel")


func _test_pick_and_brush_require_prior_tools() -> void:
	_reset()
	GS.money = 5000
	_assert(not bool(GS.can_buy("pick_click")), "pick is locked until shovel")
	_assert(str(GS.lock_reason("pick_click")).contains("Shovel"), "pick lock names the shovel")
	_assert(bool(GS.buy("shovel_click")), "shovel unlocks pick")
	_assert(bool(GS.can_buy("pick_click")), "pick is buyable after shovel")
	_assert(not bool(GS.can_buy("brush_speed")), "brush waits for the pick")
	_assert(bool(GS.buy("pick_click")), "pick purchase succeeds")
	_assert(bool(GS.can_buy("brush_speed")), "brush is buyable after pick")


func _test_skull_locked_until_rich_bed() -> void:
	_reset()
	_assert(not bool(GS.big_finds_unlocked()), "skull bed starts locked")
	GS.levels["rich_bed"] = 1
	GS.apply_upgrades()
	_assert(bool(GS.big_finds_unlocked()), "Rich Bed unlocks large finds")


func _test_scrap_income_cannot_print_midgame() -> void:
	_reset()
	GS.install_find("tooth", "Tooth", 1.0, true)
	var rate: float = float(GS.museum_income())
	_assert(rate < 0.08, "a clean tooth does not print mid-game cash")
	GS.set_featured_stand("triceratops")
	_assert(float(GS.museum_income()) < 0.08, "scraps cannot take the spotlight")
	var super_cost: int = int(_item("shovel_super").get("cost", 0))
	_assert(super_cost >= 700, "Super Shovel is a mid-game price")
	_assert(rate * 1200.0 < float(super_cost), "20 minutes of tooth income cannot buy Super Shovel")


func _test_super_shovel_is_a_wall() -> void:
	_reset()
	_assert(not bool(GS.tier_unlocked("shovel_super")), "Super Shovel starts behind Shovel I")
	_assert(int(_item("site_expand").get("cost", 0)) >= 400, "Wider Claim II is mid-game")
	_assert(int(_item("site_size").get("max", 0)) >= 3, "early pit is a short ladder")
	_assert(int(_item("site_expand").get("max", 0)) >= 5, "later pit is a long ladder")


func _test_passive_miner_is_catalogued() -> void:
	_reset()
	var item: Dictionary = _item("passive_miner")
	_assert(not item.is_empty(), "Hired Hand exists in the shop")
	_assert(int(item.get("tier", 0)) >= 3, "Hired Hand sits at the end of Site")
	_assert(int(item.get("cost", 0)) >= 2000, "Hired Hand is a late purchase")
	_assert(not bool(GS.tier_unlocked("passive_miner")), "Hired Hand waits behind Site II")


func _assert(ok: bool, label: String) -> void:
	if ok:
		_passed += 1
		print("PASS  %s" % label)
	else:
		_failed += 1
		print("FAIL  %s" % label)
