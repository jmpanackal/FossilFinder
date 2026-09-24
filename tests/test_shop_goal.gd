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
	_test_next_chip_names_the_rank()
	_test_hud_next_chip_prints_equipped_buy()
	_test_hud_goal_bar_is_gone()
	_test_hud_next_chip_hides_when_tool_maxed()
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
	_assert(str(goal.get("id", "")) != "hands_click", "bought rank is no longer the goal")
	_assert(bool(goal.get("affordable", false)), "leftover cash keeps the next buy glowing")
	_assert(str(goal.get("id", "")) == "hands_hold" or str(goal.get("id", "")) == "shovel_click", "next goal is the next early unlock")


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


func _test_next_chip_names_the_rank() -> void:
	_reset()
	_assert(GS.has_method("next_goal_chip_text"), "GameState prints a single NEXT chip line")
	if not GS.has_method("next_goal_chip_text"):
		return
	_assert(str(GS.next_goal_chip_text("brush_speed", 374)) == "Next upgrade · Softer Bristles · $374", "brush NEXT names Softer Bristles")
	_assert(str(GS.next_goal_chip_text("pick_click", 720)) == "Next upgrade · Sharp Strikes · $720", "pick NEXT names Sharp Strikes")
	_assert(str(GS.next_goal_chip_text("hands_click", 40)) == "Next upgrade · Calloused Fingers · $40", "hands NEXT names Calloused Fingers")
	_assert(str(GS.next_goal_chip_text("round_time", 55)) == "Next upgrade · Longer Shift · $55", "site NEXT stays one priced line")
	_assert(str(GS.next_goal_chip_text("shovel_click", 167)) == "Next upgrade · Heavy Swings · $167", "shovel NEXT names Heavy Swings")
	_assert(str(GS.next_goal_chip_text("shovel_radius", 90)) == "Next upgrade · Wider Scoop · $90", "shovel NEXT names Wider Scoop")
	_assert(str(GS.next_goal_chip_text("shovel_soft", 720)) == "Next upgrade · Soft Edge · $720", "shovel NEXT names Soft Edge")


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
	var rank_name: String = str(GS.next_goal_rank_name(shop_id)) if GS.has_method("next_goal_rank_name") else str(GS.shop_display_name(shop_id))
	_assert(not rank_name.is_empty() and caption.contains(rank_name), "NEXT chip names the rank")
	_assert(caption.contains("Next upgrade"), "NEXT chip says Next upgrade")
	_assert(caption.contains("·"), "NEXT chip keeps the rank · price split")
	_assert(caption.contains("$"), "NEXT chip shows the price")
	_assert(not caption.contains("Next shovel upgrade"), "NEXT chip no longer hides behind Next shovel upgrade")
	_assert(chip.clip_contents, "NEXT chip keeps its label inside the pill")
	_assert(chip.clip_text, "NEXT chip does not paint the buy onto the dirt")
	var ink: Color = chip.get_theme_color("font_color")
	_assert(ink.r + ink.g + ink.b > 1.8, "NEXT chip uses light text on the brown pill")
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
	var chip: Button = hud.get("_chip") as Button
	_assert(chip != null and chip.visible, "the NEXT button is the only footer buy control")
	if chip != null:
		_assert(str(chip.text).contains("Next upgrade"), "button says Next upgrade")
		_assert(str(chip.text).contains(str(GS.next_goal_rank_name(str(GS.next_shop_id(TN.TOOL_SHOVEL))))), "button names the upgrade")
		_assert(str(chip.text).contains("$"), "button still shows the price")
		_assert(is_equal_approx(chip.position.x, (TN.view_w - chip.size.x) * 0.5), "button is centered in the footer band")
	hud.queue_free()


func _test_hud_next_chip_hides_when_tool_maxed() -> void:
	_reset()
	for item in GS.catalog:
		var id: String = str(item["id"])
		if GS.tool_for_upgrade(id) == TN.TOOL_SHOVEL:
			GS.levels[id] = int(item["max"])
	GS.apply_upgrades()
	GS.install_find("tooth", "Tooth", 1.0, true)
	var hud: CanvasLayer = _make_hud()
	if hud == null:
		return
	hud.call("refresh", 40.0, 40.0, TN.TOOL_SHOVEL, true)
	var chip: Button = hud.get("_chip") as Button
	_assert(chip != null, "HUD exposes the NEXT chip")
	if chip != null:
		_assert(not chip.visible, "maxed shovel hides the NEXT chip instead of an empty box")
		_assert(str(chip.text).is_empty(), "hidden NEXT chip has no leftover caption")
	hud.queue_free()


func _make_hud() -> CanvasLayer:
	var hud_script: Script = load("res://hud.gd") as Script
	_assert(hud_script != null, "HUD script loads")
	if hud_script == null:
		return null
	var hud: CanvasLayer = hud_script.new() as CanvasLayer
	root.add_child(hud)
	return hud


func _chip_caption(hud: Node, chip: Button) -> String:
	var own: String = str(chip.text).strip_edges()
	if not own.is_empty():
		return own
	var title: Label = hud.get("_chip_title") as Label
	var cost: Label = hud.get("_chip_cost") as Label
	var parts: PackedStringArray = PackedStringArray()
	if title != null and not str(title.text).is_empty() and title.size.y >= 8.0:
		parts.append(str(title.text))
	if cost != null and not str(cost.text).is_empty() and cost.size.y >= 8.0:
		parts.append(str(cost.text))
	return " ".join(parts)


func _test_hired_hand_is_not_an_early_goal() -> void:
	_reset()
	if not GS.has_method("next_goal"):
		return
	GS.money = 99999
	var goal: Dictionary = GS.next_goal()
	_assert(str(goal.get("id", "")) != "passive_miner", "Hired Hand is never the early next buy")
	_assert(not bool(GS.can_buy("passive_miner")), "Hired Hand stays locked on a fat wallet")


func _assert(ok: bool, label: String) -> void:
	if ok:
		_passed += 1
		print("PASS  %s" % label)
	else:
		_failed += 1
		print("FAIL  %s" % label)
