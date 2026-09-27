extends SceneTree

## Shop tabs, tier gates, icons, unlock-then-rank chrome.
## Run: godot --headless --path <project> -s res://tests/test_shop_layout.gd

const ShopIcon := preload("res://shop_icon.gd")

var _failed: int = 0
var _passed: int = 0
var GS: Node
var TN: Node
var shop


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	GS = root.get_node("GameState")
	TN = root.get_node("Tuning")
	_reset()
	var shop_script: GDScript = load("res://shop.gd")
	shop = shop_script.new()
	root.add_child(shop)
	shop.visible = true
	shop.refresh()
	_test_shop_uses_back_not_menu()
	_test_tabs_cover_every_department()
	_test_exhibit_has_unveil_rush_upgrades()
	_test_exhibit_has_spotlight_unlock()
	_test_fine_point_is_not_a_shop_row()
	_test_icons_exist_for_tools_and_ranks()
	_test_hands_is_a_chapter_without_a_gate()
	_test_locked_shovel_two_is_a_chest_gate()
	_test_unlock_offer_hides_zero_ranks()
	_test_maxed_uses_a_seal()
	_test_affordable_tab_badges()
	_test_shop_effect_line_uses_live_ranks()
	_test_shop_row_subtitle_is_this_buy()
	_test_shop_hover_does_not_dump()
	_test_icon_wells_are_square()
	await _test_icon_glyphs_fill_the_well()
	_test_super_tool_is_two_this_buy_bits()
	await _test_site_tab_opens_without_applying_layout()
	print("shop_layout %d passed, %d failed" % [_passed, _failed])
	if shop != null:
		shop.queue_free()
	quit(1 if _failed > 0 else 0)


func _reset() -> void:
	GS.pieces.clear()
	GS.money = 0
	GS.featured_stand_id = ""
	GS.pending_unveils.clear()
	GS.pending_notices.clear()
	GS.unveil_spike_left = 0.0
	GS._income_accum = 0.0
	GS.precision_on = false
	for item in GS.catalog:
		GS.levels[item["id"]] = 0
	GS.apply_upgrades()


func _test_shop_uses_back_not_menu() -> void:
	_assert(_find_button(shop, "Back") != null, "shop header is Back")
	_assert(_find_button(shop, "Menu") == null, "shop does not instance a Menu button")


func _find_button(node: Node, text: String) -> Button:
	if node == null:
		return null
	if node is Button and str((node as Button).text) == text:
		return node as Button
	for child in node.get_children():
		var found: Button = _find_button(child, text)
		if found != null:
			return found
	return null


func _test_tabs_cover_every_department() -> void:
	var expected: Array[String] = ["Hands", "Shovel", "Pickaxe", "Brush", "Site", "Exhibit"]
	_assert(shop.CATS == expected, "left rail lists every department")
	for cat in expected:
		_assert(shop._tabs.has(cat), "tab exists for %s" % cat)
		_assert(shop._pages.has(cat), "page exists for %s" % cat)


func _test_exhibit_has_unveil_rush_upgrades() -> void:
	_assert(shop._buttons.has("unveil_time"), "Exhibit tab lists Opening Hours")
	_assert(shop._buttons.has("unveil_crowd"), "Exhibit tab lists Opening Crowd")
	_assert(str(_item("unveil_time").get("cat", "")) == "Exhibit", "Opening Hours is Exhibit")
	_assert(str(_item("unveil_crowd").get("cat", "")) == "Exhibit", "Opening Crowd is Exhibit")


func _test_exhibit_has_spotlight_unlock() -> void:
	_assert(shop._buttons.has("spotlight"), "Exhibit tab lists Spotlight")
	_assert(str(_item("spotlight").get("cat", "")) == "Exhibit", "Spotlight is Exhibit")
	_assert(int(_item("spotlight").get("max", 0)) == 3, "Spotlight has three ranks")
	_assert(int(_item("spotlight").get("cost", 0)) < 900, "Spotlight unlock is cheaper than Super Shovel")
	var row: Panel = shop._buttons["spotlight"]
	_assert(str(row.title.text) == "Unlock Spotlight", "spotlight starts as Unlock Spotlight")
	_assert(not bool(row.pips.visible), "unlock offer hides 0/N pips")
	_assert(str(GS.shop_item_desc("spotlight")).find("2x") >= 0, "unlock copy names Featured exhibit 2x")
	GS.money = int(GS.cost_of("spotlight")) + int(GS.cost_of("spotlight")) * 4
	_assert(bool(GS.buy("spotlight")), "first rank unlocks 2x")
	shop.refresh()
	_assert(str(row.title.text) == "Featured exhibit 2x", "rank 1 title is Featured exhibit 2x")
	_assert(bool(row.pips.visible), "bought spotlight shows ranks")
	_assert(str(GS.shop_item_desc("spotlight")).find("3x") >= 0, "next rank copy names 3x")
	_assert(bool(GS.buy("spotlight")), "second rank buys")
	shop.refresh()
	_assert(str(row.title.text) == "Featured exhibit 3x", "rank 2 title is Featured exhibit 3x")
	_assert(str(GS.shop_item_desc("spotlight")).find("4x") >= 0, "next rank copy names 4x")


func _test_fine_point_is_not_a_shop_row() -> void:
	_assert(not shop._buttons.has("precision"), "shop has no Fine Point row")
	for item in GS.catalog:
		_assert(str(item.get("id", "")) != "precision", "catalog has no precision id")
		_assert(str(item.get("name", "")).find("Fine") < 0, "catalog names do not say Fine")
		_assert(str(item.get("unlock_name", "")).find("Fine") < 0, "catalog unlocks do not say Fine")


func _test_icons_exist_for_tools_and_ranks() -> void:
	_assert(str(ShopIcon.glyph_for_cat("Hands")) == "hands", "hands tab uses the hand glyph")
	_assert(str(ShopIcon.glyph_for_cat("Shovel")) == "shovel", "shovel tab uses the shovel glyph")
	_assert(str(ShopIcon.glyph_for_cat("Site")) == "site", "site tab has its own glyph")
	_assert(str(ShopIcon.glyph_for("hands_hold")) == "hold", "hold ranks use the hold glyph")
	_assert(str(ShopIcon.glyph_for("shovel_super")) == "super_shovel", "tier-two shovel has a super glyph")
	var row: Panel = shop._buttons["hands_click"]
	_assert(row.icon != null, "Calloused Fingers has an icon well")


func _test_hands_is_a_chapter_without_a_gate() -> void:
	_assert(shop._chapters.has("Hands:1"), "Hands I is a chapter card")
	_assert(not shop._gates.has("Hands:1"), "Hands has no locked-chest gate")
	_assert(bool(shop._pages["Hands"].visible), "shop opens on Hands")
	_assert(not bool(shop._pages["Shovel"].visible), "other departments stay off-screen")


func _test_locked_shovel_two_is_a_chest_gate() -> void:
	_assert(shop._chapters.has("Shovel:2"), "Shovel II chapter exists")
	_assert(shop._gates.has("Shovel:2"), "Shovel II has a closed-chest gate")
	_assert(not bool(shop._chapters["Shovel:2"]["wrap"].visible), "locked Shovel II chapter stays hidden")
	_assert(bool(shop._gates["Shovel:2"]["wrap"].visible), "locked Shovel II shows the chest")
	_assert(str(shop._gates["Shovel:2"]["reason"].text).contains("Shovel I"), "chest tells you to max Shovel I")


func _test_unlock_offer_hides_zero_ranks() -> void:
	var row: Panel = shop._buttons["hands_hold"]
	_assert(str(row.title.text) == "Hold to Dig", "hold starts as the ability")
	_assert(not bool(row.pips.visible), "unlock offer hides 0/N pips")
	_assert(not bool(row.rank.visible), "unlock offer hides rank text")
	_assert(str(row.button.text).begins_with("Unlock"), "unlock offer keeps the Unlock button")


func _test_maxed_uses_a_seal() -> void:
	GS.levels["hands_click"] = 5
	GS.apply_upgrades()
	shop.refresh()
	var row: Panel = shop._buttons["hands_click"]
	_assert(bool(row.seal.visible), "maxed rank shows a seal")
	_assert(not bool(row.button.visible), "maxed rank hides the dead Buy button")
	_assert(str(row.rank.text) == "5 / 5", "maxed rank still shows the chunky count")


func _test_shop_effect_line_uses_live_ranks() -> void:
	_reset()
	_assert(GS.has_method("shop_effect_line"), "GameState exposes shop_effect_line")
	if not GS.has_method("shop_effect_line"):
		return
	_assert(str(GS.shop_effect_line("hands_hold")) == "Hold digs 23% faster", "Steady Hands is the hold-rate this-buy")
	_assert(str(GS.shop_effect_line("shovel_radius")) == "+1.0 cell radius", "Wider Scoop is the radius this-buy")
	_assert(str(GS.shop_effect_line("round_time")) == "+6s per shift", "Longer Shift is +6s")
	_assert(str(GS.shop_effect_line("spotlight")) == "Featured exhibit 2x", "unbought Spotlight is 2x")
	_assert(str(GS.shop_effect_line("unveil_time")) == "Unveil rush +6s", "Opening Hours is +6s rush")
	_assert(str(GS.shop_effect_line("lighting")) == "+20% exhibit income", "Warm Lights is +20% income")
	_assert(str(GS.shop_effect_line("hands_click")).contains("%"), "Calloused Fingers is a live percent")
	_assert(str(GS.shop_effect_line("hands_click")) != str(GS.shop_item_desc("hands_click")), "effect line is not flavor copy")
	_assert(not str(GS.shop_effect_line("round_time")).contains("Now "), "unbought effect has no Now")
	_assert(not str(GS.shop_effect_line("round_time")).contains("Next "), "unbought effect has no Next")
	var before_mult: float = float(TN.hands_click_mult)
	var before_level: int = int(GS.levels.get("hands_click", 0))
	GS.shop_effect_line("hands_click")
	_assert(int(GS.levels.get("hands_click", 0)) == before_level, "effect line does not buy a rank")
	_assert(is_equal_approx(float(TN.hands_click_mult), before_mult), "effect line restores Tuning")
	GS.levels["round_time"] = 1
	GS.apply_upgrades()
	_assert(str(GS.shop_effect_line("round_time")) == "+6s per shift", "Longer Shift this-buy stays +6s")
	_assert(not str(GS.shop_effect_line("round_time")).contains("Now "), "ranked Longer Shift has no Now")
	_assert(not str(GS.shop_effect_line("round_time")).contains("Next "), "ranked Longer Shift has no Next")
	GS.levels["spotlight"] = 1
	GS.apply_upgrades()
	_assert(str(GS.shop_effect_line("spotlight")) == "Featured exhibit 3x", "Spotlight this-buy is the next multiplier")
	GS.levels["spotlight"] = 3
	GS.apply_upgrades()
	_assert(str(GS.shop_effect_line("spotlight")) == "Featured exhibit 4x", "maxed Spotlight keeps 4x")
	_assert(not str(GS.shop_effect_line("spotlight")).contains("Now "), "maxed Spotlight has no Now")
	GS.levels["unveil_time"] = 1
	GS.apply_upgrades()
	_assert(str(GS.shop_effect_line("unveil_time")) == "Unveil rush +6s", "Opening Hours this-buy stays +6s")


func _test_shop_row_subtitle_is_this_buy() -> void:
	_reset()
	if not GS.has_method("shop_effect_line"):
		_assert(false, "shop rows can read shop_effect_line")
		return
	shop.refresh()
	var hold: Panel = shop._buttons["hands_hold"]
	var shift: Panel = shop._buttons["round_time"]
	_assert(str(hold.title.text) == "Hold to Dig", "hold title stays the unlock name")
	_assert(str(hold.desc.text) == "Hold digs 23% faster", "hold subtitle is what Unlock buys")
	_assert(str(shift.title.text) == "Longer Shift", "Longer Shift title stays the rank name")
	_assert(str(shift.desc.text) == "+6s per shift", "Longer Shift subtitle is what Buy $ buys")
	_assert(str(shift.button.text).begins_with("Buy"), "Longer Shift keeps Buy $")
	_assert(str(hold.tooltip_text).is_empty(), "hold row has no native tooltip")
	_assert(str(shift.tooltip_text).is_empty(), "Longer Shift has no native tooltip")
	_assert(str(hold.button.tooltip_text).is_empty(), "Unlock hover has no tooltip dump")
	_assert(str(shift.button.tooltip_text).is_empty(), "Buy hover has no tooltip dump")
	GS.levels["hands_hold"] = 1
	GS.apply_upgrades()
	shop.refresh()
	_assert(str(hold.desc.text) == str(GS.shop_effect_line("hands_hold")), "ranked hold subtitle tracks the next buy")
	_assert(not str(hold.desc.text).contains("Now "), "ranked hold subtitle has no Now")
	_assert(not str(hold.desc.text).contains("Hold digs faster."), "ranked hold does not show leftover flavor")


func _test_shop_hover_does_not_dump() -> void:
	_reset()
	shop.refresh()
	var row: Panel = shop._buttons["round_time"]
	_assert(str(row.tooltip_text).is_empty(), "row does not feed a Godot tooltip")
	_assert(str(row.button.tooltip_text).is_empty(), "Buy does not feed a Godot tooltip")
	_assert(not str(row.desc.text).contains("Now "), "subtitle is not a Now/Next wall")
	_assert(not str(row.desc.text).contains("Next "), "subtitle is not a Next spreadsheet")
	_assert(shop.get("_hover_tip") == null, "shop does not keep a hover spreadsheet")
	_assert(shop.get("_tip_layer") == null, "P5 CanvasLayer tip host is gone")
	if shop.has_method("show_item_tip"):
		shop.call("show_item_tip", row, "Now +6s per shift · Next +12s per shift")
		_assert(shop.get("_hover_tip") == null, "show_item_tip does not spawn a dump")
	_assert(row.has_method("_get_tooltip"), "row still swallows native hover")
	if row.has_method("_get_tooltip"):
		_assert(str(row.call("_get_tooltip", Vector2.ZERO)).is_empty(), "native tooltip getter is empty")


func _test_icon_wells_are_square() -> void:
	shop.refresh()
	for id in ["shovel_click", "shovel_hold", "shovel_radius", "hands_click"]:
		var row: Panel = shop._buttons[id]
		_assert(row.well != null, "%s has an icon well" % id)
		if row.well == null:
			continue
		var ms: Vector2 = row.well.custom_minimum_size
		_assert(is_equal_approx(ms.x, ms.y), "%s well min size is square" % id)
		_assert(ms.x >= 48.0 and ms.x <= 56.0, "%s well is a 48-56 square" % id)
		_assert((row.well.size_flags_horizontal & Control.SIZE_EXPAND) == 0, "%s well does not stretch wide" % id)
		_assert((row.well.size_flags_vertical & Control.SIZE_EXPAND) == 0, "%s well does not stretch tall" % id)
		if row.icon != null:
			_assert(is_equal_approx(row.icon.offset_left, 0.0), "%s icon has no left draw offset" % id)
			_assert(is_equal_approx(row.icon.offset_top, 0.0), "%s icon has no top draw offset" % id)
			_assert(is_equal_approx(row.icon.offset_right, 0.0), "%s icon has no right draw offset" % id)
			_assert(is_equal_approx(row.icon.offset_bottom, 0.0), "%s icon has no bottom draw offset" % id)
			_assert(is_equal_approx(row.icon.anchor_left, 0.0) and is_equal_approx(row.icon.anchor_right, 1.0), "%s icon spans the well width" % id)
			_assert(is_equal_approx(row.icon.anchor_top, 0.0) and is_equal_approx(row.icon.anchor_bottom, 1.0), "%s icon spans the well height" % id)


func _test_icon_glyphs_fill_the_well() -> void:
	shop.refresh()
	if shop._scroll != null:
		shop._scroll.size = Vector2(960, 560)
	shop._select_cat("Site")
	for _i in 8:
		await process_frame
	for id in ["round_time", "dirt_pay", "site_size", "scrap_bed"]:
		var row: Panel = shop._buttons[id]
		_assert(row != null and row.well != null and row.icon != null, "%s row has a well and icon" % id)
		if row == null or row.well == null or row.icon == null:
			continue
		_assert(row.icon.get_parent() == row.well, "%s icon is a child of the well" % id)
		_assert(is_equal_approx(row.icon.size.x, row.well.size.x), "%s icon width matches the well" % id)
		_assert(is_equal_approx(row.icon.size.y, row.well.size.y), "%s icon height matches the well" % id)
		_assert(is_equal_approx(row.icon.position.x, 0.0) and is_equal_approx(row.icon.position.y, 0.0), "%s icon origin is the well origin" % id)
		_assert(is_equal_approx(row.icon.size.x, row.icon.size.y), "%s icon stays square" % id)


func _test_super_tool_is_two_this_buy_bits() -> void:
	_reset()
	GS.levels["shovel_click"] = 6
	GS.levels["shovel_hold"] = 5
	GS.levels["shovel_radius"] = 4
	GS.apply_upgrades()
	shop.refresh()
	var line: String = str(GS.shop_effect_line("shovel_super"))
	_assert(not line.is_empty(), "Super Shovel has a this-buy line")
	_assert(not line.contains("Now "), "Super Shovel has no Now wall")
	_assert(not line.contains("Next "), "Super Shovel has no Next wall")
	var bits: PackedStringArray = line.split(" · ", false)
	_assert(bits.size() <= 2, "Super Shovel shows at most two this-buy bits")
	var plate: PackedStringArray = GS.next_goal_chip_lines("shovel_super", 1200)
	_assert(str(plate[0]) == "Next upgrade", "NEXT plate keeps a quiet caption")
	_assert(str(plate[plate.size() - 1]) == "$1200", "NEXT plate keeps a wallet price")
	_assert(plate.size() >= 3 + bits.size() - 1, "NEXT plate splits Super Shovel bits onto their own lines")
	var row: Panel = shop._buttons["shovel_super"]
	_assert(str(row.desc.text) == line, "Super Shovel subtitle is the this-buy line")
	_assert(str(row.tooltip_text).is_empty(), "Super Shovel has no hover dump")


func _test_affordable_tab_badges() -> void:
	_reset()
	GS.money = int(GS.cost_of("hands_click"))
	shop._user_picked_tab = false
	shop.refresh()
	var badge: Label = shop._tabs["Hands"]["badge"]
	_assert(bool(badge.visible), "affordable Hands tab shows a ready badge")
	_assert(str(badge.text) == "1", "Hands badge counts the glowing buy")


func _test_site_tab_opens_without_applying_layout() -> void:
	_reset()
	for id in ["round_time", "dirt_pay", "site_size", "scrap_bed"]:
		GS.levels[id] = int(_item(id).get("max", 1))
	GS.money = 91004
	GS.apply_upgrades()
	shop._user_picked_tab = true
	shop.refresh()
	_assert(int(shop._cat_glow_count("Site")) == 5, "five affordable Site rows can badge")
	TN.grid_w = 99
	TN.grid_h = 97
	if shop._scroll != null:
		shop._scroll.size = Vector2(960, 560)
	shop._select_cat("Site")
	for i in 8:
		await process_frame
	shop._fit_pages()
	shop._fit_pages()
	_assert(bool(shop._pages["Site"].visible), "Site tab shows the Site page")
	_assert(not bool(shop._pages["Brush"].visible), "other departments hide when Site opens")
	_assert(shop._chapters.has("Site:1"), "Site I is a chapter card")
	_assert(shop._chapters.has("Site:2"), "Site II chapter exists")
	_assert(shop._gates.has("Site:2"), "Site II has a chest gate")
	_assert(bool(shop._chapters["Site:1"]["wrap"].visible), "Site I chapter stays open")
	_assert(bool(shop._chapters["Site:2"]["wrap"].visible), "unlocked Site II chapter is open")
	_assert(shop._gates.has("Site:3"), "Site III still has a locked chest")
	_assert(not bool(shop._chapters["Site:3"]["wrap"].visible), "locked Site III chapter stays hidden")
	_assert(bool(shop._gates["Site:3"]["wrap"].visible), "locked Site III shows the chest")
	_assert(shop._buttons.has("site_size"), "Wider Claim row exists")
	_assert(shop._buttons.has("site_expand"), "Open Ground row exists")
	_assert(int(TN.grid_w) == 99 and int(TN.grid_h) == 97, "opening Site does not apply_site_layout")
	GS.buy("site_expand")
	shop.refresh()
	_assert(int(TN.grid_w) == 99 and int(TN.grid_h) == 97, "buying Open Ground in the shop does not apply_site_layout")
	var width_a: float = float(shop._pages_host.custom_minimum_size.x)
	shop._fit_pages()
	var width_b: float = float(shop._pages_host.custom_minimum_size.x)
	_assert(is_equal_approx(width_a, width_b), "fitting the Site page does not oscillate")


func _item(id: String) -> Dictionary:
	for entry in GS.catalog:
		if str(entry["id"]) == id:
			return entry
	return {}


func _assert(ok: bool, label: String) -> void:
	if ok:
		_passed += 1
		print("PASS  %s" % label)
	else:
		_failed += 1
		print("FAIL  %s" % label)
