extends SceneTree

## Next-buy goal, shop glow, museum rate chip.
## Run: godot --headless --path <project> -s res://tests/test_shop_goal.gd

var _failed: int = 0
var _passed: int = 0
var GS: Node
var TN: Node


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	GS = root.get_node("GameState")
	TN = root.get_node("Tuning")
	_test_start_goal_is_first_hands_rank()
	_test_affordable_goal_glows()
	_test_too_rich_rows_dim()
	_test_next_goal_walks_catalog()
	_test_small_finds_goal_when_case_started()
	_test_affordable_shop_beats_small_finds()
	_test_museum_rate_line_stays_quiet_until_income()
	_test_chip_buys_affordable_goal()
	_test_hired_hand_is_not_an_early_goal()
	_test_next_goal_is_named_for_equipped_tool()
	_test_shovel_next_ignores_hand_and_site_ranks()
	_test_hand_ranks_only_next_when_hands_selected()
	_test_next_chip_uses_this_buy()
	_test_next_chip_lines_are_a_catalog_plate()
	_test_hud_goal_bar_is_gone()
	_test_next_shop_id_is_cheapest_in_that_tool_chapter()
	_test_next_shop_id_does_not_swap_when_money_changes()
	_test_shop_opens_from_shift_over()
	print("shop_goal %d passed, %d failed" % [_passed, _failed])
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


func _test_start_goal_is_first_hands_rank() -> void:
	_reset()
	_assert(GS.has_method("next_goal"), "GameState exposes next_goal")
	if not GS.has_method("next_goal"):
		return
	var goal: Dictionary = GS.next_goal()
	_assert(str(goal.get("kind", "")) == "shop", "start goal is a shop buy")
	_assert(str(goal.get("id", "")) == "hands_click", "start goal is Calloused Fingers")
	_assert(str(goal.get("title", "")).contains("$"), "goal bar names the price")
	_assert(not bool(goal.get("affordable", true)), "broke start is not glowing")
	_assert(float(goal.get("progress", 1.0)) < 1.0, "empty wallet does not fill the bar")


func _test_affordable_goal_glows() -> void:
	_reset()
	_assert(GS.has_method("shop_row_heat"), "GameState exposes shop_row_heat")
	if not GS.has_method("shop_row_heat") or not GS.has_method("next_goal"):
		return
	GS.money = int(GS.cost_of("hands_click"))
	_assert(str(GS.shop_row_heat("hands_click")) == "glow", "affordable shop row glows")
	var goal: Dictionary = GS.next_goal()
	_assert(str(goal.get("id", "")) == "hands_click", "chip shows the affordable buy")
	_assert(bool(goal.get("affordable", false)), "chip is marked affordable")
	_assert(is_equal_approx(float(goal.get("progress", 0.0)), 1.0), "affordable goal fills the bar")


func _test_too_rich_rows_dim() -> void:
	_reset()
	if not GS.has_method("shop_row_heat"):
		return
	GS.money = 5
	_assert(str(GS.shop_row_heat("hands_click")) == "dim", "too-rich unlocked row dims")
	_assert(str(GS.shop_row_heat("pick_click")) == "locked", "gated rows stay locked")
	GS.levels["hands_click"] = 5
	GS.apply_upgrades()
	_assert(str(GS.shop_row_heat("hands_click")) == "maxed", "maxed rows are marked maxed")


func _test_next_goal_walks_catalog() -> void:
	_reset()
	if not GS.has_method("next_goal"):
		return
	GS.money = 5000
	_assert(bool(GS.buy("hands_click")), "first hands rank buys")
	var goal: Dictionary = GS.next_goal()
	_assert(str(goal.get("id", "")) == "hands_click", "next Hands rank stays the cheapest Hands buy")
	_assert(bool(goal.get("affordable", false)), "leftover cash keeps the next buy glowing")
	GS.levels["hands_click"] = 5
	GS.apply_upgrades()
	goal = GS.next_goal()
	_assert(str(goal.get("id", "")) == "hands_hold", "maxed Calloused Fingers walks to Hold")


func _test_small_finds_goal_when_case_started() -> void:
	_reset()
	if not GS.has_method("next_goal"):
		return
	GS.install_find("tooth", "Tooth", 1.0, true)
	GS.money = 0
	var goal: Dictionary = GS.next_goal()
	_assert(str(goal.get("kind", "")) == "stand", "started Small Finds case becomes the nearer goal")
	_assert(str(goal.get("title", "")).contains("Small Finds"), "bar says Small Finds")
	_assert(str(goal.get("title", "")).contains("1/2"), "bar shows 1/2")
	_assert(float(goal.get("progress", 0.0)) > 0.4, "one scrap fills half the bar")


func _test_affordable_shop_beats_small_finds() -> void:
	_reset()
	if not GS.has_method("next_goal"):
		return
	GS.install_find("tooth", "Tooth", 1.0, true)
	GS.money = int(GS.cost_of("hands_click"))
	var goal: Dictionary = GS.next_goal()
	_assert(str(goal.get("kind", "")) == "shop", "a buy they can afford beats the case")
	_assert(str(goal.get("id", "")) == "hands_click", "chip still offers the affordable rank")


func _test_museum_rate_line_stays_quiet_until_income() -> void:
	_reset()
	_assert(GS.has_method("museum_rate_line"), "GameState exposes museum_rate_line")
	if not GS.has_method("museum_rate_line"):
		return
	_assert(str(GS.museum_rate_line()) == "", "no hall income stays off the dig HUD")
	GS.install_find("tooth", "Tooth", 1.0, true)
	var line: String = str(GS.museum_rate_line())
	_assert(line.contains("/s"), "hall income shows as a small $/s")
	_assert(line.contains("$"), "hall income keeps a dollar sign")


func _test_chip_buys_affordable_goal() -> void:
	_reset()
	_assert(GS.has_method("try_buy_next_goal"), "GameState exposes try_buy_next_goal")
	if not GS.has_method("try_buy_next_goal"):
		return
	GS.money = 0
	_assert(not bool(GS.try_buy_next_goal()), "broke chip click does not buy")
	GS.money = int(GS.cost_of("hands_click"))
	_assert(bool(GS.try_buy_next_goal()), "glowing chip buys in place")
	_assert(int(GS.levels.get("hands_click", 0)) == 1, "chip purchase ranks the goal")
	_assert(GS.money == 0, "chip spend takes the listed cost")


func _test_next_goal_is_named_for_equipped_tool() -> void:
	_reset()
	var goal: Dictionary = GS.next_goal(TN.TOOL_HANDS)
	_assert(str(goal.get("id", "")) == "hands_click", "hands start next is Calloused Fingers")
	_assert(str(goal.get("title", "")).begins_with("Hands ·"), "hands next names the tool")
	_assert(str(goal.get("title", "")).contains("Calloused Fingers"), "hands next names the rank")
	_assert(str(goal.get("title", "")).contains("$"), "hands next still shows the price")
	GS.money = 5000
	_assert(bool(GS.buy("shovel_click")), "shovel unlocks so a shovel next exists")
	var shovel_goal: Dictionary = GS.next_goal(TN.TOOL_SHOVEL)
	_assert(str(GS.tool_for_upgrade(str(shovel_goal.get("id", "")))) == str(TN.TOOL_SHOVEL), "shovel next stays on shovel ranks")
	_assert(str(shovel_goal.get("title", "")).begins_with("Shovel ·"), "shovel next names the shovel")
	_assert(str(shovel_goal.get("title", "")).contains("$"), "shovel next shows the price")


func _test_shovel_next_ignores_hand_and_site_ranks() -> void:
	_reset()
	GS.levels["shovel_click"] = 1
	GS.apply_upgrades()
	GS.money = 400
	var goal: Dictionary = GS.next_goal(TN.TOOL_SHOVEL)
	var id: String = str(goal.get("id", ""))
	_assert(not id.begins_with("hands"), "shovel next does not recommend hand ranks")
	_assert(id != "fossil_value", "shovel next does not offer Careful Hands")
	_assert(GS.tool_for_upgrade(id) == TN.TOOL_SHOVEL, "shovel next is a shovel buy")
	GS.money = int(GS.cost_of(id))
	_assert(bool(GS.try_buy_next_goal(TN.TOOL_SHOVEL)), "glowing shovel chip buys a shovel rank")
	_assert(int(GS.levels.get("hands_click", 0)) == 0, "buying shovel next leaves hands untouched")


func _test_hand_ranks_only_next_when_hands_selected() -> void:
	_reset()
	GS.levels["shovel_click"] = 1
	GS.apply_upgrades()
	GS.money = 340
	var hands: Dictionary = GS.next_goal(TN.TOOL_HANDS)
	_assert(GS.tool_for_upgrade(str(hands.get("id", ""))) == TN.TOOL_HANDS, "hands selected still offers a hand rank")
	_assert(str(hands.get("title", "")).begins_with("Hands ·"), "hands next stays labeled Hands")
	var shovel: Dictionary = GS.next_goal(TN.TOOL_SHOVEL)
	_assert(GS.tool_for_upgrade(str(shovel.get("id", ""))) == TN.TOOL_SHOVEL, "same wallet on shovel does not flip to hands")


func _test_next_chip_uses_this_buy() -> void:
	_reset()
	_assert(GS.has_method("next_goal_chip_text"), "GameState prints a NEXT chip line")
	if not GS.has_method("next_goal_chip_text"):
		return
	for id in ["brush_speed", "pick_click", "hands_click", "round_time", "shovel_click", "shovel_radius", "shovel_soft"]:
		var cost: int = 55 if id == "round_time" else 90
		var effect: String = str(GS.shop_effect_line(id))
		var caption: String = str(GS.next_goal_chip_text(id, cost))
		_assert(caption.contains(effect), "%s NEXT uses the shop this-buy line" % id)
		_assert(caption.contains("$%d" % cost), "%s NEXT still shows $" % id)
		_assert(caption.contains("Next upgrade"), "%s NEXT keeps the quiet caption" % id)
		_assert(not caption.contains("Now "), "%s NEXT has no Now wall" % id)
		var lines: PackedStringArray = GS.next_goal_chip_lines(id, cost)
		_assert(lines.size() >= 3, "%s NEXT is caption / effect / price" % id)
		_assert(str(lines[0]) == "Next upgrade", "%s first line is Next upgrade" % id)
		_assert(str(lines[lines.size() - 1]) == "$%d" % cost, "%s last line is the wallet price" % id)
		_assert(not " · ".join(lines).contains("Nextupgrade"), "%s caption keeps its space" % id)


func _test_next_chip_lines_are_a_catalog_plate() -> void:
	_reset()
	_assert(GS.has_method("next_goal_chip_lines"), "GameState prints NEXT plate lines")
	if not GS.has_method("next_goal_chip_lines"):
		return
	var effect: String = str(GS.shop_effect_line("pick_super"))
	_assert(effect.contains(" · "), "Super Pick this-buy has two bits")
	var lines: PackedStringArray = GS.next_goal_chip_lines("pick_super", 37655)
	_assert(str(lines[0]) == "Next upgrade", "plate caption is Next upgrade")
	_assert(str(lines[lines.size() - 1]) == "$37655", "plate price matches the wallet $digits style")
	_assert(lines.size() >= 4, "joined Super Pick bits become their own lines")
	_assert(not lines.has(effect), "the plate does not dump both Super Pick bits on one line")
	for raw in effect.split(" · ", false):
		var bit: String = str(raw).strip_edges()
		var shown: String = bit.replace("Hold digs ", "Hold-dig ")
		var found: bool = false
		for line in lines:
			if str(line) == bit or str(line) == shown:
				found = true
				_assert(str(line).find("  ") < 0, "Super Pick bit is not double-spaced")
				if shown.find(" ") >= 0 or bit.find(" ") >= 0:
					_assert(str(line).find(" ") >= 0 or str(line).find("-") >= 0, "Super Pick bit keeps its words apart")
		_assert(found, "plate keeps %s" % bit)


func _test_hud_next_chip_prints_equipped_buy() -> void:
	_reset()
	GS.levels["shovel_click"] = 1
	GS.apply_upgrades()
	GS.money = 167
	var hud: CanvasLayer = _make_hud()
	if hud == null:
		return
	hud.call("refresh", 40.0, 40.0, TN.TOOL_SHOVEL, true)
	var chip: Button = hud.get("_chip") as Button
	_assert(chip != null, "HUD exposes the NEXT chip")
	if chip == null:
		hud.queue_free()
		return
	_assert(chip.visible, "NEXT chip shows when the equipped tool has a buy")
	var caption: String = _chip_caption(hud, chip)
	_assert(not caption.is_empty(), "NEXT chip is not an empty brown box")
	var shop_id: String = str(GS.next_shop_id(TN.TOOL_SHOVEL))
	var effect: String = str(GS.shop_effect_line(shop_id))
	_assert(not effect.is_empty() and _caption_has_effect(caption, effect), "NEXT chip uses the shop this-buy line")
	_assert(caption.contains("Shovel") or caption.contains("Next"), "NEXT plate names Shovel or says Next")
	_assert(caption.contains("$"), "NEXT chip shows the price")
	_assert(not caption.contains("Next shovel upgrade"), "NEXT chip no longer hides behind Next shovel upgrade")
	_assert(not chip.clip_contents, "NEXT chip does not square-clip the rounded brass")
	_assert(not chip.clip_text, "NEXT plate does not clip mid-word")
	var ink: Color = chip.get_theme_color("font_color")
	_assert(ink.r + ink.g + ink.b > 1.8, "NEXT chip uses light text on the brown pill")
	hud.queue_free()


func _test_hud_next_plates_show_all_owned_tools() -> void:
	_reset()
	GS.money = 5000
	GS.buy("shovel_click")
	GS.buy("pick_click")
	var hud: CanvasLayer = _make_hud()
	if hud == null:
		return
	hud.call("refresh", 40.0, 40.0, TN.TOOL_HANDS, true)
	var shown: Array = _visible_next_plates(hud)
	_assert(shown.size() >= 3, "Hands selected still shows a plate for every owned tool")
	var tools: Array = []
	for raw in shown:
		tools.append(_plate_tool(hud, raw as Button))
	_assert(tools.has(TN.TOOL_HANDS) and tools.has(TN.TOOL_SHOVEL) and tools.has(TN.TOOL_PICKAXE), "selected-only NEXT is gone")
	_assert(not tools.has(TN.TOOL_BRUSH), "unowned brush still hides its plate")
	hud.queue_free()


func _test_hud_goal_bar_is_gone() -> void:
	_reset()
	GS.levels["shovel_click"] = 1
	GS.apply_upgrades()
	GS.money = 167
	var hud: CanvasLayer = _make_hud()
	if hud == null:
		return
	hud.call("refresh", 40.0, 40.0, TN.TOOL_SHOVEL, true)
	_assert(hud.get("_goal_wrap") == null, "cream goal bar wrapper is gone")
	_assert(hud.get("_goal_track") == null, "cream goal track is gone")
	_assert(hud.get("_goal_fill") == null, "cream goal fill is gone")
	_assert(hud.get("_goal_label") == null, "silent goal-bar label is gone")
	_assert(hud.get("_chip") == null, "NEXT buy control left the live HUD")
	_assert(not hud.has_signal("shop_pressed"), "HUD has no mid-shift shop door")
	_assert(hud.get("_work_card") == null, "right rail is empty field, not a working find or shop plate")
	hud.queue_free()


func _test_shop_opens_from_shift_over() -> void:
	_reset()
	var packed: PackedScene = load("res://main.tscn") as PackedScene
	_assert(packed != null, "main.tscn loads")
	if packed == null:
		return
	var main: Node = packed.instantiate()
	root.add_child(main)
	var title: Node = main.get_node_or_null("Title")
	if title != null:
		var start: Variant = title.get("_start")
		if start is Button:
			start.pressed.emit()
	var hud: Node = main.get_node_or_null("HUD")
	_assert(hud != null and not hud.has_signal("shop_pressed"), "shop is not wired from the live HUD")
	if hud != null and hud.has_signal("end_shift"):
		hud.end_shift.emit()
	var summary: Node = main.get_node_or_null("Summary")
	_assert(summary != null and bool(summary.visible), "shift-over card still opens")
	var upgrades: Button = _find_summary_button(summary, "Upgrades")
	_assert(upgrades != null, "shift-over still has Upgrades")
	if upgrades != null:
		upgrades.pressed.emit()
	_assert(str(main.screen) == "shop", "Upgrades from shift-over opens the shop")
	var shop: Node = main.get_node_or_null("Shop")
	_assert(shop != null and bool(shop.visible), "the shop overlay still exists")
	if main.get_tree() != null:
		main.get_tree().paused = false
	main.free()


func _find_summary_button(node: Node, text: String) -> Button:
	if node == null:
		return null
	if node is Button and str((node as Button).text) == text:
		return node as Button
	for child in node.get_children():
		var found: Button = _find_summary_button(child, text)
		if found != null:
			return found
	return null


func _test_next_shop_id_is_cheapest_in_that_tool_chapter() -> void:
	_reset()
	_assert(str(GS.next_shop_id(TN.TOOL_HANDS)) == "hands_click", "Hands next is the cheapest Hands buy")
	GS.levels["shovel_click"] = 1
	GS.apply_upgrades()
	_assert(str(GS.next_shop_id(TN.TOOL_SHOVEL)) == "shovel_click", "Shovel next is the cheapest remaining shovel rank, not Hold")
	_assert(GS.tool_for_upgrade(str(GS.next_shop_id(TN.TOOL_SHOVEL))) == TN.TOOL_SHOVEL, "Shovel next stays in the shovel chapter")
	_assert(str(GS.next_shop_id(TN.TOOL_HANDS)) == "hands_click", "Hands next ignores the shovel chapter")


func _test_next_shop_id_does_not_swap_when_money_changes() -> void:
	_reset()
	GS.levels["shovel_click"] = 1
	GS.levels["pick_click"] = 1
	GS.levels["brush_speed"] = 1
	GS.apply_upgrades()
	var tools: Array = [TN.TOOL_HANDS, TN.TOOL_SHOVEL, TN.TOOL_PICKAXE, TN.TOOL_BRUSH]
	var broke: Dictionary = {}
	GS.money = 0
	for tool in tools:
		broke[tool] = str(GS.next_shop_id(tool))
		_assert(not str(broke[tool]).is_empty(), "%s still has a next buy" % GS.tool_display_name(tool))
	_assert(str(broke[TN.TOOL_HANDS]) == "hands_click", "broke Hands plate is Calloused Fingers, not Hold")
	_assert(str(broke[TN.TOOL_SHOVEL]) == "shovel_click", "broke Shovel plate is the cheap rank, not a later unlock")
	GS.money = 40
	for tool in tools:
		_assert(str(GS.next_shop_id(tool)) == str(broke[tool]), "%s next does not swap when $40 can buy a cheaper rank" % GS.tool_display_name(tool))
	GS.money = int(GS.cost_of("hands_hold"))
	_assert(str(GS.next_shop_id(TN.TOOL_HANDS)) == "hands_click", "Hands does not jump to Hold just because Hold is now affordable")
	_assert(str(GS.next_shop_id(TN.TOOL_SHOVEL)) == str(broke[TN.TOOL_SHOVEL]), "Shovel stays on its cheap rank when Hands Hold is affordable")
	GS.money = 99999
	for tool in tools:
		_assert(str(GS.next_shop_id(tool)) == str(broke[tool]), "%s next does not swap on a fat wallet" % GS.tool_display_name(tool))
	_assert(str(GS.next_shop_id(TN.TOOL_SHOVEL)) == str(broke[TN.TOOL_SHOVEL]), "selecting Hands would not change the shovel SKU")


func _test_hud_next_plates_keep_sku_when_money_changes() -> void:
	_reset()
	GS.money = 5000
	GS.buy("shovel_click")
	GS.buy("pick_click")
	GS.buy("brush_speed")
	GS.money = 0
	var hud: CanvasLayer = _make_hud()
	if hud == null:
		return
	hud.call("refresh", 40.0, 40.0, TN.TOOL_HANDS, true)
	var broke_keys: Dictionary = {}
	for tool in [TN.TOOL_HANDS, TN.TOOL_SHOVEL, TN.TOOL_PICKAXE, TN.TOOL_BRUSH]:
		var plate: Button = _plate_for_tool(hud, tool)
		_assert(plate != null and plate.visible, "%s plate stays up while broke" % GS.tool_display_name(tool))
		broke_keys[tool] = str(GS.next_shop_id(tool))
	GS.money = 40
	hud.call("refresh", 40.0, 40.0, TN.TOOL_PICKAXE, true)
	var keys: Variant = hud.get("_plate_keys")
	for tool in broke_keys.keys():
		_assert(str(GS.next_shop_id(tool)) == str(broke_keys[tool]), "%s HUD SKU stays put at $40" % GS.tool_display_name(tool))
		if keys is PackedStringArray or keys is Array:
			var plate: Button = _plate_for_tool(hud, tool)
			var caption: String = _chip_caption(hud, plate)
			_assert(_caption_has_effect(caption, str(GS.shop_effect_line(str(broke_keys[tool])))), "%s plate still names the same this-buy" % GS.tool_display_name(tool))
	hud.queue_free()


func _test_hud_next_chip_shows_maxed() -> void:
	_reset()
	for item in GS.catalog:
		var id: String = str(item["id"])
		if GS.tool_for_upgrade(id) == TN.TOOL_SHOVEL:
			GS.levels[id] = int(item["max"])
	GS.apply_upgrades()
	GS.install_find("tooth", "Tooth", 1.0, true)
	_assert(str(GS.next_shop_id(TN.TOOL_SHOVEL)).is_empty(), "maxed shovel has no leftover SKU")
	var hud: CanvasLayer = _make_hud()
	if hud == null:
		return
	hud.call("refresh", 40.0, 40.0, TN.TOOL_SHOVEL, true)
	var chip: Button = _plate_for_tool(hud, TN.TOOL_SHOVEL)
	if chip == null:
		chip = hud.get("_chip") as Button
	_assert(chip != null, "HUD exposes the shovel plate")
	if chip != null:
		_assert(chip.visible, "maxed shovel keeps its plate")
		var caption: String = _chip_caption(hud, chip)
		_assert(caption.contains("Maxed") or caption.contains("maxed"), "maxed shovel plate reads Maxed")
		_assert(caption.contains("Shovel") or caption.contains("shovel"), "maxed copy still names Shovel")
		_assert(not caption.contains("$"), "maxed plate is not a buy")
		_assert(chip.disabled, "maxed plate is not clickable-as-success")
		var before_money: int = int(GS.money)
		chip.pressed.emit()
		_assert(int(GS.money) == before_money, "clicking maxed shovel does not spend")
	var hands: Button = _plate_for_tool(hud, TN.TOOL_HANDS)
	_assert(hands != null and hands.visible, "maxed shovel does not hide the hands plate")
	_assert(not str(GS.next_shop_id(TN.TOOL_HANDS)).is_empty(), "hands still has its own next buy")
	hud.queue_free()


func _test_hud_next_plate_afford_vs_unafford_chrome() -> void:
	_reset()
	GS.levels["shovel_click"] = 1
	GS.apply_upgrades()
	GS.money = 0
	var hud: CanvasLayer = _make_hud()
	if hud == null:
		return
	hud.call("refresh", 40.0, 40.0, TN.TOOL_SHOVEL, true)
	if hud.has_method("_process"):
		hud._process(0.016)
	var plate: Button = _plate_for_tool(hud, TN.TOOL_SHOVEL)
	_assert(plate != null and plate.visible, "shovel plate shows while broke")
	if plate == null:
		hud.queue_free()
		return
	var shop_id: String = str(GS.next_shop_id(TN.TOOL_SHOVEL))
	var cost: int = int(GS.cost_of(shop_id))
	var broke_caption: String = _chip_caption(hud, plate)
	_assert(broke_caption.contains("$%d" % cost), "unaffordable plate still shows the price")
	_assert(plate.disabled, "unaffordable plate is not clickable-as-success")
	_assert(_plate_is_muted(plate), "unaffordable plate is muted")
	var price: Label = _plate_price_label(hud, plate)
	_assert(price != null and str(price.text).begins_with("$"), "unaffordable price stays on its own line")
	if price != null:
		_assert(_color_is_muted(price.get_theme_color("font_color")), "unaffordable price is muted, not live gold")
	GS.money = cost
	hud.call("refresh", 40.0, 40.0, TN.TOOL_SHOVEL, true)
	if hud.has_method("_process"):
		hud._process(0.016)
	_assert(str(GS.next_shop_id(TN.TOOL_SHOVEL)) == shop_id, "crossing the price does not swap the SKU")
	_assert(not plate.disabled, "affordable plate can buy")
	_assert(_plate_looks_live(plate), "affordable plate looks live")
	var rich_caption: String = _chip_caption(hud, plate)
	_assert(rich_caption.contains("$%d" % cost), "affordable plate keeps a loud price")
	if price != null:
		var gold: Color = price.get_theme_color("font_color")
		_assert(gold.r > 0.75 and gold.g > 0.55 and gold.b < 0.55, "affordable price is gold")
	hud.queue_free()


func _test_hud_next_chip_uses_shop_effect() -> void:
	_reset()
	_assert(GS.has_method("shop_effect_line"), "GameState exposes shop_effect_line for NEXT")
	if not GS.has_method("shop_effect_line"):
		return
	GS.levels["shovel_click"] = 1
	GS.apply_upgrades()
	GS.money = 167
	var hud: CanvasLayer = _make_hud()
	if hud == null:
		return
	hud.call("refresh", 40.0, 40.0, TN.TOOL_SHOVEL, true)
	var chip: Button = hud.get("_chip") as Button
	_assert(chip != null, "HUD exposes the NEXT chip")
	if chip == null:
		hud.queue_free()
		return
	var shop_id: String = str(GS.next_shop_id(TN.TOOL_SHOVEL))
	var effect: String = str(GS.shop_effect_line(shop_id))
	_assert(_caption_has_effect(_chip_caption(hud, chip), effect), "NEXT chip caption uses shop_effect_line")
	_assert(str(chip.tooltip_text).is_empty(), "NEXT chip has no hover dump")
	hud.queue_free()


func _test_hud_next_chip_is_a_catalog_plate() -> void:
	_reset()
	GS.levels["pick_click"] = 6
	GS.levels["pick_hold"] = 5
	GS.levels["pick_soft"] = 5
	GS.apply_upgrades()
	GS.money = 0
	var hud: CanvasLayer = _make_hud()
	if hud == null:
		return
	hud.call("refresh", 40.0, 40.0, TN.TOOL_PICKAXE, true)
	if hud.has_method("_process"):
		hud._process(0.016)
	var chip: Button = hud.get("_chip") as Button
	_assert(chip != null and chip.visible, "pick NEXT still shows when Super Pick is the buy")
	if chip == null:
		hud.queue_free()
		return
	var caption: Label = hud.get("_chip_caption") as Label
	var price: Label = hud.get("_chip_price") as Label
	_assert(caption != null and (str(caption.text) == "Pickaxe" or str(caption.text) == "Next"), "quiet caption is its own line")
	_assert(price != null and str(price.text).begins_with("$"), "loud price is its own line")
	_assert(price != null and str(price.text).find(",") < 0, "NEXT price matches wallet $digits")
	if caption != null and price != null:
		_assert(price.get_theme_font_size("font_size") > caption.get_theme_font_size("font_size"), "price is louder than the caption")
		_assert(not caption.clip_text, "caption does not clip its space")
		_assert(_copy_fits(caption), "quiet caption is wide enough to keep its space")
	var shop_id: String = str(GS.next_shop_id(TN.TOOL_PICKAXE))
	var bits: PackedStringArray = str(GS.shop_effect_line(shop_id)).split(" · ", false)
	_assert(bits.size() >= 2, "pick NEXT is a two-bit Super Pick buy")
	var fx_labels: Array[Label] = _chip_effect_labels(hud)
	_assert(fx_labels.size() >= 2, "each Super Pick bit gets its own line")
	for i in mini(bits.size(), fx_labels.size()):
		var bit: String = str(bits[i]).strip_edges()
		var shown: String = str(fx_labels[i].text)
		_assert(shown == bit or shown == bit.replace("Hold digs ", "Hold-dig "), "effect line keeps %s" % bit)
		_assert(shown.find("pickclick") < 0 and shown.find("Holdold") < 0, "effect line is not smashed")
		_assert(not fx_labels[i].clip_text, "effect line does not clip spaces")
		_assert(_copy_fits(fx_labels[i]), "effect line keeps its words")
	_assert(chip.disabled, "unaffordable Super Pick plate is not clickable-as-success")
	_assert(_plate_is_muted(chip), "unaffordable Super Pick plate is muted")
	_assert(price != null and str(price.text).begins_with("$"), "unaffordable Super Pick still shows the price")
	GS.money = int(GS.cost_of(shop_id))
	hud.call("refresh", 40.0, 40.0, TN.TOOL_PICKAXE, true)
	if hud.has_method("_process"):
		hud._process(0.016)
	_assert(not chip.disabled, "affordable NEXT still buys in place")
	_assert(_plate_looks_live(chip), "affordable Super Pick plate looks live")
	hud.queue_free()


func _test_hud_next_plates_keep_tool_glyphs() -> void:
	_reset()
	GS.money = 5000
	GS.buy("shovel_click")
	var hud: CanvasLayer = _make_hud()
	if hud == null:
		return
	hud.call("refresh", 40.0, 40.0, TN.TOOL_HANDS, true)
	var shovel: Button = _plate_for_tool(hud, TN.TOOL_SHOVEL)
	_assert(shovel != null and shovel.visible, "shovel NEXT plate still shows")
	if shovel == null:
		hud.queue_free()
		return
	var icon: Node = _find_tool_icon(shovel)
	_assert(icon != null, "shovel NEXT plate has the shovel glyph")
	if icon != null:
		_assert(int(icon.get("tool_id")) == int(TN.TOOL_SHOVEL), "plate glyph is the shovel, not the selected tool")
		var mark: Control = icon as Control
		_assert(is_equal_approx(mark.size.x, 22.0) and is_equal_approx(mark.size.y, 22.0), "shovel NEXT glyph is the shared 22px tool box")
		var row: Node = mark.get_parent()
		_assert(row is HBoxContainer and int((row as HBoxContainer).get_theme_constant("separation")) == 8, "shovel NEXT keeps an 8px gap before the tool name")
	var caption: String = _chip_caption(hud, shovel)
	_assert(_caption_has_effect(caption, str(GS.shop_effect_line(str(GS.next_shop_id(TN.TOOL_SHOVEL))))), "glyph plate still shows the this-buy line")
	_assert(caption.contains("$"), "glyph plate still shows $")
	var shop_id: String = str(GS.next_shop_id(TN.TOOL_SHOVEL))
	var before: int = int(GS.levels.get(shop_id, 0))
	GS.money = int(GS.cost_of(shop_id))
	hud.call("refresh", 40.0, 40.0, TN.TOOL_HANDS, true)
	shovel.pressed.emit()
	_assert(int(GS.levels.get(shop_id, 0)) == before + 1, "click-to-buy is unchanged with the glyph")
	hud.queue_free()


func _find_tool_icon(node: Node) -> Node:
	if node == null:
		return null
	var script: Script = node.get_script() as Script
	if script != null and str(script.resource_path).ends_with("tool_icon.gd"):
		return node
	for child in node.get_children():
		var found: Node = _find_tool_icon(child)
		if found != null:
			return found
	return null


func _make_hud() -> CanvasLayer:
	var hud_script: Script = load("res://hud.gd") as Script
	_assert(hud_script != null, "HUD script loads")
	if hud_script == null:
		return null
	var hud: CanvasLayer = hud_script.new() as CanvasLayer
	root.add_child(hud)
	return hud


func _chip_caption(hud: Node, chip: Button) -> String:
	var parts: PackedStringArray = PackedStringArray()
	_collect_text(chip, parts)
	var joined: String = " ".join(parts).strip_edges()
	if not joined.is_empty():
		return joined
	var caption: Label = hud.get("_chip_caption") as Label
	var price: Label = hud.get("_chip_price") as Label
	if caption != null and not str(caption.text).is_empty():
		parts.append(str(caption.text))
	if price != null and not str(price.text).is_empty():
		parts.append(str(price.text))
	return " ".join(parts)


func _collect_text(node: Node, parts: PackedStringArray) -> void:
	if node is Label:
		var text: String = str(node.text).strip_edges()
		if not text.is_empty():
			parts.append(text)
	elif node is Button:
		var text: String = str(node.text).strip_edges()
		if not text.is_empty():
			parts.append(text)
	for child in node.get_children():
		_collect_text(child, parts)


func _caption_has_effect(caption: String, effect: String) -> bool:
	if caption.contains(effect):
		return true
	for raw in effect.split(" · ", false):
		var bit: String = str(raw).strip_edges()
		if bit.is_empty():
			continue
		if not (caption.contains(bit) or caption.contains(bit.replace("Hold digs ", "Hold-dig "))):
			return false
	return not effect.is_empty()


func _chip_effect_labels(hud: Node) -> Array[Label]:
	var labels: Array[Label] = []
	var box: Node = hud.get("_chip_fx")
	if box != null:
		for child in box.get_children():
			if child is Label and not str(child.text).is_empty():
				labels.append(child)
	return labels


func _copy_fits(label: Label) -> bool:
	if label == null:
		return false
	if label.clip_text:
		return false
	if label.autowrap_mode != TextServer.AUTOWRAP_OFF:
		return not str(label.text).contains("  ")
	var font: Font = label.get_theme_font("font")
	if font == null:
		return false
	var size: int = label.get_theme_font_size("font_size")
	var need: float = font.get_string_size(str(label.text), HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	return maxf(label.get_combined_minimum_size().x, label.size.x) + 0.5 >= need


func _all_next_plates(hud: Node) -> Array:
	var raw: Variant = hud.get("_next_plates")
	if raw is Array:
		return raw
	var chip: Button = hud.get("_chip") as Button
	if chip != null:
		return [chip]
	return []


func _visible_next_plates(hud: Node) -> Array:
	var shown: Array = []
	for raw in _all_next_plates(hud):
		var plate: Button = raw as Button
		if plate != null and plate.visible:
			shown.append(plate)
	return shown


func _plate_for_tool(hud: Node, tool: int) -> Button:
	for raw in _all_next_plates(hud):
		var plate: Button = raw as Button
		if plate != null and _plate_tool(hud, plate) == tool:
			return plate
	return null


func _plate_tool(hud: Node, plate: Button) -> int:
	if plate != null and plate.has_meta("tool"):
		return int(plate.get_meta("tool"))
	var plates: Array = _all_next_plates(hud)
	var tools: Variant = hud.get("_plate_tools")
	if tools is Array:
		for i in plates.size():
			if plates[i] == plate and i < tools.size():
				return int(tools[i])
	return -1


func _test_hud_next_plates_match_tool_cards() -> void:
	_reset()
	GS.money = 5000
	GS.buy("shovel_click")
	GS.buy("pick_click")
	GS.buy("brush_speed")
	var hud: CanvasLayer = _make_hud()
	if hud == null:
		return
	hud.call("refresh", 40.0, 40.0, TN.TOOL_HANDS, true)
	var matched: int = 0
	var buttons: Array = hud.get("_tool_buttons") as Array
	var slot_tools: Array = hud.get("_slot_tools") as Array
	for i in slot_tools.size():
		var button: Button = buttons[i] as Button if i < buttons.size() else null
		var plate: Button = _plate_for_tool(hud, int(slot_tools[i]))
		if button == null or plate == null or not button.visible or not plate.visible:
			continue
		matched += 1
		var card := Vector2(maxf(button.size.x, button.custom_minimum_size.x), maxf(button.size.y, button.custom_minimum_size.y))
		var plate_size := Vector2(maxf(plate.size.x, plate.custom_minimum_size.x), maxf(plate.size.y, plate.custom_minimum_size.y))
		_assert(is_equal_approx(card.y, 110.0), "%s tool card stays 110px" % GS.tool_display_name(int(slot_tools[i])))
		_assert(is_equal_approx(plate_size.x, card.x) and is_equal_approx(plate_size.y, card.y), "%s NEXT plate matches the tool card size" % GS.tool_display_name(int(slot_tools[i])))
	_assert(matched == 4, "all four owned tools compare NEXT size to the left card")
	hud.queue_free()


func _test_hud_rail_section_labels() -> void:
	_reset()
	var hud: CanvasLayer = _make_hud()
	if hud == null:
		return
	hud.call("refresh", 40.0, 40.0, TN.TOOL_HANDS, true)
	var tools: Label = _rail_section_label(hud, "Tools")
	var upgrades: Label = _rail_section_label(hud, "Next Upgrades")
	_assert(tools != null and str(tools.text) == "Tools", "left rail is labeled Tools")
	_assert(upgrades != null and str(upgrades.text) == "Next Upgrades", "right rail is labeled Next Upgrades")
	if tools == null or upgrades == null:
		hud.queue_free()
		return
	var pit: Rect2 = TN.pit_grid_rect() if TN.has_method("pit_grid_rect") else Rect2(TN.grid_origin, Vector2(float(TN.grid_w) * TN.cell_w, float(TN.grid_h) * TN.cell_h))
	_assert(not pit.intersects(Rect2(tools.global_position if tools.global_position != Vector2.ZERO else tools.position, tools.size)), "Tools label stays off the pit")
	_assert(not pit.intersects(Rect2(upgrades.global_position if upgrades.global_position != Vector2.ZERO else upgrades.position, upgrades.size)), "Next Upgrades label stays off the pit")
	hud.queue_free()


func _rail_section_label(hud: Node, text: String) -> Label:
	for raw in [hud.get("_tools_label"), hud.get("_upgrades_label")]:
		var label: Label = raw as Label
		if label != null and str(label.text) == text:
			return label
	return _find_label_with_text(hud, text)


func _find_label_with_text(node: Node, text: String) -> Label:
	if node is Label and str((node as Label).text) == text:
		return node as Label
	for child in node.get_children():
		var found: Label = _find_label_with_text(child, text)
		if found != null:
			return found
	return null


func _test_hired_hand_is_not_an_early_goal() -> void:
	_reset()
	if not GS.has_method("next_goal"):
		return
	GS.money = 99999
	var goal: Dictionary = GS.next_goal()
	_assert(str(goal.get("id", "")) != "passive_miner", "Hired Hand is never the early next buy")
	_assert(not bool(GS.can_buy("passive_miner")), "Hired Hand stays locked on a fat wallet")


func _plate_price_label(hud: Node, plate: Button) -> Label:
	var plates: Array = _all_next_plates(hud)
	var prices: Variant = hud.get("_plate_prices")
	if prices is Array:
		for i in plates.size():
			if plates[i] == plate and i < prices.size():
				return prices[i] as Label
	return hud.get("_chip_price") as Label


func _plate_is_muted(plate: Button) -> bool:
	if plate == null:
		return false
	if plate.modulate.r + plate.modulate.g + plate.modulate.b < 2.55:
		return true
	var box: StyleBox = plate.get_theme_stylebox("normal")
	if box is StyleBoxFlat:
		var fill: Color = (box as StyleBoxFlat).bg_color
		return fill.r < 0.45
	return false


func _plate_looks_live(plate: Button) -> bool:
	if plate == null or plate.disabled:
		return false
	if plate.modulate.r > 0.85 and plate.modulate.g > 0.7:
		return true
	var box: StyleBox = plate.get_theme_stylebox("normal")
	if box is StyleBoxFlat:
		var fill: Color = (box as StyleBoxFlat).bg_color
		var border: Color = (box as StyleBoxFlat).border_color
		return fill.r > 0.45 or border.g > 0.55
	return false


func _color_is_muted(color: Color) -> bool:
	return color.b >= 0.5 and color.r <= 0.85


func _assert(ok: bool, label: String) -> void:
	if ok:
		_passed += 1
		print("PASS  %s" % label)
	else:
		_failed += 1
		print("FAIL  %s" % label)
