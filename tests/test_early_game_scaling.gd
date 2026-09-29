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
	_test_each_depth_has_its_own_dirt_color()
	_test_pick_stone_breaks_from_shovel_dirt()
	_test_pick_scales_like_the_shovel()
	_test_wrong_tool_plays_refuse()
	_test_chunk_sides_show_the_dirt_stack()
	_test_site_layout_waits_for_round()
	_test_shovel_is_first_rank_purchase()
	_test_gated_shop_rows()
	_test_pick_and_brush_require_prior_tools()
	_test_skull_locked_until_rich_bed()
	_test_scrap_income_cannot_print_midgame()
	_test_super_shovel_is_a_wall()
	_test_shovel_and_pick_one_take_twenty_minutes()
	_test_super_and_crowds_price_band()
	_test_mid_rows_last_in_late_band()
	_test_comfort_rows_pay_a_cent_and_cost_more()
	_test_late_ticket_ranks_cost_more()
	_test_existing_shop_reaches_millions_before_apex()
	_test_apex_chapters_exist_and_gate()
	_test_apex_ranks_add_power()
	_test_first_tool_buys_stay_early_victories()
	_test_passive_miner_is_catalogued()
	_test_wider_scoop_rank_2_hits_more_than_one_cell()
	_test_pick_wider_scoop_scales_like_shovel()
	_test_fullscreen_pixels_do_not_become_play_view()
	_test_footer_chrome_stays_below_pit()
	_test_find_footer_stays_on_screen()
	_test_extracted_preview_keeps_fossil_value()
	_test_find_toast_does_not_cover_footer()
	_test_find_footer_shows_one_extract_readout()
	_test_dirt_label_rises_as_brushed()
	_test_find_chip_keeps_related_stats_together()
	_test_fully_brushed_chip_stays_complete_and_priced()
	_test_extract_does_not_stack_a_found_toast()
	_test_two_pit_finds_make_two_footer_chips()
	_test_buried_finds_do_not_make_footer_chips()
	_test_find_chips_sit_in_footer_band()
	_test_full_uncover_flies_to_footer_chip()
	_test_hands_stay_the_careful_one_cell_tool()
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
	_assert(TN.has_method("chunk_line_width"), "Tuning exposes the pit outline width")
	if TN.has_method("chunk_line_width"):
		_assert(float(TN.chunk_line_width()) <= 1.5, "pit outline is a thin crease, not a 3px bar")
	_assert(not TN.chunk_top_color().is_equal_approx(Color("2A2118")), "chunk is not the old chocolate tray")


func _test_each_depth_has_its_own_dirt_color() -> void:
	_assert(int(TN.layer_count) == 24, "depth stay is still 24 layers")
	_assert(int(TN.material_at_layer(0)) == int(TN.MAT_LOOSE), "surface is still loose dirt")
	_assert(int(TN.material_at_layer(6)) == int(TN.MAT_PACKED), "mid stack is still packed")
	_assert(int(TN.material_at_layer(12)) == int(TN.MAT_CLAY), "lower stack is still clay")
	_assert(int(TN.material_at_layer(18)) == int(TN.MAT_ROCK), "floor is still rock")
	var last: Color = TN.color_for_layer(0)
	for layer in range(1, int(TN.layer_count)):
		var next: Color = TN.color_for_layer(layer)
		var step: float = absf(last.r - next.r) + absf(last.g - next.g) + absf(last.b - next.b)
		_assert(not last.is_equal_approx(next), "layer %d is not a copy of the layer above" % layer)
		_assert(step >= 0.055, "layer %d is a visible step down the hole" % layer)
		_assert(next.get_luminance() > 0.05, "layer %d stays readable dirt, not a black hole" % layer)
		last = next
	_assert(TN.color_for_layer(0).g > TN.color_for_layer(int(TN.layer_count) - 1).g, "the hole cools from sand toward stone")


func _test_pick_stone_breaks_from_shovel_dirt() -> void:
	var dirt: Color = TN.color_for_layer(11)
	var stone: Color = TN.color_for_layer(12)
	var seam: float = absf(dirt.r - stone.r) + absf(dirt.g - stone.g) + absf(dirt.b - stone.b)
	_assert(int(TN.material_at_layer(11)) == int(TN.MAT_PACKED), "layer 11 is still shovel dirt")
	_assert(int(TN.material_at_layer(12)) == int(TN.MAT_CLAY), "layer 12 is still pick stone")
	_assert(seam >= 0.22, "first pick layer is not another brown")
	_assert(dirt.r > dirt.b + 0.08, "last shovel layer stays warm dirt")
	_assert(stone.b >= stone.r - 0.02, "first pick layer is cool stone")


func _test_pick_scales_like_the_shovel() -> void:
	_reset()
	GS.levels["shovel_click"] = 1
	GS.levels["pick_click"] = 1
	GS.apply_upgrades()
	_assert(TN.matrix_dirt_chance <= 0.52, "dirt is not a 94% rain")
	_assert(TN.matrix_stone_chance >= 0.54, "stone hides finds more often than the old 42%")
	_assert(TN.matrix_stone_chance >= TN.matrix_dirt_chance, "stone pops at least as often as dirt")
	_assert(TN.pickaxe_splash_mult >= 0.69, "pick splash chips neighbors")
	var fresh_clay: float = float(TN.damage_for(TN.TOOL_PICKAXE, 12)) * TN.pickaxe_click_mult
	_assert(fresh_clay < float(TN.hp_for_layer(12)), "a fresh pick still takes more than one hit on clay")
	var shovel_base: float = TN.shovel_click_mult
	var pick_base: float = TN.pickaxe_click_mult
	GS.levels["shovel_click"] = 2
	GS.levels["pick_click"] = 2
	GS.apply_upgrades()
	_assert(is_equal_approx(TN.shovel_click_mult - shovel_base, 0.20), "one shovel rank is +0.20 click")
	_assert(is_equal_approx(TN.pickaxe_click_mult - pick_base, 0.20), "one pick rank matches shovel click")
	GS.levels["pick_click"] = 6
	GS.levels["pick_hold"] = 5
	GS.levels["shovel_click"] = 6
	GS.levels["shovel_hold"] = 5
	GS.apply_upgrades()
	_assert(is_equal_approx(TN.pickaxe_click_mult - pick_base, TN.shovel_click_mult - shovel_base), "maxed pick click ranks match the shovel")
	_assert(TN.pickaxe_hold_tick_rate >= 5.0, "maxed pick hold is in the shovel neighborhood")
	var clay_hit: float = float(TN.damage_for(TN.TOOL_PICKAXE, 12)) * TN.pickaxe_click_mult
	var rock_hit: float = float(TN.damage_for(TN.TOOL_PICKAXE, 18)) * TN.pickaxe_click_mult
	_assert(clay_hit >= float(TN.hp_for_layer(12)), "maxed tier-1 pick one-shots clay")
	_assert(rock_hit >= float(TN.hp_for_layer(18)), "maxed tier-1 pick one-shots rock")
	_assert(float(TN.damage_for(TN.TOOL_PICKAXE, 0)) < float(TN.damage_for(TN.TOOL_SHOVEL, 0)), "pick stays weaker on dirt than the shovel")
	var splash: float = float(TN.pickaxe_cell_damage(12, true, TN.pickaxe_click_mult))
	_assert(splash >= float(TN.hp_for_layer(12)) * 0.55, "splash is a real chip, not a tickle")
	var loose_pick: float = float(TN.damage_for(TN.TOOL_PICKAXE, 0)) * TN.pickaxe_click_mult
	var packed_pick: float = float(TN.damage_for(TN.TOOL_PICKAXE, 6)) * TN.pickaxe_click_mult
	_assert(loose_pick < float(TN.hp_for_layer(0)), "even a maxed pick does not tear loose dirt")
	_assert(packed_pick < float(TN.hp_for_layer(6)), "even a maxed pick does not tear packed dirt")


func _test_wrong_tool_plays_refuse() -> void:
	_assert(TN.has_method("tool_works_on"), "Tuning says which tool fits a layer")
	if not TN.has_method("tool_works_on"):
		return
	_assert(bool(TN.tool_works_on(TN.TOOL_SHOVEL, 0)), "shovel works on loose dirt")
	_assert(bool(TN.tool_works_on(TN.TOOL_HANDS, 5)), "hands work on dirt")
	_assert(not bool(TN.tool_works_on(TN.TOOL_SHOVEL, 12)), "shovel does not work on clay")
	_assert(not bool(TN.tool_works_on(TN.TOOL_PICKAXE, 5)), "pick does not work on dirt")
	_assert(bool(TN.tool_works_on(TN.TOOL_PICKAXE, 12)), "pick works on clay")
	_assert(bool(TN.tool_works_on(TN.TOOL_PICKAXE, 18)), "pick works on rock")
	var SfxNode: Node = root.get_node("Sfx")
	var tones: Dictionary = SfxNode.get("_TONES") as Dictionary
	_assert(tones.has("tool_refuse"), "Sfx has a refuse clack")
	var site_script: Script = load("res://dig_site.gd") as Script
	_assert(site_script != null, "dig site loads for refuse sound")
	if site_script == null:
		return
	var site: Node = site_script.new()
	root.add_child(site)
	site.set("current_tool", TN.TOOL_SHOVEL)
	if SfxNode.has_method("reset_throttle"):
		SfxNode.reset_throttle()
	site.call("_play_hit", 18)
	_assert(str(SfxNode.get("last_id")) == "tool_refuse", "shovel on rock plays the refuse clack")
	site.call("_play_hit", 0)
	_assert(str(SfxNode.get("last_id")) == "hit_dirt", "shovel on dirt still thuds")
	site.set("current_tool", TN.TOOL_PICKAXE)
	if SfxNode.has_method("reset_throttle"):
		SfxNode.reset_throttle()
	site.call("_play_hit", 2)
	_assert(str(SfxNode.get("last_id")) == "tool_refuse", "pick on dirt plays the refuse clack")
	site.queue_free()


func _test_chunk_sides_show_the_dirt_stack() -> void:
	var src: String = FileAccess.get_file_as_string("res://dig_site.gd")
	_assert(src.find("func _draw_strata_stack") >= 0, "pit paints remaining dirt as a visible stack")
	_assert(src.find("_draw_strata_stack(") >= 0, "chunk faces actually call the stack painter")
	var north_fn: String = src
	var start: int = src.find("func _draw_north_face")
	if start >= 0:
		north_fn = src.substr(start, 900)
	_assert(north_fn.find("band * float(i)") < 0, "north wall is not three fake shade bands")


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
	_assert(is_equal_approx(featured, rate), "featuring without ranks does not multiply")
	_assert(featured >= 0.05, "a featured tooth is a visible tick")
	_assert(featured < 0.15, "a featured tooth still does not print mid-game cash")
	var super_cost: int = int(_item("shovel_super").get("cost", 0))
	_assert(super_cost >= 3000, "Super Shovel is a mid-game price")
	_assert(rate * 1200.0 < float(super_cost), "20 minutes of tooth income cannot buy Super Shovel")


func _test_super_shovel_is_a_wall() -> void:
	_reset()
	_assert(not bool(GS.tier_unlocked("shovel_super")), "Super Shovel starts behind Shovel I")
	_assert(int(_item("site_expand").get("cost", 0)) >= 400, "Wider Claim II is mid-game")
	_assert(int(_item("site_size").get("max", 0)) >= 3, "early pit is a short ladder")
	_assert(int(_item("site_expand").get("max", 0)) >= 5, "later pit is a long ladder")


func _chapter_total(cat: String, tier: int) -> int:
	var total: int = 0
	for item in GS.catalog:
		if str(item.get("cat", "")) != cat or int(item.get("tier", 1)) != tier:
			continue
		total += _row_total(str(item["id"]))
	return total


func _row_total(id: String) -> int:
	var item: Dictionary = _item(id)
	if item.is_empty():
		return 0
	var saved: int = int(GS.levels.get(id, 0))
	var total: int = 0
	for rank in int(item.get("max", 1)):
		GS.levels[id] = rank
		total += int(GS.cost_of(id))
	GS.levels[id] = saved
	return total


func _row_last(id: String) -> int:
	var item: Dictionary = _item(id)
	if item.is_empty():
		return 0
	var saved: int = int(GS.levels.get(id, 0))
	GS.levels[id] = maxi(0, int(item.get("max", 1)) - 1)
	var cost: int = int(GS.cost_of(id))
	GS.levels[id] = saved
	return cost


func _test_shovel_and_pick_one_take_twenty_minutes() -> void:
	_reset()
	GS.install_find("tooth", "Tooth", 1.0, true)
	var tooth_rate: float = float(GS.museum_income())
	_assert(tooth_rate >= 0.05 and tooth_rate < 0.15, "first tooth is still the early toaster")
	var shovel_i: int = _chapter_total("Shovel", 1)
	var pick_i: int = _chapter_total("Pickaxe", 1)
	_assert(float(shovel_i) > tooth_rate * 600.0, "tooth-only AFK cannot max Shovel I in 10 minutes")
	_assert(float(pick_i) > tooth_rate * 600.0, "tooth-only AFK cannot max Pickaxe I in 10 minutes")
	# Dirt/matrix + first tooth while digging, not a $30/s hall. Current Shovel I
	# dumps in ~10 minutes at this rate; the stretch should need ≥20 and still
	# finish in ~25–40.
	const EARLY_PLAY := 4.4
	_assert(float(shovel_i) > EARLY_PLAY * 600.0, "Shovel I cannot be maxed in 10 minutes of early play")
	_assert(float(shovel_i) >= EARLY_PLAY * 1200.0, "Shovel I takes at least 20 minutes of early play")
	_assert(float(shovel_i) <= EARLY_PLAY * 2400.0, "Shovel I can still be maxed in about 40 minutes of early play")
	_assert(float(pick_i) > EARLY_PLAY * 600.0, "Pickaxe I cannot be maxed in 10 minutes of early play")
	_assert(float(pick_i) >= EARLY_PLAY * 1200.0, "Pickaxe I takes at least 20 minutes of early play")


func _test_super_and_crowds_price_band() -> void:
	_reset()
	for id in ["shovel_super", "pick_super", "brush_master", "crowds"]:
		var first: int = int(_item(id).get("cost", 0))
		var last: int = _row_last(id)
		_assert(first >= 3000 and first <= 5000, "%s first buy is $3k–$5k" % id)
		_assert(last >= 80000 and last <= 200000, "%s last buy is $80k–$200k" % id)


func _test_mid_rows_last_in_late_band() -> void:
	_reset()
	for id in ["shovel_soft", "restoration", "site_expand", "money_mult"]:
		var last: int = _row_last(id)
		_assert(last >= 25000 and last <= 50000, "%s last buy is $25k–$50k" % id)
	var museum_i: int = _chapter_total("Museum", 1)
	_assert(museum_i >= 34000 and museum_i <= 40000, "Museum I chapter is about $35–40k")
	var site_i: int = _chapter_total("Site", 1)
	_assert(site_i >= 3000 and site_i <= 4000, "Site I chapter is about $3–4k")


func _test_comfort_rows_pay_a_cent_and_cost_more() -> void:
	_reset()
	_assert(is_equal_approx(float(TN.donation_base), 0.02), "donation_base stays $0.02")
	_assert(str(GS.shop_effect_line("lighting")) == "+$0.01 per visitor", "Warm Lights this-buy is +$0.01 per visitor")
	_assert(str(GS.shop_effect_line("benches")) == "+$0.01 per visitor", "Benches this-buy is +$0.01 per visitor")
	_assert(str(GS.shop_effect_line("labels")) == "+$0.01 per visitor", "Clear Labels this-buy is +$0.01 per visitor")
	_assert(str(GS.shop_effect_line("gift_shop")) == "+$0.02 per visitor", "Gift Counter this-buy is +$0.02 per visitor")
	# Package C snapshot: lighting 200/3200, benches 180/2880, labels 900/19503, gift 1800/44570.
	_assert(int(_item("lighting").get("cost", 0)) > 200, "Warm Lights first buy rose with the cent floor")
	_assert(_row_last("lighting") > 3200, "Warm Lights last buy rose with the cent floor")
	_assert(int(_item("benches").get("cost", 0)) > 180, "Benches first buy rose with the cent floor")
	_assert(_row_last("benches") > 2880, "Benches last buy rose with the cent floor")
	_assert(int(_item("labels").get("cost", 0)) > 900, "Clear Labels first buy rose with the cent floor")
	_assert(_row_last("labels") > 19503, "Clear Labels last buy rose with the cent floor")
	_assert(int(_item("gift_shop").get("cost", 0)) > 1800, "Gift Counter first buy rose with the cent floor")
	_assert(_row_last("gift_shop") > 44570, "Gift Counter last buy rose with the cent floor")
	_assert(int(_item("lighting").get("max", 0)) == 5, "Warm Lights max ranks stay 5")
	_assert(int(_item("benches").get("max", 0)) == 5, "Benches max ranks stay 5")
	_assert(int(_item("labels").get("max", 0)) == 6, "Clear Labels max ranks stay 6")
	_assert(int(_item("gift_shop").get("max", 0)) == 6, "Gift Counter max ranks stay 6")
	_assert(int(_item("shovel_super").get("cost", 0)) == 4000, "Super Shovel first buy is unchanged")
	_assert(int(_item("shovel_titan").get("cost", 0)) == 80000, "Titan Shovel first buy is unchanged")
	_assert(int(_item("blockbuster_ticket").get("cost", 0)) == 120000, "Box Office first buy is unchanged")


func _per_visitor_dollars(line: String) -> float:
	var marker := " per visitor"
	var end: int = line.find(marker)
	if end < 0:
		return 0.0
	var start: int = line.rfind("$", end)
	if start < 0:
		return 0.0
	return float(line.substr(start + 1, end - start - 1))


func _test_late_ticket_ranks_cost_more() -> void:
	_reset()
	# Live catalog before juicier late tickets: labels 69344, gift 158470, box 2267482.
	_assert(_row_last("labels") > 69344, "Clear Labels last buy rose with juicier late ranks")
	_assert(_row_last("gift_shop") > 158470, "Gift Counter last buy rose with juicier late ranks")
	_assert(_row_last("blockbuster_ticket") > 2267482, "Box Office last buy rose with juicier late ranks")
	_assert(_row_last("gift_shop") >= 632000, "last Gift cost rose about 5x with a 5x last-rank ticket")
	_assert(_row_last("blockbuster_ticket") >= 1000000 and _row_last("blockbuster_ticket") <= 3000000, "Box Office last buy stays in the $1–3M band")
	_assert(int(_item("shovel_super").get("cost", 0)) == 4000, "Super Shovel first buy stays $4k")
	_assert(int(_item("shovel_titan").get("cost", 0)) == 80000, "Titan Shovel first buy stays $80k")
	_assert(int(_item("blockbuster_ticket").get("cost", 0)) == 120000, "Box Office first buy stays $120k")
	GS.levels["gift_shop"] = 5
	GS.levels["blockbuster_ticket"] = 5
	GS.apply_upgrades()
	_assert(_per_visitor_dollars(str(GS.shop_effect_line("gift_shop"))) + 0.0001 >= 0.05, "last Gift this-buy is at least +$0.05 per visitor")
	_assert(_per_visitor_dollars(str(GS.shop_effect_line("blockbuster_ticket"))) + 0.0001 >= 0.10, "last Box Office this-buy is at least +$0.10 per visitor")


func _test_existing_shop_reaches_millions_before_apex() -> void:
	_reset()
	var apex := {
		"hands_craft": true,
		"hands_swift": true,
		"round_marathon": true,
		"prime_bed": true,
		"shovel_titan": true,
		"pick_titan": true,
		"blockbuster_ticket": true,
		"blockbuster_crowd": true,
		"blockbuster_hours": true,
		"blockbuster_feature": true,
	}
	var existing: int = 0
	var whole: int = 0
	for item in GS.catalog:
		var id: String = str(item["id"])
		var total: int = _row_total(id)
		whole += total
		if not apex.has(id):
			existing += total
	_assert(existing >= 1500000 and existing <= 4000000, "existing shop lands at millions before apex chapters")
	_assert(whole > existing, "apex chapters push the ceiling into the millions")
	_assert(whole >= 3000000, "full ladder including apex reaches millions")


func _test_apex_chapters_exist_and_gate() -> void:
	_reset()
	var rows := [
		{"id": "hands_craft", "cat": "Hands", "tier": 2},
		{"id": "hands_swift", "cat": "Hands", "tier": 2},
		{"id": "round_marathon", "cat": "Site", "tier": 3},
		{"id": "prime_bed", "cat": "Site", "tier": 3},
		{"id": "shovel_titan", "cat": "Shovel", "tier": 3},
		{"id": "pick_titan", "cat": "Pickaxe", "tier": 3},
		{"id": "blockbuster_ticket", "cat": "Museum", "tier": 4},
		{"id": "blockbuster_crowd", "cat": "Museum", "tier": 4},
		{"id": "blockbuster_hours", "cat": "Museum", "tier": 4},
		{"id": "blockbuster_feature", "cat": "Museum", "tier": 4},
	]
	for raw in rows:
		var spec: Dictionary = raw
		var id: String = str(spec["id"])
		var item: Dictionary = _item(id)
		_assert(not item.is_empty(), "%s exists in the shop" % id)
		if item.is_empty():
			continue
		_assert(str(item.get("cat", "")) == str(spec["cat"]), "%s sits on %s" % [id, spec["cat"]])
		_assert(int(item.get("tier", 0)) == int(spec["tier"]), "%s is chapter %d" % [id, spec["tier"]])
		_assert(not bool(GS.tier_unlocked(id)), "%s starts gated" % id)
		_assert(not bool(GS.can_buy(id)), "%s cannot be bought at the start" % id)
	_assert(int(_item("hands_craft").get("cost", 0)) >= 1400 and int(_item("hands_craft").get("cost", 0)) <= 1800, "Fieldcraft first buy is about $1.5k")
	_assert(_row_last("hands_craft") >= 25000 and _row_last("hands_craft") <= 35000, "Fieldcraft last buy is about $30k")
	_assert(int(_item("round_marathon").get("cost", 0)) >= 20000 and int(_item("round_marathon").get("cost", 0)) <= 30000, "Grand Claim first buy is about $25k")
	_assert(_row_last("round_marathon") >= 200000 and _row_last("round_marathon") <= 400000, "Grand Claim last buy is $200–400k")
	_assert(int(_item("shovel_titan").get("cost", 0)) >= 70000 and int(_item("shovel_titan").get("cost", 0)) <= 90000, "Titan Shovel first buy is about $80k")
	_assert(_row_last("shovel_titan") >= 600000 and _row_last("shovel_titan") <= 1200000, "Titan Shovel last buy is $0.6–1.2M")
	_assert(int(_item("pick_titan").get("cost", 0)) >= 70000 and int(_item("pick_titan").get("cost", 0)) <= 90000, "Titan Pick first buy is about $80k")
	_assert(_row_last("pick_titan") >= 600000 and _row_last("pick_titan") <= 1200000, "Titan Pick last buy is $0.6–1.2M")
	_assert(int(_item("blockbuster_ticket").get("cost", 0)) >= 100000 and int(_item("blockbuster_ticket").get("cost", 0)) <= 140000, "Blockbuster first buy is about $120k")
	_assert(_row_last("blockbuster_ticket") >= 1000000 and _row_last("blockbuster_ticket") <= 3000000, "Blockbuster last buy is $1–3M")
	_max_chapter("Hands", 1)
	_assert(bool(GS.tier_unlocked("hands_craft")), "maxed Hands I unlocks Fieldcraft")
	_max_chapter("Shovel", 1)
	_max_chapter("Shovel", 2)
	_assert(bool(GS.tier_unlocked("shovel_titan")), "maxed Shovel II unlocks Titan Shovel")
	_max_chapter("Pickaxe", 1)
	_max_chapter("Pickaxe", 2)
	_assert(bool(GS.tier_unlocked("pick_titan")), "maxed Pickaxe II unlocks Titan Pick")
	_max_chapter("Site", 1)
	_max_chapter("Site", 2)
	_assert(bool(GS.tier_unlocked("round_marathon")), "maxed Site II unlocks Grand Claim")
	_max_chapter("Museum", 1)
	_max_chapter("Museum", 2)
	_max_chapter("Museum", 3)
	_assert(bool(GS.tier_unlocked("blockbuster_ticket")), "maxed Museum III unlocks Blockbuster")
	_assert(str(GS.lock_reason("blockbuster_ticket")).contains("III") or bool(GS.tier_unlocked("blockbuster_ticket")), "Museum IV lock copy can name III")


func _max_chapter(cat: String, tier: int) -> void:
	for item in GS.catalog:
		if str(item.get("cat", "")) != cat or int(item.get("tier", 1)) != tier:
			continue
		GS.levels[str(item["id"])] = int(item["max"])
	GS.apply_upgrades()


func _test_apex_ranks_add_power() -> void:
	_reset()
	_max_chapter("Hands", 1)
	var quality: float = float(TN.matrix_hands_quality)
	var pay: float = float(TN.matrix_hands_pay)
	var hold: float = float(TN.shovel_hold_tick_rate)
	GS.levels["hands_craft"] = 1
	GS.levels["hands_swift"] = 1
	GS.apply_upgrades()
	_assert(float(TN.matrix_hands_quality) > quality, "Fieldcraft raises Hands harvest quality")
	_assert(float(TN.matrix_hands_pay) > pay, "Fieldcraft raises Hands harvest pay")
	_assert(float(TN.shovel_hold_tick_rate) > hold, "Fieldcraft hold ranks dig faster")
	_reset()
	GS.levels["round_time"] = 4
	GS.apply_upgrades()
	var shift: float = float(TN.round_seconds)
	_assert(shift >= 64.0, "max Longer Shift still reaches 64s")
	var fossils: int = int(TN.extra_find_slots)
	GS.levels["round_marathon"] = 1
	GS.levels["prime_bed"] = 1
	GS.apply_upgrades()
	_assert(float(TN.round_seconds) > 64.0, "Marathon Shift runs past 64s")
	_assert(float(TN.round_seconds) > shift, "Marathon Shift lengthens the clock")
	_assert(int(TN.extra_find_slots) > fossils, "Prime Bed hides more fossils")
	_reset()
	_max_chapter("Shovel", 1)
	_max_chapter("Shovel", 2)
	var shovel_click: float = float(TN.shovel_click_mult)
	var shovel_hold: float = float(TN.shovel_hold_tick_rate)
	var shovel_reach: float = float(TN.shovel_radius)
	GS.levels["shovel_titan"] = 1
	GS.apply_upgrades()
	_assert(float(TN.shovel_click_mult) > shovel_click, "Titan Shovel hits harder")
	_assert(float(TN.shovel_hold_tick_rate) > shovel_hold, "Titan Shovel holds faster")
	_assert(float(TN.shovel_radius) > shovel_reach, "Titan Shovel scoops wider")
	_reset()
	_max_chapter("Pickaxe", 1)
	_max_chapter("Pickaxe", 2)
	var pick_click: float = float(TN.pickaxe_click_mult)
	var pick_hold: float = float(TN.pickaxe_hold_tick_rate)
	var pick_reach: float = float(TN.pickaxe_radius)
	GS.levels["pick_titan"] = 1
	GS.apply_upgrades()
	_assert(float(TN.pickaxe_click_mult) > pick_click, "Titan Pick hits harder")
	_assert(float(TN.pickaxe_hold_tick_rate) > pick_hold, "Titan Pick holds faster")
	_assert(float(TN.pickaxe_radius) > pick_reach, "Titan Pick scoops wider")
	_reset()
	_max_chapter("Museum", 1)
	var donation: float = float(TN.donation_mult)
	var visitors: int = int(TN.visitor_flat)
	var unveil: float = float(TN.unveil_spike_seconds)
	var featured: float = float(TN.spotlight_mult)
	GS.levels["blockbuster_ticket"] = 1
	GS.levels["blockbuster_crowd"] = 1
	GS.levels["blockbuster_hours"] = 1
	GS.levels["blockbuster_feature"] = 1
	GS.apply_upgrades()
	_assert(float(TN.donation_mult) > donation, "Blockbuster raises the ticket")
	_assert(int(TN.visitor_flat) > visitors, "Blockbuster draws more visitors")
	_assert(float(TN.unveil_spike_seconds) > unveil, "Blockbuster lengthens unveil")
	_assert(float(TN.spotlight_mult) > featured, "Blockbuster raises featured")
	GS.levels["blockbuster_feature"] = int(_item("blockbuster_feature").get("max", 2))
	GS.apply_upgrades()
	_assert(float(TN.spotlight_mult) >= 5.0, "max Blockbuster featured is at least 5x")


func _test_first_tool_buys_stay_early_victories() -> void:
	_reset()
	_assert(int(_item("shovel_click").get("cost", 999)) >= 18 and int(_item("shovel_click").get("cost", 999)) <= 30, "first shovel stays an early-game victory")
	_assert(int(_item("pick_click").get("cost", 999)) >= 130 and int(_item("pick_click").get("cost", 999)) <= 170, "first pick is still a shift, not $200")
	_assert(int(_item("hands_click").get("cost", 999)) >= 8 and int(_item("hands_click").get("cost", 999)) <= 12, "first hands buy stays cheap")
	_assert(int(_item("passive_miner").get("cost", 0)) < 8000, "Hired Hand stays a cheap stub")
	_assert(int(_item("benches").get("max", 0)) == 5, "Benches stay five ranks")
	_assert(int(_item("lighting").get("max", 0)) == 5, "Warm Lights stay five ranks")
	_assert(_item("brush_titan").is_empty() and _item("brush_master_plus").is_empty(), "there is no Brush III")


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
	GS.levels["precision"] = 5
	GS.apply_upgrades()
	_assert(TN.shovel_hit_cells(Vector2i(2, 2), float(TN.shovel_radius)).size() > 1, "leftover Fine ranks do not pinch the shovel")
	_assert(is_zero_approx(float(TN.precision_damage_bonus)), "leftover Fine ranks do not add a precision bonus")
	GS.precision_on = false


func _test_pick_wider_scoop_scales_like_shovel() -> void:
	_reset()
	var scoop: Dictionary = {}
	var pick_scoop: Dictionary = {}
	for item in GS.catalog:
		if str(item.get("id", "")) == "shovel_radius":
			scoop = item
		elif str(item.get("id", "")) == "pick_radius":
			pick_scoop = item
	_assert(not pick_scoop.is_empty(), "pickaxe has a Wider Scoop row")
	_assert(str(pick_scoop.get("cat", "")) == "Pickaxe", "pick scoop sits on Pickaxe")
	_assert(int(pick_scoop.get("max", 0)) == int(scoop.get("max", 0)), "pick scoop uses the same rank count as the shovel")
	_assert(int(pick_scoop.get("cost", 0)) > int(scoop.get("cost", 0)), "pick scoop costs more than the shovel scoop")
	_assert(str(pick_scoop.get("requires", "")) == "pick_click", "pick scoop waits for the pickaxe")
	GS.levels["pick_click"] = 1
	GS.apply_upgrades()
	var base_pick: float = float(TN.pickaxe_radius)
	_assert(base_pick >= 0.99, "an unbought pick still has the free plus")
	_assert(str(GS.shop_effect_line("pick_radius")).find("cell radius") >= 0, "pick scoop this-buy is a radius line")
	var plus_hits: int = _count_shovel_cells(Vector2i(2, 2), base_pick)
	GS.levels["pick_radius"] = 4
	GS.levels["shovel_radius"] = 4
	GS.apply_upgrades()
	_assert(float(TN.pickaxe_radius) > base_pick, "maxed pick scoop grows past the free plus")
	_assert(float(TN.pickaxe_radius) < float(TN.shovel_radius), "maxed pick scoop stays a bit narrower than the shovel")
	var max_hits: int = _count_shovel_cells(Vector2i(4, 4), float(TN.pickaxe_radius))
	_assert(max_hits > plus_hits, "maxed pick scoop hits more cells than the free plus")


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


func _test_footer_chrome_stays_below_pit() -> void:
	TN.view_w = 1280.0
	TN.view_h = 720.0
	TN.site_size_rank = 0
	TN.apply_site_layout()
	_assert(TN.has_method("pit_face_bottom"), "Tuning exposes the 1024x400 face bottom")
	_assert(TN.has_method("footer_top"), "Tuning exposes the reserved HUD footer")
	if not TN.has_method("pit_face_bottom") or not TN.has_method("footer_top"):
		return
	var face: float = float(TN.pit_face_bottom())
	var chunk_end: float = face + float(TN.chunk_front)
	var footer: float = float(TN.footer_top())
	_assert(is_equal_approx(float(TN.grid_w) * TN.cell_w, 16.0 * TN.base_cell_w), "footer layout keeps the 1024px pit")
	_assert(is_equal_approx(float(TN.grid_h) * TN.cell_h, 10.0 * TN.base_cell_h), "footer layout keeps the 400px pit")
	_assert(footer >= chunk_end, "find chrome starts below the dirt chunk")
	_assert(footer + 120.0 <= TN.view_h - 8.0, "find grade/stars fit under the pit")


func _test_find_footer_stays_on_screen() -> void:
	TN.view_w = 1280.0
	TN.view_h = 720.0
	TN.site_size_rank = 0
	TN.apply_site_layout()
	_assert(TN.has_method("footer_find_top"), "Tuning exposes the find-band top")
	_assert(TN.has_method("footer_menu_gutter"), "Tuning exposes the chip inset")
	if not TN.has_method("footer_find_top") or not TN.has_method("footer_menu_gutter"):
		return
	var find_top: float = float(TN.footer_find_top())
	var find_bottom: float = TN.view_h - 8.0
	var gutter: float = float(TN.footer_menu_gutter())
	var pit: Rect2 = TN.pit_grid_rect() if TN.has_method("pit_grid_rect") else Rect2(TN.grid_origin, Vector2(float(TN.grid_w) * TN.cell_w, float(TN.grid_h) * TN.cell_h))
	_assert(find_top >= float(TN.footer_top()), "find band stays below the pit chunk")
	_assert(find_bottom - find_top >= 88.0, "find band is tall enough for value, grade, and stars")
	_assert(find_bottom <= TN.view_h - 4.0, "find band stays above the window bottom")
	_assert(gutter >= 120.0, "chips stay inset to the pit, not the old Menu gutters")
	var hud_script: Script = load("res://hud.gd") as Script
	_assert(hud_script != null, "HUD script loads")
	if hud_script == null:
		return
	var hud: Node = hud_script.new()
	root.add_child(hud)
	if hud.has_method("refresh"):
		hud.call("refresh", 40.0, 40.0, TN.TOOL_BRUSH, true, true, 5, "Well preserved", 0.4, 80)
	if hud.has_method("set_find_cards"):
		hud.call("set_find_cards", [_card("Tooth", "t_rex_tooth", "brush", 5, "Brushed 40%", 80)])
	var find_box: Control = hud.get("_find_box") as Control
	_assert(find_box != null, "HUD exposes the find footer")
	_assert(hud.get("_work_card") == null, "HUD no longer hosts a working-find card")
	if find_box == null:
		hud.queue_free()
		return
	var finds_label: Label = hud.get("_finds_label") as Label
	if finds_label != null:
		_assert(is_equal_approx(finds_label.position.y, find_top) or finds_label.position.y >= find_top - 0.5, "HUD parks the Finds label at the reserved band")
		_assert(find_box.position.y >= finds_label.position.y + finds_label.size.y - 0.5, "chips sit under the Finds label")
	_assert(find_box.position.y >= find_top - 0.5, "HUD parks the find footer in the reserved band")
	_assert(find_box.position.y + find_box.size.y <= TN.view_h - 4.0, "HUD find footer stays above the window bottom")
	_assert(is_equal_approx(find_box.position.x, pit.position.x + 10.0), "HUD find chips start under the pit")
	_assert(is_equal_approx(find_box.size.x, pit.size.x - 20.0), "HUD find chips use the pit width")
	_assert(find_box.position.x >= gutter - 0.5, "HUD find text stays pit-aligned")
	_assert(find_box.position.x + find_box.size.x <= TN.view_w - 4.0, "HUD find chips stay on screen in the slim right field")
	var content_h: float = find_box.get_combined_minimum_size().y
	if content_h <= 0.0:
		content_h = _tray_content_h(find_box)
	_assert(content_h <= find_box.size.y + 1.0, "find chips fit inside the find band")
	hud.queue_free()


func _make_focused_find(extracted: bool, value: int = 80) -> Node:
	var script: Script = load("res://dig_site.gd") as Script
	var site: Node = script.new()
	var data: Resource = FossilData.new()
	data.set("name", "Tooth")
	data.set("base_value", value)
	var cell := Vector2i(0, 0)
	site.set("finds", [{
		"data": data,
		"extracted": extracted,
		"integrity": 1.0,
		"cells": {cell: true},
	}])
	site.set("cleanliness", {cell: 1.0})
	site.set("exposed_cells", {cell: true})
	site.set("_focus_index", 0)
	return site


func _test_extracted_preview_keeps_fossil_value() -> void:
	var site: Node = _make_focused_find(true, 80)
	_assert(int(site.call("preview_value")) == 80, "extracted find still shows the fossil payout")
	_assert(bool(site.call("has_visible_find")), "extracted find stays in the footer band")
	site.free()


func _test_find_toast_does_not_cover_footer() -> void:
	TN.view_w = 1280.0
	TN.view_h = 720.0
	TN.site_size_rank = 0
	TN.apply_site_layout()
	var hud_script: Script = load("res://hud.gd") as Script
	var toast_script: Script = load("res://toast_layer.gd") as Script
	_assert(hud_script != null and toast_script != null, "HUD and toast scripts load")
	if hud_script == null or toast_script == null:
		return
	var hud: Node = hud_script.new()
	var toast: Node = toast_script.new()
	root.add_child(hud)
	root.add_child(toast)
	if hud.has_method("refresh"):
		hud.call("refresh", 40.0, 40.0, TN.TOOL_BRUSH, true, true, 5, "Well preserved", 1.0, 80)
	if hud.has_method("set_find_cards"):
		hud.call("set_find_cards", [_card("Tooth", "t_rex_tooth", "bagged", 5, "Brushed 100%", 80)])
	if hud.has_method("set_find_headline"):
		hud.call("set_find_headline", "Tooth found!")
	toast.call("show_toast", "Tooth found!", "Well preserved")
	var find_box: Control = hud.get("_find_box") as Control
	var toast_box: Control = toast.get("_box") as Control
	_assert(find_box != null and toast_box != null, "find footer and toast expose their boxes")
	if find_box == null or toast_box == null:
		hud.queue_free()
		toast.queue_free()
		return
	var find_rect := Rect2(find_box.global_position, find_box.size)
	var toast_rect := Rect2(toast_box.global_position, toast_box.size)
	var stacked: bool = find_box.visible and toast_box.modulate.a > 0.05 and find_rect.intersects(toast_rect)
	_assert(not stacked, "find toast and live footer do not share the same pixels")
	_assert(toast_box.position.y + toast_box.size.y <= float(TN.footer_top()) + 0.5, "toast stays above the find band")
	_assert(toast_box.position.y >= float(TN.pit_face_bottom()) - 0.5, "toast stays off the dirt cells")
	hud.queue_free()
	toast.queue_free()


func _test_find_footer_shows_one_extract_readout() -> void:
	TN.view_w = 1280.0
	TN.view_h = 720.0
	TN.site_size_rank = 0
	TN.apply_site_layout()
	var hud_script: Script = load("res://hud.gd") as Script
	_assert(hud_script != null, "HUD script loads for extract readout")
	if hud_script == null:
		return
	var hud: Node = hud_script.new()
	root.add_child(hud)
	if hud.has_method("refresh"):
		hud.call("refresh", 40.0, 40.0, TN.TOOL_BRUSH, true, true, 5, "Well preserved", 1.0, 80)
	_assert(hud.has_method("set_find_cards"), "HUD can show a find chip instead of a stacked toast")
	if hud.has_method("set_find_cards"):
		hud.call("set_find_cards", [_card("Tooth", "t_rex_tooth", "bagged", 5, "Brushed 100%", 80, "Well preserved")])
	if hud.has_method("set_find_headline"):
		hud.call("set_find_headline", "Tooth found!")
	var find_box: Control = hud.get("_find_box") as Control
	var chips: Array = _hud_chips(hud)
	_assert(chips.size() == 1, "extract footer shows one chip, not a toast plus a name")
	if chips.size() == 1:
		var chip: Control = chips[0] as Control
		var name_label: Label = chip.get("_name_label") as Label
		var status_label: Label = chip.get("_status_label") as Label
		var icon: Control = chip.get("_icon") as Control
		var grade_label: Label = chip.get("_grade_label") as Label
		var price_label: Label = chip.get("_price_label") as Label
		var body: String = ""
		if grade_label != null:
			body += grade_label.text
		if status_label != null:
			body += "\n" + status_label.text
		if price_label != null:
			body += "\n" + price_label.text
		_assert(name_label != null and name_label.text.find("Tooth") >= 0, "extract chip names the Tooth")
		_assert(body.find("$80") >= 0, "extract chip shows the fossil value")
		_assert(body.find("Well preserved") >= 0 or body.find("★") >= 0 or body.find("5") >= 0, "extract chip shows stars or grade")
		_assert(body.find("Brushed 100%") >= 0, "extract chip shows brushed percent once")
		_assert(body.find("Dust") < 0 and body.find("Clean") < 0, "extract chip does not say Dust or Clean")
		_assert(icon != null, "extract chip shows the bone doodle")
	if find_box != null:
		_assert(find_box.position.y >= float(TN.footer_find_top()) - 0.5, "extract readout stays in the reserved find band")
		var content_h: float = find_box.get_combined_minimum_size().y
		if content_h <= 0.0:
			content_h = _tray_content_h(find_box)
		_assert(content_h <= find_box.size.y + 1.0, "find chips fit in the find band")
	hud.queue_free()


func _test_dirt_label_rises_as_brushed() -> void:
	_assert(TN.has_method("dirt_label"), "Tuning prints the chip dirt meter")
	if not TN.has_method("dirt_label"):
		return
	_assert(str(TN.dirt_label(0.0)) == "Brushed 0%", "fully dirty is Brushed 0%")
	_assert(str(TN.dirt_label(0.25)) == "Brushed 25%", "quarter clean is Brushed 25%")
	_assert(str(TN.dirt_label(0.75)) == "Brushed 75%", "mostly clean is Brushed 75%")
	_assert(str(TN.dirt_label(0.99)) == "Brushed 100%", "near-clean rounds to Brushed 100%")
	_assert(str(TN.dirt_label(1.0)) == "Brushed 100%", "fully clean is Brushed 100%")
	_assert(str(TN.dirt_label(0.0)).find("Dust") < 0, "dirt label never says Dust")
	_assert(str(TN.dirt_label(1.0)).find("Clean") < 0, "dirt label never says Clean")


func _test_find_chip_keeps_related_stats_together() -> void:
	TN.view_w = 1280.0
	TN.view_h = 720.0
	TN.site_size_rank = 0
	TN.apply_site_layout()
	var hud: Node = _make_hud()
	if hud == null:
		return
	if hud.has_method("refresh"):
		hud.call("refresh", 40.0, 40.0, TN.TOOL_BRUSH, true, true, 5, "Well preserved", 0.75, 17)
	if hud.has_method("set_find_cards"):
		hud.call("set_find_cards", [_card("Brachiosaurus Tooth", "brachiosaurus_tooth", "brush", 5, "Brushed 75%", 17, "Well preserved", 0, "New")])
	var chips: Array = _hud_chips(hud)
	_assert(chips.size() == 1, "an uncovered sauropod tooth makes one footer chip")
	if chips.size() == 1:
		var chip: Control = chips[0] as Control
		var name_label: Label = chip.get("_name_label") as Label
		var grade_label: Label = chip.get("_grade_label") as Label
		var status_label: Label = chip.get("_status_label") as Label
		var price_label: Label = chip.get("_price_label") as Label
		_assert(name_label != null and name_label.text.find("Brachiosaurus") >= 0 and name_label.text.find("Tooth") >= 0, "full uncover names the bone")
		_assert(name_label != null and name_label.text.find("...") < 0, "the name is not ellipsized")
		_assert(name_label != null and name_label.text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING, "the name label does not trim with an ellipsis")
		_assert(name_label != null and name_label.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER, "the name is centered in the text column")
		_assert(grade_label != null and grade_label.text.find("Well preserved") >= 0, "grade stays on the condition line")
		_assert(chip.get("_stars") != null and bool(chip.get("_stars").visible), "stars sit with the condition")
		_assert(grade_label != null and grade_label.text.find("Dust") < 0, "dust is not jammed onto the star line")
		_assert(grade_label != null and grade_label.text.find("$") < 0, "price is not jammed onto the star line")
		_assert(grade_label != null and grade_label.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER, "condition stays centered under the name")
		_assert(status_label != null and (status_label.text.find("New") >= 0 or status_label.text.find("/") >= 0 or status_label.text.find("Brushed 75%") >= 0), "uncover chip shows quota or the brush meter")
		_assert(status_label != null and status_label.text.find("Dust") < 0, "the meter does not say Dust")
		_assert(status_label != null and status_label.text.find("$") < 0, "price does not share the quota line")
		_assert(status_label != null and status_label.text.find("★") < 0, "stars do not share the quota line")
		_assert(status_label != null and status_label.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER, "quota copy is centered under the condition")
		_assert(price_label != null and price_label.text.find("$17") >= 0, "value sits on its own price tag")
		_assert(price_label != null and price_label.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT, "the price is right-aligned")
		_assert(price_label != null and price_label.vertical_alignment == VERTICAL_ALIGNMENT_CENTER, "the price is vertically centered")
		if name_label != null and price_label != null:
			_assert(name_label.get_theme_font_size("font_size") > price_label.get_theme_font_size("font_size"), "the bone name is louder than the price")
		if price_label != null and status_label != null:
			_assert(price_label.get_theme_font_size("font_size") >= status_label.get_theme_font_size("font_size") - 1, "the price stays readable next to the meter")
	var find_box: Control = hud.get("_find_box") as Control
	if find_box != null:
		var content_h: float = find_box.get_combined_minimum_size().y
		if content_h <= 0.0:
			content_h = _tray_content_h(find_box)
		_assert(content_h <= find_box.size.y + 1.0, "grouped chips still fit in the find band")
		_assert(find_box.position.y >= float(TN.pit_face_bottom()) + float(TN.chunk_front) - 0.5, "grouped chips stay below the dirt")
	hud.queue_free()


func _test_fully_brushed_chip_stays_complete_and_priced() -> void:
	TN.view_w = 1280.0
	TN.view_h = 720.0
	TN.site_size_rank = 0
	TN.apply_site_layout()
	var hud: Node = _make_hud()
	if hud == null:
		return
	if hud.has_method("refresh"):
		hud.call("refresh", 40.0, 40.0, TN.TOOL_BRUSH, true, true, 5, "Well preserved", 1.0, 90)
	if hud.has_method("set_find_cards"):
		hud.call("set_find_cards", [_card("Triceratops Vertebra", "triceratops_vertebra", "bagged", 5, "Brushed 100%", 90, "Well preserved")])
	if hud.has_method("set_find_headline"):
		hud.call("set_find_headline", "Triceratops Vertebra found!")
	var chips: Array = _hud_chips(hud)
	_assert(chips.size() == 1, "a fully brushed fossil still makes one footer chip")
	if chips.size() == 1:
		var chip: Control = chips[0] as Control
		var name_label: Label = chip.get("_name_label") as Label
		var grade_label: Label = chip.get("_grade_label") as Label
		var status_label: Label = chip.get("_status_label") as Label
		var price_label: Label = chip.get("_price_label") as Label
		_assert(name_label != null and name_label.text == "Triceratops Vertebra", "fully brushed chip keeps one name")
		_assert(name_label != null and name_label.text.find("found") < 0, "the title is not a found toast")
		_assert(grade_label != null and grade_label.text.find("found") < 0, "condition is not a found line")
		_assert(grade_label != null and grade_label.text.find("Triceratops") < 0, "condition does not repeat the fossil name")
		_assert(grade_label != null and grade_label.text.find("Well preserved") >= 0, "condition stays Well preserved")
		_assert(chip.get("_stars") != null and bool(chip.get("_stars").visible), "stars stay with the condition")
		_assert(status_label != null and status_label.text.find("Brushed 100%") >= 0, "meter can still say Brushed 100%")
		_assert(price_label != null and price_label.visible and price_label.text == "$90", "the payout stays on the chip at 100%")
		_assert(price_label != null and price_label.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT, "payout stays on the right")
		_assert(price_label != null and price_label.vertical_alignment == VERTICAL_ALIGNMENT_CENTER, "payout stays vertically centered")
		if price_label != null and name_label != null:
			var icon: Control = chip.get("_icon") as Control
			_assert(icon.position.x < name_label.position.x and name_label.position.x < price_label.position.x, "layout stays icon | text | $")
		var done_box: StyleBox = chip.get_theme_stylebox("panel")
		_assert(done_box != null and "border_color" in done_box, "finished chip uses a brass panel")
		if done_box != null and "border_color" in done_box:
			var done_border: Color = done_box.border_color
			_assert(done_border.r > 0.8 and done_border.g > 0.55, "100% chip rim is fully gold")
	if hud.has_method("set_find_cards"):
		hud.call("set_find_cards", [_card("Triceratops Vertebra", "triceratops_vertebra", "brush", 5, "Brushed 50%", 90, "Well preserved")])
	var mid_chips: Array = _hud_chips(hud)
	if mid_chips.size() == 1:
		var mid: Control = mid_chips[0] as Control
		var mid_box: StyleBox = mid.get_theme_stylebox("panel")
		if mid_box != null and "border_color" in mid_box:
			var mid_border: Color = mid_box.border_color
			_assert(mid_border.r > 0.5 and mid_border.r < 0.82, "50% chip rim is only half warm")
	hud.queue_free()


func _test_extract_does_not_stack_a_found_toast() -> void:
	var src: String = FileAccess.get_file_as_string("res://main.gd")
	_assert(not src.is_empty(), "main.gd loads")
	_assert(src.find("show_toast(\"%s found!\"") < 0, "extract does not fire a found toast on top of the footer")


func _test_two_pit_finds_make_two_footer_chips() -> void:
	var site: Node = _make_two_finds()
	_assert(site.has_method("live_find_cards"), "the pit lists every live fossil for the footer")
	if not site.has_method("live_find_cards"):
		site.free()
		return
	var cards: Array = site.call("live_find_cards")
	_assert(cards.size() == 2, "two bones in the pit make two cards, not one name")
	if cards.size() >= 2:
		_assert(str(cards[0].get("piece_id", "")).find("tooth") >= 0, "first card is still the Tooth find")
		_assert(str(cards[1].get("piece_id", "")).find("trilobite") >= 0, "second card is still the Trilobite find")
		_assert(str(cards[0].get("name", "")).find("Tooth") < 0, "partly uncovered card stays mystery Bone")
		_assert(str(cards[1].get("name", "")).find("Trilobite") < 0, "buried card does not name the Trilobite")
		_assert(str(cards[0].get("status", "")) == "uncovering", "touched bone is uncovering")
		_assert(str(cards[1].get("status", "")) == "underground", "untouched extra stays underground")
	var hud: Node = _make_hud()
	if hud == null:
		site.free()
		return
	if hud.has_method("refresh"):
		hud.call("refresh", 40.0, 40.0, TN.TOOL_HANDS, true, true, 5, "", 0.0, 40)
	if hud.has_method("set_find_cards"):
		hud.call("set_find_cards", cards)
	var chips: Array = _hud_chips(hud)
	_assert(chips.size() == 1, "first exposed cell makes one Bone chip")
	if chips.size() == 1:
		var mystery: Label = chips[0].get("_name_label") as Label
		_assert(mystery != null and str(mystery.text) == "Bone", "first-cell chip stays a silhouette Bone")
	_assert(hud.get("_chip") == null, "NEXT left the live HUD")
	hud.queue_free()
	site.free()
	var uncovered: Node = _make_two_uncovered_finds()
	var ready: Array = uncovered.call("live_find_cards")
	_assert(ready.size() == 2, "two fully uncovered bones still make two cards")
	var ready_hud: Node = _make_hud()
	if ready_hud == null:
		uncovered.free()
		return
	if ready_hud.has_method("set_find_cards"):
		ready_hud.call("set_find_cards", ready)
	var ready_chips: Array = _hud_chips(ready_hud)
	_assert(ready_chips.size() == 2, "two uncovered bones make two footer chips")
	if ready_chips.size() >= 2:
		var a: Label = ready_chips[0].get("_name_label") as Label
		var b: Label = ready_chips[1].get("_name_label") as Label
		_assert(a != null and a.text.find("Tooth") >= 0, "first chip names the Tooth at full uncover")
		_assert(b != null and b.text.find("Trilobite") >= 0, "second chip names the Trilobite at full uncover")
		_assert(ready_chips[0].get("_icon") != null and ready_chips[1].get("_icon") != null, "each chip shows a bone doodle")
	_assert(ready_hud.get("_chip") == null, "NEXT stayed gone when two finds are uncovered")
	ready_hud.queue_free()
	uncovered.free()


func _test_buried_finds_do_not_make_footer_chips() -> void:
	var hud: Node = _make_hud()
	if hud == null:
		return
	if hud.has_method("refresh"):
		hud.call("refresh", 40.0, 40.0, TN.TOOL_HANDS, true, true, 5, "", 0.0, 40)
	if hud.has_method("set_find_cards"):
		hud.call("set_find_cards", [
			_card("Stegosaurus Foot", "stegosaurus_foot", "underground", 0, "", 0, "", 0),
			_card("Triceratops Tooth", "triceratops_tooth", "brush", 5, "Brushed 80%", 90, "", 1),
			_card("Velociraptor Femur", "velociraptor_femur", "uncovering", 0, "", 0, "", 2),
		])
	var chips: Array = _hud_chips(hud)
	_assert(chips.size() == 2, "full uncover and first-cell bones both become chips")
	if chips.size() == 2:
		var named: Label = chips[0].get("_name_label") as Label
		var mystery: Label = chips[1].get("_name_label") as Label
		_assert(named != null and named.text.find("Triceratops") >= 0, "the fully uncovered tooth names the species")
		_assert(mystery != null and mystery.text.find("Velociraptor") < 0, "partly uncovered names stay hidden")
		_assert(mystery != null and str(mystery.text) == "Bone", "first exposed cell is a Bone chip")
	if hud.has_method("find_chip_catch_pos"):
		var dest: Vector2 = hud.call("find_chip_catch_pos", 1)
		var fallback := Vector2(TN.view_w * 0.5, TN.footer_find_top() + 34.0)
		_assert(dest != fallback, "fly targets the uncovered chip by find index")
	_assert(hud.get("_chip") == null, "NEXT left the live HUD")
	hud.queue_free()


func _test_find_chips_sit_in_footer_band() -> void:
	TN.view_w = 1280.0
	TN.view_h = 720.0
	TN.site_size_rank = 0
	TN.apply_site_layout()
	var hud_script: Script = load("res://hud.gd") as Script
	var hud: Node = hud_script.new()
	root.add_child(hud)
	if hud.has_method("refresh"):
		hud.call("refresh", 40.0, 40.0, TN.TOOL_BRUSH, true, true, 5, "Well preserved", 0.4, 80)
	if hud.has_method("set_find_cards"):
		hud.call("set_find_cards", [
			_card("Tooth", "t_rex_tooth", "brush", 5, "Brushed 40%", 80, "", 0),
			_card("Trilobite", "trilobite", "bagged", 5, "Brushed 100%", 40, "", 1),
		])
	var find_box: Control = hud.get("_find_box") as Control
	_assert(find_box != null, "find tray lives on the HUD")
	if find_box == null:
		hud.queue_free()
		return
	_assert(find_box.position.y >= float(TN.footer_find_top()) - 0.5, "chips sit in the reserved footer band")
	_assert(find_box.position.y >= float(TN.pit_face_bottom()) + float(TN.chunk_front) - 0.5, "chips sit below the dirt, not on cells")
	var pit: Rect2 = TN.pit_grid_rect() if TN.has_method("pit_grid_rect") else Rect2(TN.grid_origin, Vector2(float(TN.grid_w) * TN.cell_w, float(TN.grid_h) * TN.cell_h))
	_assert(is_equal_approx(find_box.position.x, pit.position.x + 10.0), "chips start at the pit's left edge")
	_assert(is_equal_approx(find_box.size.x, pit.size.x - 20.0), "chips use the full pit width")
	_assert(not pit.intersects(Rect2(find_box.position, find_box.size)), "chips do not sit on the pit grid")
	_assert(hud.get("_work_card") == null, "find chips have no working-find card to overlap")
	var chips: Array = _hud_chips(hud)
	_assert(chips.size() == 2, "the footer row shows both live finds")
	hud.queue_free()


func _test_full_uncover_flies_to_footer_chip() -> void:
	var Fly: GDScript = load("res://loot_fly.gd") as GDScript
	_assert(Fly != null, "loot_fly.gd still exists")
	var can_fly_fossil: bool = false
	if Fly != null:
		var probe: Node = Fly.new() as Node
		can_fly_fossil = probe != null and probe.has_method("setup_fossil")
		if probe != null:
			probe.free()
	_assert(can_fly_fossil, "loot fly can carry a fossil to its chip")
	if Fly != null and Fly.has_method("arc_point"):
		var start := Vector2(400, 300)
		var dest := Vector2(220, 640)
		var mid: Vector2 = Fly.arc_point(start, dest, 0.5)
		var linear: Vector2 = start.lerp(dest, 0.5)
		_assert(mid.y < linear.y, "the fossil arcs up on the way to its chip")
		_assert(Fly.arc_point(start, dest, 1.0) == dest, "the fossil lands on its footer chip")
	var site: Node = _make_two_uncovered_finds()
	if site.has_method("live_find_cards"):
		var cards: Array = site.call("live_find_cards")
		var hud: Node = _make_hud()
		if hud != null and hud.has_method("set_find_cards"):
			hud.call("set_find_cards", cards)
		_assert(hud != null and hud.has_method("find_chip_catch_pos"), "HUD exposes each chip as a fly target")
		if hud != null and hud.has_method("find_chip_catch_pos"):
			var pos: Vector2 = hud.call("find_chip_catch_pos", 0)
			_assert(pos.y >= float(TN.footer_find_top()) - 8.0, "fly target is the footer chip, not the wallet")
			_assert(pos.y > 200.0, "fly target is not the pouch")
		if hud != null and hud.has_method("catch_find"):
			hud.call("catch_find", 0)
			var chips: Array = _hud_chips(hud)
			if chips.size() > 0:
				_assert(float(chips[0].get("_pop")) > 0.0 or float(chips[0].get("_lit")) > 0.0, "arrived fossil lights its chip")
		if hud != null:
			hud.queue_free()
	site.free()
	var main_src: String = FileAccess.get_file_as_string("res://main.gd")
	_assert(main_src.find("setup_fossil") >= 0 or main_src.find("find_chip_catch_pos") >= 0, "full uncover flies the bone to its chip")
	_assert(main_src.find("fossil_ready_to_dust") >= 0, "fly starts when every cell is revealed")
	var ready_at: int = main_src.find("func _on_ready_to_dust")
	var extract_at: int = main_src.find("func _on_fossil_extracted")
	_assert(ready_at >= 0 and extract_at > ready_at, "_on_ready_to_dust is a distinct fly hook")
	if ready_at >= 0 and extract_at > ready_at:
		var ready_fn: String = main_src.substr(ready_at, extract_at - ready_at)
		var add_at: int = ready_fn.find("set_find_cards")
		var fly_at: int = ready_fn.find("_spawn_fossil_fly")
		_assert(add_at >= 0, "the chip is added when the last cell is revealed")
		_assert(add_at >= 0 and fly_at > add_at, "fly starts after the chip exists")


func _test_hands_stay_the_careful_one_cell_tool() -> void:
	_reset()
	GS.levels["shovel_click"] = 1
	GS.levels["shovel_radius"] = 1
	GS.apply_upgrades()
	_assert(TN.hands_click_mult < TN.shovel_click_mult, "hands scrape dirt weaker than the shovel")
	_assert(TN.has_method("integrity_hit_for"), "Tuning exposes per-tool bone cost")
	if not TN.has_method("integrity_hit_for"):
		return
	## Bone condition comes from the ground now; no tool ever damages bone.
	for tool in [TN.TOOL_HANDS, TN.TOOL_SHOVEL, TN.TOOL_PICKAXE, TN.TOOL_BRUSH]:
		_assert(is_zero_approx(float(TN.integrity_hit_for(tool))), "tool %d never damages bone" % tool)
	_assert(TN.shovel_hit_cells(Vector2i(2, 2), 0.0).size() == 1, "hands stay a one-cell scrape")


func _test_passive_miner_is_catalogued() -> void:
	_reset()
	var item: Dictionary = _item("passive_miner")
	_assert(not item.is_empty(), "Hired Hand exists in the shop")
	_assert(int(item.get("tier", 0)) >= 3, "Hired Hand sits at the end of Site")
	_assert(int(item.get("cost", 0)) >= 2000, "Hired Hand is a late purchase")
	_assert(not bool(GS.tier_unlocked("passive_miner")), "Hired Hand waits behind Site II")
	_assert(not bool(GS.requirements_met("passive_miner")), "Hired Hand waits for Super tools / Rich Bed")
	GS.money = 99999
	_assert(not bool(GS.can_buy("passive_miner")), "Hired Hand cannot be bought at the start")
	GS.levels["shovel_super"] = 1
	GS.levels["rich_bed"] = 1
	GS.apply_upgrades()
	_assert(bool(GS.requirements_met("passive_miner")), "Hired Hand requires Super Shovel and Rich Bed")
	_assert(not bool(GS.can_buy("passive_miner")), "Hired Hand still waits for Site II even with those ranks")
	_assert(not GS.has_method("tick_hired_hands"), "Hired Hand does not auto-dig this pass")


func _make_hud() -> Node:
	var hud_script: Script = load("res://hud.gd") as Script
	_assert(hud_script != null, "HUD script loads")
	if hud_script == null:
		return null
	var hud: Node = hud_script.new()
	root.add_child(hud)
	return hud


func _card(find_name: String, piece_id: String, status: String, stars: int, dirt: String, value: int, grade: String = "", index: int = 0, progress: String = "") -> Dictionary:
	return {
		"index": index,
		"name": find_name,
		"piece_id": piece_id,
		"status": status,
		"stars": stars,
		"grade": grade,
		"dirt": dirt,
		"value": value,
		"progress": progress,
		"exposed": 1 if status != "underground" else 0,
		"needed": 1,
		"centroid": Vector2(400, 300),
		"fully_exposed": status == "brush" or status == "bagged",
		"extracted": status == "bagged",
	}


func _make_two_finds() -> Node:
	var script: Script = load("res://dig_site.gd") as Script
	var site: Node = script.new()
	var tooth: Resource = FossilData.new()
	tooth.set("name", "Tooth")
	tooth.set("piece_id", "t_rex_tooth")
	tooth.set("base_value", 80)
	var bug: Resource = FossilData.new()
	bug.set("name", "Trilobite")
	bug.set("piece_id", "trilobite")
	bug.set("base_value", 40)
	var cell_a := Vector2i(0, 0)
	var cell_a2 := Vector2i(1, 0)
	var cell_b := Vector2i(2, 1)
	site.set("finds", [
		{
			"data": tooth,
			"piece_id": "t_rex_tooth",
			"extracted": false,
			"integrity": 1.0,
			"cells": {cell_a: true, cell_a2: true},
			"origin": cell_a,
			"layer": 0,
			"ready": false,
		},
		{
			"data": bug,
			"piece_id": "trilobite",
			"extracted": false,
			"integrity": 1.0,
			"cells": {cell_b: true},
			"origin": cell_b,
			"layer": 2,
			"ready": false,
		},
	])
	site.set("cleanliness", {cell_a: 0.4})
	site.set("exposed_cells", {cell_a: true})
	site.set("_focus_index", 0)
	return site


func _make_two_uncovered_finds() -> Node:
	var site: Node = _make_two_finds()
	var finds: Array = site.get("finds")
	var exposed: Dictionary = {}
	for find in finds:
		var cells: Dictionary = find.get("cells", {})
		for cell in cells:
			exposed[cell] = true
		find["ready"] = true
	site.set("exposed_cells", exposed)
	return site


func _hud_chips(hud: Node) -> Array:
	var raw: Variant = hud.get("_chips")
	if raw is Array:
		return raw
	var box: Node = hud.get("_find_box") as Node
	if box == null:
		return []
	var chips: Array = []
	for child in box.get_children():
		if child is Control and child.get("_name_label") != null:
			chips.append(child)
	return chips


func _tray_content_h(find_box: Control) -> float:
	var content_h: float = 0.0
	var visible_kids: int = 0
	for child in find_box.get_children():
		var item: Control = child as Control
		if item == null or not item.visible:
			continue
		content_h = maxf(content_h, item.get_combined_minimum_size().y)
		visible_kids += 1
	if visible_kids > 1 and find_box is VBoxContainer:
		content_h += float(find_box.get_theme_constant("separation")) * float(visible_kids - 1)
	return content_h


func _assert(ok: bool, label: String) -> void:
	if ok:
		_passed += 1
		print("PASS  %s" % label)
	else:
		_failed += 1
		print("FAIL  %s" % label)
