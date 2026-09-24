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
	_assert(str(GS.tool_role_line(TN.TOOL_HANDS)) == "Precision · 1 cell", "hands are the precision tool")
	_assert(str(GS.tool_role_line(TN.TOOL_SHOVEL)) == "Dirt", "shovel is for dirt")
	_assert(str(GS.tool_role_line(TN.TOOL_PICKAXE)) == "Stone", "pickaxe is for stone")
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
	_assert(str(role.text) == "Precision · 1 cell", "hands show Precision · 1 cell")
	_assert(role.position.y + role.size.y <= float(TN.hud_h) + 1.0, "role line stays in the top chrome and off the pit")
	hud.call("refresh", 40.0, 40.0, TN.TOOL_SHOVEL, true)
	_assert(str(role.text) == "Dirt", "shovel role updates to Dirt")
	hud.call("refresh", 40.0, 40.0, TN.TOOL_PICKAXE, true)
	_assert(str(role.text) == "Stone", "pickaxe role updates to Stone")
	hud.call("refresh", 40.0, 40.0, TN.TOOL_BRUSH, true)
	_assert(str(role.text) == "Fossil", "brush role updates to Fossil")
	hud.queue_free()


func _assert(ok: bool, label: String) -> void:
	if ok:
		_passed += 1
		print("PASS  %s" % label)
	else:
		_failed += 1
		print("FAIL  %s" % label)
