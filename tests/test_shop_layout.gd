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
	_test_tabs_cover_every_department()
	_test_icons_exist_for_tools_and_ranks()
	_test_hands_is_a_chapter_without_a_gate()
	_test_locked_shovel_two_is_a_chest_gate()
	_test_unlock_offer_hides_zero_ranks()
	_test_maxed_uses_a_seal()
	_test_affordable_tab_badges()
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


func _test_tabs_cover_every_department() -> void:
	var expected: Array[String] = ["Hands", "Shovel", "Pickaxe", "Brush", "Site", "Exhibit"]
	_assert(shop.CATS == expected, "left rail lists every department")
	for cat in expected:
		_assert(shop._tabs.has(cat), "tab exists for %s" % cat)
		_assert(shop._pages.has(cat), "page exists for %s" % cat)


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
