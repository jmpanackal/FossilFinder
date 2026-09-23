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
	_test_pit_footprint_stays_fixed()
	_test_chunk_matches_surface_dirt()
	_test_site_layout_waits_for_round()
	_test_shovel_is_first_rank_purchase()
	_test_gated_shop_rows()
	_test_pick_and_brush_require_prior_tools()
	_test_skull_locked_until_rich_bed()
	_test_scrap_income_cannot_print_midgame()
	_test_super_shovel_is_a_wall()
	_test_passive_miner_is_catalogued()
	_test_wider_scoop_rank_2_hits_more_than_one_cell()
	_test_fullscreen_pixels_do_not_become_play_view()
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
	_assert(tools.size() == 1 and int(tools[0]) == int(TN.TOOL_HANDS), "only the hands slot is available")


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
	var cells: int = layout.x * layout.y
	_assert(layout.x >= 4 and layout.y >= 3, "starting pit is multiple cells")
	_assert(cells >= 12 and cells <= 24, "starting pit is a small search, not a stamp")
	_assert(layout != Vector2i(1, 1), "starting pit is never 1x1")
	_assert(layout == Vector2i(5, 4), "starting pit is 5x4")
	var grown: Vector2i = TN.site_layout_for_rank(8)
	_assert(grown.x * grown.y > cells, "Wider Claim still has room to grow")
	_assert(grown == Vector2i(16, 10), "top rank still reaches the old 16x10 site")


func _test_pit_footprint_stays_fixed() -> void:
	_reset()
	TN.view_w = 1280.0
	TN.view_h = 720.0
	TN.site_size_rank = 0
	TN.apply_site_layout()
	var start_w: float = float(TN.grid_w) * TN.cell_w
	var start_h: float = float(TN.grid_h) * TN.cell_h
	var start_cell_w: float = TN.cell_w
	var start_cell_h: float = TN.cell_h
	_assert(TN.grid_w == 5 and TN.grid_h == 4, "start still uses a 5x4 cell count")
	_assert(is_equal_approx(start_w, 16.0 * TN.base_cell_w), "start pit uses the full 1024px width")
	_assert(is_equal_approx(start_h, 10.0 * TN.base_cell_h), "start pit uses the full 400px height")
	_assert(start_cell_w > 64.0 and start_cell_h > 40.0, "start cells are larger than late-game cells")
	TN.site_size_rank = 8
	TN.apply_site_layout()
	var late_w: float = float(TN.grid_w) * TN.cell_w
	var late_h: float = float(TN.grid_h) * TN.cell_h
	_assert(TN.grid_w == 16 and TN.grid_h == 10, "late pit is 16x10 cells")
	_assert(is_equal_approx(late_w, start_w), "visual width stays the same as ranks grow")
	_assert(is_equal_approx(late_h, start_h), "visual height stays the same as ranks grow")
	_assert(TN.cell_w < start_cell_w, "more columns pack smaller cells")
	_assert(TN.cell_h < start_cell_h, "more rows pack smaller cells")
	TN.site_size_rank = 0
	TN.apply_site_layout()


func _test_chunk_matches_surface_dirt() -> void:
	var dirt: Color = TN.color_for_layer(0)
	_assert(TN.chunk_top_color().is_equal_approx(dirt), "chunk top matches surface dirt")
	_assert(TN.chunk_side_color().is_equal_approx(dirt.darkened(0.32)), "chunk sides are same dirt, darkened")
	_assert(TN.chunk_line_color().is_equal_approx(Color("241C16")), "chunk outline matches cell outlines")
	_assert(not TN.chunk_top_color().is_equal_approx(Color("2A2118")), "chunk is not the old chocolate tray")


func _test_site_layout_waits_for_round() -> void:
	_reset()
	TN.apply_site_layout()
	_assert(TN.grid_w == 5 and TN.grid_h == 4, "start layout is 5x4")
	GS.levels["site_size"] = 1
	GS.apply_upgrades()
	_assert(int(TN.site_size_rank) == 1, "rank updates on buy")
	_assert(TN.grid_w == 5 and TN.grid_h == 4, "grid size waits for the next round")
	TN.apply_site_layout()
	_assert(TN.grid_w == 6 and TN.grid_h == 4, "next round uses the larger pit")


func _test_shovel_is_first_rank_purchase() -> void:
	_reset()
	var item: Dictionary = _item("shovel_click")
	_assert(not item.is_empty(), "shovel click exists")
	_assert(str(item.get("unlock_name", "")) == "Shovel", "first rank is Buy Shovel")
	_assert(int(item.get("cost", 999)) <= 30, "first shovel is cheap")
	GS.money = int(GS.cost_of("shovel_click"))
	_assert(bool(GS.buy("shovel_click")), "shovel can be bought on the first ranks of money")
	_assert(bool(GS.owns_tool(TN.TOOL_SHOVEL)), "buying rank 1 grants the shovel")


func _test_gated_shop_rows() -> void:
	_reset()
	_assert(str(GS.shop_row_title("hands_hold")) == "Hold to Dig", "hold starts as the ability, not a rank")
	_assert(not str(GS.shop_row_title("hands_hold")).contains("/"), "hold has no 0/N before unlock")
	_assert(str(GS.shop_item_desc("hands_hold")) == "Click and hold to keep digging.", "hold unlock explains the verb")
	_assert(str(GS.shop_button_label("hands_hold")).begins_with("Unlock"), "hold button is Unlock")
	_assert(str(GS.shop_row_title("shovel_hold")) == "Hold to Dig", "shovel hold starts as the ability")
	_assert(not str(GS.shop_row_title("shovel_hold")).contains("/"), "shovel hold has no 0/N")
	_assert(str(GS.shop_button_label("shovel_hold")).begins_with("Unlock"), "shovel hold button is Unlock")
	_assert(str(GS.shop_row_title("shovel_radius")) == "Wider Scoop", "radius starts as the ability")
	_assert(not str(GS.shop_row_title("shovel_radius")).contains("/"), "radius has no 0/N")
	_assert(str(GS.shop_item_desc("shovel_radius")) == "The shovel covers more than one cell.", "radius unlock explains the extra reach")
	_assert(str(GS.shop_button_label("shovel_radius")).begins_with("Unlock"), "radius button is Unlock")
	_assert(str(GS.shop_row_title("shovel_click")) == "Shovel", "shovel tool starts without 0/N")
	_assert(str(GS.shop_button_label("shovel_click")).begins_with("Buy Shovel"), "shovel button stays Buy Shovel")
	_assert(str(GS.shop_row_title("hands_click")).contains("0 /"), "plain ranks still show 0/N")
	_assert(str(GS.shop_row_title("site_expand")).contains("0 /"), "Open Ground stays a ranked upgrade")
	_assert(str(GS.shop_button_label("hands_click")).begins_with("Buy"), "plain ranks still say Buy")
	GS.money = 5000
	_assert(bool(GS.buy("hands_hold")), "hold unlock can be bought")
	_assert(str(GS.shop_display_name("hands_hold")) == "Steady Hands", "after unlock hold uses the rank name")
	_assert(str(GS.shop_row_title("hands_hold")).contains("1 / 4"), "after unlock hold shows 1/4")
	_assert(str(GS.shop_item_desc("hands_hold")) == "Hold digs faster.", "after unlock hold describes the upgrade")
	_assert(str(GS.shop_button_label("hands_hold")).begins_with("Buy"), "after unlock hold button is Buy")
	_assert(bool(GS.buy("shovel_click")), "shovel unlock can be bought")
	_assert(str(GS.shop_row_title("shovel_click")).begins_with("Heavy Swings"), "after shovel, ranked name")
	_assert(str(GS.shop_row_title("shovel_click")).contains("1 / 6"), "after shovel shows 1/6")
	_assert(str(GS.shop_button_label("shovel_click")).begins_with("Buy  $"), "after shovel button is Buy $")
	_assert(bool(GS.buy("shovel_radius")), "radius unlock can be bought")
	_assert(str(GS.shop_row_title("shovel_radius")).contains("1 / 4"), "after unlock radius shows 1/4")
	_assert(str(GS.shop_item_desc("shovel_radius")) == "Covers more ground.", "after unlock radius describes the upgrade")
	_assert(str(GS.shop_button_label("shovel_radius")).begins_with("Buy"), "after unlock radius button is Buy")
	_assert(bool(GS.buy("shovel_hold")), "shovel hold unlock can be bought")
	_assert(str(GS.shop_display_name("shovel_hold")) == "Steady Shoveling", "after unlock shovel hold uses the rank name")
	_assert(str(GS.shop_row_title("shovel_hold")).contains("1 / 5"), "after unlock shovel hold shows 1/5")


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
	_assert(rate >= 0.05, "a clean tooth is a visible tick")
	_assert(rate < 0.15, "a clean tooth does not print mid-game cash")
	_assert(bool(GS.set_featured_stand("small_finds")), "a tooth can be featured in its case")
	var featured: float = float(GS.museum_income())
	_assert(featured >= 0.10, "a featured tooth is a visible tick")
	_assert(featured < 0.30, "a featured tooth still does not print mid-game cash")
	var super_cost: int = int(_item("shovel_super").get("cost", 0))
	_assert(super_cost >= 700, "Super Shovel is a mid-game price")
	_assert(rate * 1200.0 < float(super_cost), "20 minutes of tooth income cannot buy Super Shovel")


func _test_super_shovel_is_a_wall() -> void:
	_reset()
	_assert(not bool(GS.tier_unlocked("shovel_super")), "Super Shovel starts behind Shovel I")
	_assert(int(_item("site_expand").get("cost", 0)) >= 400, "Wider Claim II is mid-game")
	_assert(int(_item("site_size").get("max", 0)) >= 3, "early pit is a short ladder")
	_assert(int(_item("site_expand").get("max", 0)) >= 5, "later pit is a long ladder")


func _count_shovel_cells(center: Vector2i, radius: float) -> int:
	var count: int = 0
	var reach: int = int(ceili(radius))
	for x in range(center.x - reach, center.x + reach + 1):
		for y in range(center.y - reach, center.y + reach + 1):
			if Vector2(x, y).distance_to(Vector2(center)) <= radius:
				count += 1
	return count


func _test_wider_scoop_rank_2_hits_more_than_one_cell() -> void:
	_reset()
	GS.levels["shovel_click"] = 1
	GS.levels["shovel_radius"] = 2
	GS.precision_on = false
	GS.apply_upgrades()
	_assert(TN.shovel_radius >= 1.0, "Wider Scoop 2 reach is at least one cell")
	var hits: int = _count_shovel_cells(Vector2i(2, 2), float(TN.shovel_radius))
	_assert(hits > 1, "shovel damages more than one cell at Wider Scoop 2")
	_assert(hits >= 5, "rank 2 is at least a plus or 3-wide")
	GS.precision_on = true
	_assert(_count_shovel_cells(Vector2i(2, 2), 0.0) == 1, "precision still pinches to one cell")
	GS.precision_on = false


func _test_fullscreen_pixels_do_not_become_play_view() -> void:
	var design: Vector2 = TN.play_view_size(Vector2(1280, 720))
	_assert(design.is_equal_approx(Vector2(1280, 720)), "design view stays 1280x720")
	var full: Vector2 = TN.play_view_size(Vector2(1920, 1080))
	_assert(full.is_equal_approx(Vector2(1280, 720)), "1080p pixels do not become the play view")
	var huge: Vector2 = TN.play_view_size(Vector2(3840, 2160))
	_assert(huge.is_equal_approx(Vector2(1280, 720)), "4K pixels do not become the play view")
	var wide: Vector2 = TN.play_view_size(Vector2(1706, 720))
	_assert(wide.is_equal_approx(Vector2(1706, 720)), "ultrawide expand can keep extra design width")
	TN.view_w = 1920.0
	TN.view_h = 1080.0
	TN.site_size_rank = 0
	TN.apply_site_layout()
	_assert(is_equal_approx(float(TN.grid_w) * TN.cell_w, 16.0 * TN.base_cell_w), "fullscreen keeps the 1024px pit")
	_assert(is_equal_approx(float(TN.grid_h) * TN.cell_h, 10.0 * TN.base_cell_h), "fullscreen keeps the 400px pit")
	TN.view_w = 1280.0
	TN.view_h = 720.0
	TN.apply_site_layout()


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
