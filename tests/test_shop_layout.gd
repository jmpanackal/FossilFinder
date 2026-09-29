extends SceneTree

## Shop tabs, tier gates, icons, unlock-then-rank chrome.
## Run: godot --headless --path <project> -s res://tests/test_shop_layout.gd

const ShopIcon := preload("res://shop_icon.gd")
const Ui := preload("res://ui_style.gd")

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
	_test_shop_has_no_second_bank()
	_test_shop_header_has_dig_museum_menu()
	_test_tabs_cover_every_department()
	_test_museum_has_unveil_rush_upgrades()
	_test_museum_has_spotlight_unlock()
	_test_fine_point_is_not_a_shop_row()
	_test_icons_exist_for_tools_and_ranks()
	_test_hands_is_a_chapter_without_a_gate()
	_test_locked_shovel_two_is_a_chest_gate()
	_test_apex_chapters_are_gated()
	_test_tier_title_has_roman_iv()
	_test_unlock_offer_hides_zero_ranks()
	_test_maxed_uses_a_seal()
	_test_affordable_tab_badges()
	await _test_chapter_tab_badges_stay_inside_tabs()
	_test_shop_effect_line_uses_live_ranks()
	_test_shop_copy_names_fossils_not_scraps()
	_test_blunted_point_keeps_a_description()
	_test_every_shop_row_has_an_effect_line()
	_test_shop_dollar_this_buy_is_at_least_a_cent()
	_test_ticket_this_buy_uses_hall_rate()
	_test_visitor_this_buy_uses_hall_rate()
	_test_late_ticket_this_buy_is_juicier()
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
	_assert(_find_button(shop, "Back") == null, "shop does not instance its own Back")
	_assert(_find_button(shop, "Menu") == null, "shop does not instance a Menu button")


func _test_shop_has_no_second_bank() -> void:
	_assert(shop.get("_wallet") == null, "shop does not host a second bank")
	var header_money: Label = null
	for raw in shop.get_children():
		if raw is Label:
			var text: String = str((raw as Label).text)
			if text.begins_with("$") and text.find(" ") < 0:
				header_money = raw as Label
	_assert(header_money == null, "shop header has no $ total")


func _test_shop_header_has_dig_museum_menu() -> void:
	var settings: Node = root.get_node_or_null("Settings")
	_assert(settings != null, "Settings hosts shop overlay nav")
	if settings == null:
		return
	if settings.has_method("set_nav_visible"):
		settings.call("set_nav_visible", true)
	_assert(settings.has_method("set_nav_context"), "Settings can show shop overlay nav")
	if settings.has_method("set_nav_context"):
		settings.call("set_nav_context", "shop")
	if settings.has_method("_layout_nav_chrome"):
		settings.call("_layout_nav_chrome")
	var dig: Button = settings.get("_dig_btn") as Button
	var museum: Button = settings.get("_museum_btn") as Button
	var menu: Button = settings.get("_menu_btn") as Button
	var back: Button = settings.get("_back_btn") as Button
	var upgrades: Button = settings.get("_upgrades_btn") as Button
	_assert(dig != null and str(dig.text) == "Dig" and dig.visible, "shop overlay has Dig")
	_assert(museum != null and str(museum.text) == "Museum" and museum.visible, "shop overlay has Museum")
	_assert(menu != null and str(menu.text) == "Menu" and menu.visible, "shop overlay has Menu")
	_assert(back == null or not back.visible, "shop overlay drops Back")
	_assert(upgrades == null or not upgrades.visible, "shop overlay does not show Upgrades")
	if dig != null and museum != null and menu != null:
		_assert(dig.global_position.x >= TN.view_w * 0.45, "shop Dig sits on the right")
		_assert(dig.global_position.y <= 16.0, "shop Dig sits in the header")
		_assert(menu.global_position.x > museum.global_position.x, "Menu is the rightmost shop button")
		_assert(menu.global_position.x + menu.size.x <= TN.view_w - 4.0, "shop Menu stays on screen")


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
	var expected: Array[String] = ["Hands", "Shovel", "Pickaxe", "Brush", "Site", "Museum"]
	_assert(shop.CATS == expected, "left rail lists every department")
	for cat in expected:
		_assert(shop._tabs.has(cat), "tab exists for %s" % cat)
		_assert(shop._pages.has(cat), "page exists for %s" % cat)
	if shop._tabs.has("Museum"):
		_assert(str(shop._tabs["Museum"]["caption"].text) == "Museum", "Museum tab caption says Museum")


func _test_museum_has_unveil_rush_upgrades() -> void:
	_assert(shop._buttons.has("unveil_time"), "Museum tab lists Opening Hours")
	_assert(shop._buttons.has("unveil_crowd"), "Museum tab lists Opening Crowd")
	_assert(str(_item("unveil_time").get("cat", "")) == "Museum", "Opening Hours is Museum")
	_assert(str(_item("unveil_crowd").get("cat", "")) == "Museum", "Opening Crowd is Museum")
	var hours: Panel = shop._buttons["unveil_time"]
	var crowd: Panel = shop._buttons["unveil_crowd"]
	_assert(str(hours.title.text) == "Opening Hours", "Opening Hours title stays Opening Hours")
	_assert(str(crowd.title.text) == "Opening Crowd", "Opening Crowd title stays Opening Crowd")
	_assert(str(hours.title.text).find(" ") >= 0, "Opening Hours title keeps its space")
	_assert(str(crowd.title.text).find(" ") >= 0, "Opening Crowd title keeps its space")
	_assert(str(hours.desc.text) == "Crowd surge on unveil +6s", "Opening Hours subtitle is surge on unveil")
	_assert(str(crowd.desc.text) == "+25% visitors on unveil", "Opening Crowd subtitle is visitors on unveil")
	_assert(not hours.title.clip_text, "Opening Hours title does not clip its space")
	_assert(not crowd.title.clip_text, "Opening Crowd title does not clip its space")
	_assert(not hours.desc.clip_text, "Opening Hours effect does not clip spaces")
	_assert(not crowd.desc.clip_text, "Opening Crowd effect does not clip spaces")


func _test_museum_has_spotlight_unlock() -> void:
	_assert(shop._buttons.has("spotlight"), "Museum tab lists Spotlight")
	_assert(str(_item("spotlight").get("cat", "")) == "Museum", "Spotlight is Museum")
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
	_assert(str(ShopIcon.glyph_for_cat("Museum")) == "exhibit", "Museum tab keeps the exhibit glyph")
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


func _test_apex_chapters_are_gated() -> void:
	_assert(shop._chapters.has("Hands:2"), "Hands II chapter exists")
	_assert(shop._gates.has("Hands:2"), "Hands II has a closed-chest gate")
	if shop._chapters.has("Hands:2") and shop._gates.has("Hands:2"):
		_assert(not bool(shop._chapters["Hands:2"]["wrap"].visible), "locked Hands II chapter stays hidden")
		_assert(bool(shop._gates["Hands:2"]["wrap"].visible), "locked Hands II shows the chest")
		_assert(str(shop._gates["Hands:2"]["title"].text).contains("Fieldcraft"), "Hands II is named Fieldcraft")
	_assert(shop._chapters.has("Shovel:3"), "Shovel III chapter exists")
	_assert(shop._gates.has("Shovel:3"), "Shovel III has a closed-chest gate")
	if shop._chapters.has("Shovel:3") and shop._gates.has("Shovel:3"):
		_assert(not bool(shop._chapters["Shovel:3"]["wrap"].visible), "locked Shovel III chapter stays hidden")
		_assert(str(shop._gates["Shovel:3"]["title"].text).contains("Titan"), "Shovel III is named Titan Shovel")
	_assert(shop._chapters.has("Pickaxe:3"), "Pickaxe III chapter exists")
	_assert(shop._gates.has("Pickaxe:3"), "Pickaxe III has a closed-chest gate")
	if shop._gates.has("Pickaxe:3"):
		_assert(str(shop._gates["Pickaxe:3"]["title"].text).contains("Titan"), "Pickaxe III is named Titan Pick")
	_assert(shop._chapters.has("Site:3"), "Site III chapter exists")
	if shop._gates.has("Site:3") and shop._chapters.has("Site:3"):
		_assert(str(shop._gates["Site:3"]["title"].text).contains("Grand Claim") or str(shop._chapters["Site:3"]["title"].text).contains("Grand Claim"), "Site III is named Grand Claim")
	_assert(shop._chapters.has("Museum:4"), "Museum IV chapter exists")
	_assert(shop._gates.has("Museum:4"), "Museum IV has a closed-chest gate")
	if shop._chapters.has("Museum:4") and shop._gates.has("Museum:4"):
		_assert(not bool(shop._chapters["Museum:4"]["wrap"].visible), "locked Museum IV chapter stays hidden")
		_assert(str(shop._gates["Museum:4"]["title"].text).contains("IV"), "Museum IV title uses roman IV")
		_assert(str(shop._gates["Museum:4"]["title"].text).contains("Blockbuster"), "Museum IV is named Blockbuster")
	_assert(shop._buttons.has("hands_craft"), "Hands tab lists Fieldcraft")
	_assert(shop._buttons.has("shovel_titan"), "Shovel tab lists Titan Shovel")
	_assert(shop._buttons.has("pick_titan"), "Pickaxe tab lists Titan Pick")
	_assert(shop._buttons.has("round_marathon"), "Site tab lists Marathon Shift")
	_assert(shop._buttons.has("blockbuster_ticket"), "Museum tab lists Blockbuster")


func _test_tier_title_has_roman_iv() -> void:
	_assert(str(GS.tier_title("Museum", 4)).contains("IV"), "tier_title prints Museum IV")
	_assert(str(GS.lock_reason("blockbuster_ticket")).contains("III"), "Museum IV lock names Museum III")
	_assert(not str(GS.tier_title("Museum", 4)).contains("III"), "Museum IV is not labeled III")


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
	_assert(str(GS.shop_effect_line("pick_radius")).find("cell radius") >= 0, "pick Wider Scoop is the radius this-buy")
	_assert(str(GS.shop_effect_line("round_time")) == "+6s per shift", "Longer Shift is +6s")
	_assert(str(GS.shop_effect_line("spotlight")) == "Featured exhibit 2x", "unbought Spotlight is 2x")
	_assert(str(GS.shop_effect_line("unveil_time")) == "Crowd surge on unveil +6s", "Opening Hours is +6s surge on unveil")
	_assert(str(GS.shop_effect_line("unveil_crowd")) == "+25% visitors on unveil", "Opening Crowd is +25% visitors on unveil")
	_assert(str(GS.shop_effect_line("lighting")).find("per visitor") >= 0, "Warm Lights is donation per visitor")
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
	_assert(str(GS.shop_effect_line("unveil_time")) == "Crowd surge on unveil +6s", "Opening Hours this-buy stays +6s on unveil")
	GS.levels["unveil_crowd"] = 1
	GS.apply_upgrades()
	_assert(str(GS.shop_effect_line("unveil_crowd")) == "+25% visitors on unveil", "Opening Crowd this-buy stays +25% on unveil")


func _test_shop_copy_names_fossils_not_scraps() -> void:
	_reset()
	var item: Dictionary = _item("scrap_bed")
	_assert(str(item.get("name", "")).find("Scrap") < 0, "Scattered Fossils title does not say Scrap")
	_assert(str(item.get("name", "")).find("scrap") < 0, "Scattered Fossils title does not say scrap")
	_assert(str(item.get("name", "")).find("Fossil") >= 0, "title names fossils")
	_assert(str(GS.shop_display_name("scrap_bed")).find("Fossil") >= 0, "unlock name names fossils")
	_assert(str(GS.shop_effect_line("scrap_bed")).find("scrap") < 0, "this-buy does not say scrap")
	_assert(str(GS.shop_effect_line("scrap_bed")).begins_with("Extra fossil odds"), "this-buy shows the extra fossil odds")
	_assert(str(item.get("desc", "")).find("scrap") < 0, "flavor does not say scrap")
	_assert(str(item.get("unlock_desc", "")).find("scrap") < 0, "unlock flavor does not say scrap")
	_assert(str(GS.upgrade_feel_line("scrap_bed")).find("scrap") < 0, "feel line does not say scrap")
	var rich: Dictionary = _item("rich_bed")
	_assert(str(GS.shop_effect_line("rich_bed")).find("scrap") < 0, "Rich Bed this-buy does not say scrap")
	_assert(str(GS.shop_effect_line("rich_bed")).find("fossil") >= 0, "Rich Bed this-buy names the extra fossil")
	_assert(str(rich.get("desc", "")).find("scrap") < 0, "Rich Bed flavor does not say scrap")
	GS.levels["scrap_bed"] = 1
	GS.apply_upgrades()
	_assert(str(GS.shop_display_name("scrap_bed")).find("Fossil") >= 0, "ranked title still names fossils")
	_assert(str(GS.shop_effect_line("scrap_bed")).contains("→"), "rank 2 this-buy shows odds before → after")


func _test_blunted_point_keeps_a_description() -> void:
	_reset()
	var line: String = str(GS.shop_effect_line("pick_soft"))
	_assert(not line.is_empty(), "Blunted Point has a this-buy line")
	_assert(line.contains("Great or Perfect"), "unbought Gentle Picking states the better-bone odds")
	_assert(str(GS.shop_effect_line("shovel_soft")) == line, "Gentle Digging uses the same odds this-buy")
	GS.levels["shovel_soft"] = 5
	GS.apply_upgrades()
	var floored: String = str(GS.shop_effect_line("pick_soft"))
	_assert(not floored.is_empty(), "Blunted Point still has a line after Soft Edge maxes the pool")
	_assert(floored.find("bone") >= 0, "floored Blunted Point says what it does to bone")
	shop.refresh()
	var row: Panel = shop._buttons["pick_soft"]
	_assert(str(row.desc.text) == floored, "Blunted Point row shows that line")
	_assert(not str(row.desc.text).is_empty(), "Blunted Point subtitle is not blank")


func _test_every_shop_row_has_an_effect_line() -> void:
	_reset()
	for item in GS.catalog:
		var id: String = str(item["id"])
		var line: String = str(GS.shop_effect_line(id))
		_assert(not line.is_empty(), "%s has a this-buy line" % id)
		_assert(not line.to_lower().contains("scrap"), "%s this-buy does not say scrap" % id)
	GS.levels["shovel_soft"] = 5
	GS.levels["pick_soft"] = 2
	GS.apply_upgrades()
	_assert(not str(GS.shop_effect_line("pick_soft")).is_empty(), "ranked Blunted Point stays described")
	_assert(not str(GS.shop_effect_line("shovel_soft")).is_empty(), "maxed Soft Edge stays described")


func _test_shop_dollar_this_buy_is_at_least_a_cent() -> void:
	_reset()
	for item in GS.catalog:
		var id: String = str(item["id"])
		var max_level: int = int(item.get("max", 1))
		for rank in range(0, max_level + 1):
			GS.levels[id] = rank
			GS.apply_upgrades()
			var line: String = str(GS.shop_effect_line(id))
			for amount in _shop_dollar_amounts(line):
				_assert(amount + 0.0001 >= 0.01, "%s rank %d this-buy is at least a cent (%s)" % [id, rank, line])
				_assert(line.find("$0.00") < 0, "%s rank %d does not format mill-cents (%s)" % [id, rank, line])
		GS.levels[id] = 0
	_reset()
	_assert(str(GS.shop_effect_line("lighting")) == "+$0.01 per visitor", "Warm Lights this-buy is +$0.01 per visitor")
	_assert(str(GS.shop_effect_line("benches")) == "+$0.01 per visitor", "Benches this-buy is +$0.01 per visitor")
	_assert(str(GS.shop_effect_line("labels")) == "+$0.01 per visitor", "Clear Labels this-buy is +$0.01 per visitor")
	_assert(str(GS.shop_effect_line("gift_shop")) == "+$0.02 per visitor", "Gift Counter this-buy is +$0.02 per visitor")
	_assert(str(GS.shop_effect_line("blockbuster_ticket")).find("per visitor") >= 0, "Box Office this-buy is per visitor")
	_assert(str(GS.shop_effect_line("blockbuster_ticket")).find("$0.00") < 0, "Box Office empty hall never prints $0.00 / sec")
	_assert(str(GS.shop_effect_line("blockbuster_ticket")).find("/ min") < 0, "Box Office stays in /sec")


func _pack_fifty_visitors() -> void:
	var ids := [
		"t_rex_skull", "t_rex_jaw", "t_rex_ribcage", "t_rex_femur", "t_rex_tail",
		"triceratops_skull", "triceratops_brow_horns", "triceratops_nose_horn",
		"triceratops_hind_limb", "triceratops_tail",
	]
	for id in ids:
		GS.install_find(id, id, 1.0, true)
	_assert(int(GS.museum_visitors()) == 50, "fixture packs 50 visitors")


func _per_visitor_dollars(line: String) -> float:
	var marker := " per visitor"
	var end: int = line.find(marker)
	if end < 0:
		return 0.0
	var start: int = line.rfind("$", end)
	if start < 0:
		return 0.0
	return float(line.substr(start + 1, end - start - 1))


func _test_ticket_this_buy_uses_hall_rate() -> void:
	_reset()
	var empty: String = str(GS.shop_effect_line("lighting"))
	_assert(empty.find("$0.00") < 0, "empty-hall Lights never prints $0.00 / sec")
	_assert(empty.find("/ sec") < 0, "empty-hall Lights has no $/sec headline")
	_assert(empty.find("/ min") < 0, "Lights stays in /sec")
	_assert(empty == "+$0.01 per visitor", "empty-hall Lights is +$0.01 per visitor only")
	_pack_fifty_visitors()
	var lights: String = str(GS.shop_effect_line("lighting"))
	_assert(lights.find("+$0.50 / sec") >= 0, "50 visitors Lights headline is +$0.50 / sec")
	_assert(lights.find("+$0.01 per visitor") >= 0, "Lights second bit is +$0.01 per visitor")
	_assert(lights.find("/ min") < 0, "packed Lights stays in /sec")
	var gift: String = str(GS.shop_effect_line("gift_shop"))
	_assert(gift.find("+$1.00 / sec") >= 0, "50 visitors Gift headline is +$1.00 / sec")
	_assert(gift.find("+$0.02 per visitor") >= 0, "Gift first rank is +$0.02 per visitor")


func _test_visitor_this_buy_uses_hall_rate() -> void:
	_reset()
	var empty: String = str(GS.shop_effect_line("glass_case"))
	_assert(empty.find("$0.00") < 0, "empty-hall Glass Case never prints $0.00 / sec")
	_assert(empty.find("/ sec") < 0, "empty-hall Glass Case has no $/sec headline")
	_assert(empty.find("visitor") >= 0, "empty-hall Glass Case is +N visitors")
	_pack_fifty_visitors()
	var glass: String = str(GS.shop_effect_line("glass_case"))
	_assert(glass.find("+$0.06 / sec") >= 0, "Glass Case packed headline is current ticket times new visitors")
	_assert(glass.find("+3 visitors") >= 0, "Glass Case still names +3 visitors")
	var crowds: String = str(GS.shop_effect_line("crowds"))
	_assert(crowds.find("+$0.16 / sec") >= 0, "Weekend Crowds packed headline uses current ticket")
	_assert(crowds.find("+8 visitors") >= 0, "Weekend Crowds still names +8 visitors")
	var sellout: String = str(GS.shop_effect_line("blockbuster_crowd"))
	_assert(sellout.find("/ sec") >= 0, "Sellout packed headline includes $/sec")
	_assert(sellout.find("visitor") >= 0, "Sellout packed line still names visitors")


func _test_late_ticket_this_buy_is_juicier() -> void:
	_reset()
	GS.levels["labels"] = 5
	GS.levels["gift_shop"] = 5
	GS.levels["blockbuster_ticket"] = 5
	GS.apply_upgrades()
	var labels: float = _per_visitor_dollars(str(GS.shop_effect_line("labels")))
	var gift: float = _per_visitor_dollars(str(GS.shop_effect_line("gift_shop")))
	var box: float = _per_visitor_dollars(str(GS.shop_effect_line("blockbuster_ticket")))
	_assert(labels + 0.0001 >= 0.05, "last Clear Labels this-buy is at least +$0.05 per visitor")
	_assert(gift + 0.0001 >= 0.05, "last Gift Counter this-buy is at least +$0.05 per visitor")
	_assert(box + 0.0001 >= 0.10, "last Box Office this-buy is at least +$0.10 per visitor")
	_assert(box + 0.0001 >= gift, "last Box Office is at least as juicy as last Gift")
	_reset()
	_assert(_per_visitor_dollars(str(GS.shop_effect_line("blockbuster_ticket"))) + 0.0001 >= 0.10, "first Box Office is already a late-ticket bump")


func _shop_dollar_amounts(line: String) -> Array[float]:
	var amounts: Array[float] = []
	var search_from: int = 0
	while true:
		var idx: int = line.find("$", search_from)
		if idx < 0:
			break
		var cursor: int = idx + 1
		var token: String = ""
		while cursor < line.length():
			var ch: String = line.substr(cursor, 1)
			if (ch >= "0" and ch <= "9") or ch == ".":
				token += ch
				cursor += 1
				continue
			break
		if not token.is_empty() and token != ".":
			amounts.append(float(token))
		search_from = cursor
	return amounts


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


func _test_chapter_tab_badges_stay_inside_tabs() -> void:
	_reset()
	GS.money = 999999
	shop._user_picked_tab = true
	shop.refresh()
	if shop._scroll != null:
		shop._scroll.size = Vector2(960, 560)
	shop._select_cat("Museum")
	for cat in shop.CATS:
		if not shop._tabs.has(cat):
			continue
		var show: Label = shop._tabs[cat]["badge"]
		if show == null:
			continue
		show.visible = true
		if str(show.text).is_empty():
			show.text = "2"
		show.add_theme_stylebox_override("normal", Ui.badge_box())
	for _i in 8:
		await process_frame
	_flush_chapter_tabs()
	var list_left: float = INF
	if shop._scroll != null:
		list_left = shop._scroll.global_position.x
	var corner: float = float(Ui.CORNER)
	for cat in shop.CATS:
		if not shop._tabs.has(cat):
			continue
		var button: Button = shop._tabs[cat]["button"]
		var badge: Label = shop._tabs[cat]["badge"]
		var caption: Label = shop._tabs[cat]["caption"]
		_assert(button != null and badge != null and caption != null, "%s tab has a button, badge, and caption" % cat)
		if button == null or badge == null or caption == null:
			continue
		_assert(bool(badge.visible), "%s tab shows a ready badge" % cat)
		if not badge.visible:
			continue
		var tab_rect: Rect2 = button.get_global_rect()
		var badge_rect: Rect2 = badge.get_global_rect()
		var caption_rect: Rect2 = caption.get_global_rect()
		var inner: Rect2 = tab_rect.grow(-corner)
		_assert(tab_rect.size.x > 1.0 and tab_rect.size.y > 1.0, "%s tab has a laid-out rect" % cat)
		if not inner.encloses(badge_rect):
			print("  %s tab=%s badge=%s caption=%s inner=%s" % [cat, tab_rect, badge_rect, caption_rect, inner])
		_assert(inner.encloses(badge_rect), "%s badge stays inside the tab, inset from the rounded corner" % cat)
		_assert(badge_rect.position.x + 0.5 >= caption_rect.end.x, "%s badge does not cover the word %s" % [cat, cat])
		_assert(tab_rect.end.x + 0.5 <= list_left, "%s tab does not grow over the shop list" % cat)


func _flush_chapter_tabs() -> void:
	for cat in shop.CATS:
		if not shop._tabs.has(cat):
			continue
		var button: Button = shop._tabs[cat]["button"]
		if button == null:
			continue
		button.notification(Control.NOTIFICATION_RESIZED)
		for raw in button.get_children():
			if raw is Container:
				(raw as Container).notification(Container.NOTIFICATION_SORT_CHILDREN)


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
