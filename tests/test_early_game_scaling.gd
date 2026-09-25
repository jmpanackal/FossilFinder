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
	_test_footer_chrome_stays_below_pit()
	_test_find_footer_and_next_chip_stay_on_screen()
	_test_extracted_preview_keeps_fossil_value()
	_test_find_toast_does_not_cover_footer()
	_test_find_footer_shows_one_extract_readout()
	_test_extract_does_not_stack_a_found_toast()
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
	GS.levels["precision"] = 5
	GS.apply_upgrades()
	_assert(TN.shovel_hit_cells(Vector2i(2, 2), float(TN.shovel_radius)).size() > 1, "leftover Fine ranks do not pinch the shovel")
	_assert(is_zero_approx(float(TN.precision_damage_bonus)), "leftover Fine ranks do not add a precision bonus")
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
	_assert(footer >= chunk_end, "goal/NEXT/find chrome starts below the dirt chunk")
	_assert(footer + 130.0 <= TN.view_h - 8.0, "goal, NEXT, and find grade/stars fit under the pit")


func _test_find_footer_and_next_chip_stay_on_screen() -> void:
	TN.view_w = 1280.0
	TN.view_h = 720.0
	TN.site_size_rank = 0
	TN.apply_site_layout()
	_assert(TN.has_method("footer_find_top"), "Tuning exposes the find-band top")
	_assert(TN.has_method("footer_menu_gutter"), "Tuning exposes the Menu/End gutter")
	if not TN.has_method("footer_find_top") or not TN.has_method("footer_menu_gutter"):
		return
	var find_top: float = float(TN.footer_find_top())
	var find_bottom: float = TN.view_h - 8.0
	var gutter: float = float(TN.footer_menu_gutter())
	_assert(find_top >= float(TN.footer_top()), "find band stays below the goal/NEXT row")
	_assert(find_bottom - find_top >= 88.0, "find band is tall enough for value, grade, and stars")
	_assert(find_bottom <= TN.view_h - 4.0, "find band stays above the window bottom")
	_assert(gutter >= 124.0, "Menu and End shift keep a side gutter")
	var hud_script: Script = load("res://hud.gd") as Script
	_assert(hud_script != null, "HUD script loads")
	if hud_script == null:
		return
	var hud: Node = hud_script.new()
	root.add_child(hud)
	if hud.has_method("refresh"):
		hud.call("refresh", 40.0, 40.0, TN.TOOL_BRUSH, true, true, 5, "Well preserved", 0.4, 80)
	var find_box: VBoxContainer = hud.get("_find_box") as VBoxContainer
	var chip: Button = hud.get("_chip") as Button
	_assert(find_box != null and chip != null, "HUD exposes the find footer and NEXT chip")
	if find_box == null or chip == null:
		hud.queue_free()
		return
	_assert(is_equal_approx(find_box.position.y, find_top), "HUD parks the find footer in the reserved band")
	_assert(find_box.position.y + find_box.size.y <= TN.view_h - 4.0, "HUD find footer stays above the window bottom")
	_assert(find_box.position.x >= gutter, "HUD find text stays clear of the Menu button")
	_assert(find_box.position.x + find_box.size.x <= TN.view_w - gutter, "HUD find text stays clear of End shift")
	var content_h: float = 0.0
	var visible_kids: int = 0
	for child in find_box.get_children():
		var item: Control = child as Control
		if item == null or not item.visible:
			continue
		content_h += item.get_combined_minimum_size().y
		visible_kids += 1
	if visible_kids > 1:
		content_h += float(find_box.get_theme_constant("separation")) * float(visible_kids - 1)
	_assert(content_h <= find_box.size.y + 1.0, "value, grade, stars, and dirt fit inside the find band")
	_assert(chip.position.x + chip.size.x <= TN.view_w - 8.0, "NEXT chip stays on screen")
	_assert(chip.clip_contents, "NEXT chip keeps its label inside the box")
	_assert(chip.clip_text, "NEXT chip does not paint its buy onto the dirt")
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
	if hud.has_method("set_find_headline"):
		hud.call("set_find_headline", "Tooth found!")
	toast.call("show_toast", "Tooth found!", "Well preserved")
	var find_box: Control = hud.get("_find_box") as Control
	var toast_box: Control = toast.get("_box") as Control
	var chip: Button = hud.get("_chip") as Button
	_assert(find_box != null and toast_box != null, "find footer and toast expose their boxes")
	if find_box == null or toast_box == null:
		hud.queue_free()
		toast.queue_free()
		return
	var find_rect := Rect2(find_box.global_position, find_box.size)
	var toast_rect := Rect2(toast_box.global_position, toast_box.size)
	var stacked: bool = find_box.visible and toast_box.modulate.a > 0.05 and find_rect.intersects(toast_rect)
	_assert(not stacked, "find toast and live footer do not share the same pixels")
	_assert(toast_box.position.y + toast_box.size.y <= float(TN.footer_top()) + 0.5, "toast stays above NEXT and the goal bar")
	_assert(toast_box.position.y >= float(TN.pit_face_bottom()) - 0.5, "toast stays off the dirt cells")
	if chip != null:
		var chip_rect := Rect2(chip.global_position, chip.size)
		_assert(not chip_rect.intersects(toast_rect), "toast does not draw through NEXT")
		_assert(not chip_rect.intersects(find_rect), "find readout stays below NEXT")
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
	if hud.has_method("set_find_headline"):
		hud.call("set_find_headline", "Tooth found!")
	var headline: Label = hud.get("_headline") as Label
	var value: Label = hud.get("_value") as Label
	var grade: Label = hud.get("_grade") as Label
	var dirt: Label = hud.get("_dirt_label") as Label
	var find_box: VBoxContainer = hud.get("_find_box") as VBoxContainer
	_assert(headline != null and headline.visible, "extract footer shows a Tooth found headline")
	if headline != null:
		_assert(headline.text == "Tooth found!", "extract headline is Tooth found!")
	_assert(value != null and value.text == "$80", "extract footer shows the fossil value")
	_assert(grade != null and grade.text == "Well preserved", "extract footer shows one condition line")
	if find_box != null:
		var grades: int = 0
		for child in find_box.get_children():
			var label: Label = child as Label
			if label != null and label.visible and label.text == "Well preserved":
				grades += 1
		_assert(grades == 1, "Well preserved appears once in the find footer")
	_assert(dirt != null and dirt.text == "Clean", "extract footer shows dirt/clean once")
	if find_box != null:
		_assert(is_equal_approx(find_box.position.y, float(TN.footer_find_top())), "extract readout stays in the reserved find band")
		var content_h: float = 0.0
		var visible_kids: int = 0
		for child in find_box.get_children():
			var item: Control = child as Control
			if item == null or not item.visible:
				continue
			content_h += item.get_combined_minimum_size().y
			visible_kids += 1
		if visible_kids > 1:
			content_h += float(find_box.get_theme_constant("separation")) * float(visible_kids - 1)
		_assert(content_h <= find_box.size.y + 1.0, "headline, value, grade, stars, and dirt fit in the find band")
	hud.queue_free()


func _test_extract_does_not_stack_a_found_toast() -> void:
	var src: String = FileAccess.get_file_as_string("res://main.gd")
	_assert(not src.is_empty(), "main.gd loads")
	_assert(src.find("show_toast(\"%s found!\"") < 0, "extract does not fire a found toast on top of the footer")


func _test_hands_stay_the_careful_one_cell_tool() -> void:
	_reset()
	GS.levels["shovel_click"] = 1
	GS.levels["shovel_radius"] = 1
	GS.apply_upgrades()
	_assert(TN.hands_click_mult < TN.shovel_click_mult, "hands scrape dirt weaker than the shovel")
	_assert(TN.has_method("integrity_hit_for"), "Tuning exposes per-tool bone cost")
	if not TN.has_method("integrity_hit_for"):
		return
	_assert(float(TN.integrity_hit_for(TN.TOOL_HANDS)) < float(TN.integrity_hit_for(TN.TOOL_SHOVEL)), "hands are safer on bone than the shovel")
	_assert(is_zero_approx(float(TN.integrity_hit_for(TN.TOOL_HANDS))), "hands do not chip integrity")
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


func _assert(ok: bool, label: String) -> void:
	if ok:
		_passed += 1
		print("PASS  %s" % label)
	else:
		_failed += 1
		print("FAIL  %s" % label)
