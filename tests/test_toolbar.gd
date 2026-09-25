extends SceneTree

## In-round toolbar: only owned tools, hands on 0.
## Run: godot --headless --path <project> -s res://tests/test_toolbar.gd

var _failed: int = 0
var _passed: int = 0
var GS: Node
var TN: Node


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	GS = root.get_node("GameState")
	TN = root.get_node("Tuning")
	_test_start_owned_tools_are_hands_only()
	_test_buying_tools_appends_without_replacing_hands()
	_test_toolbar_hotkeys_are_fixed()
	_test_tool_role_lines_are_short()
	_test_hud_shows_selected_tool_role()
	_test_fine_point_is_gone_from_shop()
	_test_hud_has_no_fine_button()
	print("toolbar %d passed, %d failed" % [_passed, _failed])
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


func _test_start_owned_tools_are_hands_only() -> void:
	_reset()
	var tools: Array = GS.owned_tool_ids()
	_assert(tools.size() == 1, "start toolbar has a single owned tool")
	_assert(int(tools[0]) == int(TN.TOOL_HANDS), "the only starting tool is hands")
	_assert(not bool(GS.owns_tool(TN.TOOL_SHOVEL)), "shovel is not owned at start")
	_assert(not bool(GS.owns_tool(TN.TOOL_PICKAXE)), "pick is not owned at start")
	_assert(not bool(GS.owns_tool(TN.TOOL_BRUSH)), "brush is not owned at start")


func _test_buying_tools_appends_without_replacing_hands() -> void:
	_reset()
	GS.money = 5000
	_assert(bool(GS.buy("shovel_click")), "shovel can be bought")
	var after_shovel: Array = GS.owned_tool_ids()
	_assert(after_shovel.size() == 2, "buying shovel adds a second toolbar slot")
	if after_shovel.size() >= 2:
		_assert(int(after_shovel[0]) == int(TN.TOOL_HANDS), "hands stays first after shovel")
		_assert(int(after_shovel[1]) == int(TN.TOOL_SHOVEL), "shovel appears after hands")
	_assert(bool(GS.buy("pick_click")), "pick can be bought after shovel")
	var after_pick: Array = GS.owned_tool_ids()
	_assert(after_pick.size() == 3, "buying pick adds a third toolbar slot")
	if after_pick.size() >= 3:
		_assert(int(after_pick[2]) == int(TN.TOOL_PICKAXE), "pick appears after shovel")
	_assert(bool(GS.buy("brush_speed")), "brush can be bought after pick")
	var after_brush: Array = GS.owned_tool_ids()
	_assert(after_brush.size() == 4, "buying brush adds a fourth toolbar slot")
	if after_brush.size() >= 4:
		_assert(int(after_brush[3]) == int(TN.TOOL_BRUSH), "brush appears last")


func _test_toolbar_hotkeys_are_fixed() -> void:
	_reset()
	var start_bar: Array = GS.toolbar_entries()
	_assert(start_bar.size() == 1, "start bar lists only hands")
	if start_bar.size() >= 1:
		_assert(int(start_bar[0].get("id", -1)) == int(TN.TOOL_HANDS), "start card is hands")
		_assert(str(start_bar[0].get("hotkey", "")) == "0", "hands hotkey is 0")
	GS.money = 5000
	GS.buy("shovel_click")
	GS.buy("pick_click")
	GS.buy("brush_speed")
	var full: Array = GS.toolbar_entries()
	_assert(full.size() == 4, "owned tools fill 0 through 3 with no holes")
	if full.size() >= 4:
		_assert(str(full[0].get("hotkey", "")) == "0", "hands stays on 0 after other tools")
		_assert(int(full[1].get("id", -1)) == int(TN.TOOL_SHOVEL) and str(full[1].get("hotkey", "")) == "1", "shovel is 1")
		_assert(int(full[2].get("id", -1)) == int(TN.TOOL_PICKAXE) and str(full[2].get("hotkey", "")) == "2", "pick is 2")
		_assert(int(full[3].get("id", -1)) == int(TN.TOOL_BRUSH) and str(full[3].get("hotkey", "")) == "3", "brush is 3")


func _test_tool_role_lines_are_short() -> void:
	_reset()
	_assert(GS.has_method("tool_role_line"), "GameState names each tool's job")
	if not GS.has_method("tool_role_line"):
		return
	_assert(str(GS.tool_role_line(TN.TOOL_HANDS)) == "Harvest · 1 cell", "hands are the harvest tool")
	_assert(str(GS.tool_role_line(TN.TOOL_SHOVEL)) == "Clear dirt", "shovel clears dirt")
	_assert(str(GS.tool_role_line(TN.TOOL_PICKAXE)) == "Clear stone", "pickaxe clears stone")
	_assert(str(GS.tool_role_line(TN.TOOL_BRUSH)) == "Fossil", "brush is for the fossil")


func _test_hud_shows_selected_tool_role() -> void:
	_reset()
	GS.money = 5000
	GS.buy("shovel_click")
	GS.buy("pick_click")
	GS.buy("brush_speed")
	var hud_script: Script = load("res://hud.gd") as Script
	_assert(hud_script != null, "HUD script loads")
	if hud_script == null:
		return
	var hud: CanvasLayer = hud_script.new() as CanvasLayer
	root.add_child(hud)
	hud.call("refresh", 40.0, 40.0, TN.TOOL_HANDS, true)
	var role: Label = hud.get("_tool_role") as Label
	_assert(role != null, "HUD exposes a selected-tool role line")
	if role == null:
		hud.queue_free()
		return
	_assert(role.visible, "role line shows for the equipped tool")
	_assert(str(role.text) == "Harvest · 1 cell", "hands show Harvest · 1 cell")
	_assert_role_on_selected_slot(hud, role, TN.TOOL_HANDS)
	hud.call("refresh", 40.0, 40.0, TN.TOOL_SHOVEL, true)
	_assert(str(role.text) == "Clear dirt", "shovel role updates to Clear dirt")
	_assert_role_on_selected_slot(hud, role, TN.TOOL_SHOVEL)
	hud.call("refresh", 40.0, 40.0, TN.TOOL_PICKAXE, true)
	_assert(str(role.text) == "Clear stone", "pickaxe role updates to Clear stone")
	_assert_role_on_selected_slot(hud, role, TN.TOOL_PICKAXE)
	hud.call("refresh", 40.0, 40.0, TN.TOOL_BRUSH, true)
	_assert(str(role.text) == "Fossil", "brush role updates to Fossil")
	_assert_role_on_selected_slot(hud, role, TN.TOOL_BRUSH)
	hud.queue_free()


func _test_fine_point_is_gone_from_shop() -> void:
	_reset()
	var has_fine := false
	for item in GS.catalog:
		var id := str(item.get("id", ""))
		var name := str(item.get("name", ""))
		var unlock := str(item.get("unlock_name", ""))
		if id == "precision" or name.contains("Fine") or unlock.contains("Fine"):
			has_fine = true
	_assert(not has_fine, "shop catalog has no Fine Point row")
	_assert(GS._item("precision").is_empty(), "precision is not a shop id")
	_assert(str(GS.next_goal_chip_text("precision", 650)).find("Fine") < 0, "NEXT never names Fine Point")
	GS.money = 99999
	GS.levels["shovel_click"] = 1
	GS.levels["pick_click"] = 6
	GS.levels["pick_hold"] = 5
	GS.apply_upgrades()
	var pick_goal: Dictionary = GS.next_goal(TN.TOOL_PICKAXE)
	_assert(str(pick_goal.get("id", "")) != "precision", "pick NEXT is never Fine Point")
	_assert(str(pick_goal.get("title", "")).find("Fine") < 0, "pick NEXT title does not mention Fine")
	GS.levels["precision"] = 5
	GS.apply_upgrades()
	_assert(is_zero_approx(float(TN.precision_damage_bonus)), "leftover Fine ranks do not buff damage")


func _test_hud_has_no_fine_button() -> void:
	_reset()
	GS.money = 5000
	GS.buy("shovel_click")
	GS.buy("pick_click")
	GS.buy("brush_speed")
	var hud: CanvasLayer = _make_hud()
	if hud == null:
		return
	hud.call("refresh", 40.0, 40.0, TN.TOOL_PICKAXE, true)
	_assert(hud.get("_precision") == null, "HUD has no Fine Point control")
	var role: Label = hud.get("_tool_role") as Label
	_assert(role != null, "HUD still shows the selected-tool role")
	if role != null:
		_assert(str(role.text).find("Fine") < 0, "HUD role does not mention Fine")
	GS.levels["precision"] = 5
	GS.apply_upgrades()
	hud.call("refresh", 40.0, 40.0, TN.TOOL_HANDS, true)
	if role != null:
		_assert(str(role.text) == "Harvest · 1 cell", "hands stay Harvest · 1 cell")
		_assert(str(role.text).find("Fine") < 0, "leftover Fine ranks do not change the hands role")
	hud.call("refresh", 40.0, 40.0, TN.TOOL_PICKAXE, true)
	_assert(hud.get("_precision") == null, "leftover Fine ranks do not add a Fine button")
	var main_src: String = FileAccess.get_file_as_string("res://main.gd")
	_assert(not main_src.is_empty(), "main.gd loads")
	_assert(main_src.find("KEY_P") < 0, "P is not a Fine Point hotkey")
	_assert(main_src.find("_toggle_precision") < 0, "main has no Fine Point toggle")
	var dig_src: String = FileAccess.get_file_as_string("res://dig_site.gd")
	_assert(not dig_src.is_empty(), "dig_site.gd loads")
	_assert(dig_src.find("GameState.precision_on") < 0, "shovel and pick no longer pinch from Fine Point")
	hud.queue_free()


func _make_hud() -> CanvasLayer:
	var hud_script: Script = load("res://hud.gd") as Script
	_assert(hud_script != null, "HUD script loads")
	if hud_script == null:
		return null
	var hud: CanvasLayer = hud_script.new() as CanvasLayer
	root.add_child(hud)
	return hud


func _assert_role_on_selected_slot(hud: CanvasLayer, role: Label, tool: int) -> void:
	var slots: Array = hud.get("_tool_slots") as Array
	var slot_tools: Array = hud.get("_slot_tools") as Array
	var slot: Control = null
	for i in slot_tools.size():
		if int(slot_tools[i]) == tool:
			slot = slots[i] as Control
			break
	_assert(slot != null, "selected tool has a toolbar slot")
	if slot == null or role == null:
		return
	_assert(role.get_parent() == slot, "role text sits on the selected tool, not across 0-3")
	var ink: Color = role.get_theme_color("font_color")
	_assert(ink.get_luminance() < 0.45, "role text is dark enough to read on sand")
	var role_bottom: float = role.global_position.y + role.size.y
	if role_bottom <= 0.0:
		role_bottom = role.position.y + role.size.y
	_assert(role_bottom <= float(TN.hud_h) + 8.0, "role text stays in the top chrome and off the pit")


func _assert(ok: bool, label: String) -> void:
	if ok:
		_passed += 1
		print("PASS  %s" % label)
	else:
		_failed += 1
		print("FAIL  %s" % label)
