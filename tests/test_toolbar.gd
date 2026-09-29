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
	_test_hud_shows_tool_role_always()
	_test_tool_card_icon_stack_layout()
	_test_tool_cards_stay_in_the_gutter()
	_test_rail_section_labels()
	_test_selected_tool_chrome_is_unmistakable()
	_test_tool_hover_matches_selected_gold_outline()
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
	if TN.has_method("apply_site_layout"):
		TN.view_w = 1280.0
		TN.view_h = 720.0
		TN.site_size_rank = 0
		TN.apply_site_layout()


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
		_assert(str(start_bar[0].get("hotkey", "")) == "1", "hands hotkey is 1")
	GS.money = 5000
	GS.buy("shovel_click")
	GS.buy("pick_click")
	GS.buy("brush_speed")
	var full: Array = GS.toolbar_entries()
	_assert(full.size() == 4, "owned tools fill 1 through 4 with no holes")
	if full.size() >= 4:
		_assert(str(full[0].get("hotkey", "")) == "1", "hands stays on 1 after other tools")
		_assert(int(full[1].get("id", -1)) == int(TN.TOOL_SHOVEL) and str(full[1].get("hotkey", "")) == "2", "shovel is 2")
		_assert(int(full[2].get("id", -1)) == int(TN.TOOL_PICKAXE) and str(full[2].get("hotkey", "")) == "3", "pick is 3")
		_assert(int(full[3].get("id", -1)) == int(TN.TOOL_BRUSH) and str(full[3].get("hotkey", "")) == "4", "brush is 4")


func _test_tool_role_lines_are_short() -> void:
	_reset()
	_assert(GS.has_method("tool_role_line"), "GameState names each tool's job")
	if not GS.has_method("tool_role_line"):
		return
	_assert(str(GS.tool_role_line(TN.TOOL_HANDS)) == "Pick up small finds", "hands are the harvest tool")
	_assert(str(GS.tool_role_line(TN.TOOL_SHOVEL)) == "Clear dirt fast", "shovel clears dirt")
	_assert(str(GS.tool_role_line(TN.TOOL_PICKAXE)) == "Break clay and stone", "pickaxe clears stone")
	_assert(str(GS.tool_role_line(TN.TOOL_BRUSH)) == "Wipe dirt off bones", "brush is for the fossil")


func _test_hud_shows_tool_role_always() -> void:
	_reset()
	GS.money = 5000
	GS.buy("shovel_click")
	GS.buy("pick_click")
	GS.buy("brush_speed")
	var hud: CanvasLayer = _make_hud()
	if hud == null:
		return
	hud.call("refresh", 40.0, 40.0, TN.TOOL_HANDS, true)
	var expected := {
		TN.TOOL_HANDS: "Pick up small finds",
		TN.TOOL_SHOVEL: "Clear dirt fast",
		TN.TOOL_PICKAXE: "Break clay and stone",
		TN.TOOL_BRUSH: "Wipe dirt off bones",
	}
	var heights_hands: PackedFloat32Array = _visible_slot_heights(hud)
	_assert(heights_hands.size() == 4, "all four owned tools have a row")
	_assert(_heights_match(heights_hands, heights_hands[0] if heights_hands.size() > 0 else 0.0), "owned rows share one height")
	for tool in expected.keys():
		var role: Label = _role_for(hud, int(tool))
		_assert(role != null, "each card has its own role line")
		if role == null:
			continue
		_assert(str(role.text) == str(expected[tool]), "%s role is %s" % [GS.tool_display_name(int(tool)), expected[tool]])
		_assert(str(role.text).find("  ") < 0, "role copy is not smashed together")
		if str(expected[tool]).find(" ") >= 0:
			_assert(str(role.text).find(" ") >= 0, "role keeps its spaces")
		## Slim rail: the role moved off the card into a hover tip.
		_assert(not role.visible, "role is off the slim card (shown on hover)")
	hud.call("refresh", 40.0, 40.0, TN.TOOL_PICKAXE, true)
	var heights_pick: PackedFloat32Array = _visible_slot_heights(hud)
	_assert(_arrays_match(heights_hands, heights_pick), "selecting pickaxe does not change row heights")
	var pick_role: Label = _role_for(hud, TN.TOOL_PICKAXE)
	_assert(pick_role != null and not pick_role.visible, "selecting pickaxe keeps the card slim")
	if pick_role != null:
		_assert(str(pick_role.text) == "Break clay and stone", "pickaxe role stays Break clay and stone")
	var hands_role: Label = _role_for(hud, TN.TOOL_HANDS)
	var shovel_role: Label = _role_for(hud, TN.TOOL_SHOVEL)
	_assert(not _tip_visible(hud), "no tool tip without hover")
	_hover_tool(hud, TN.TOOL_PICKAXE, true)
	var heights_hover: PackedFloat32Array = _visible_slot_heights(hud)
	_assert(_arrays_match(heights_hands, heights_hover), "hovering a row does not slide neighbors")
	_assert(_tip_shows(hud, "Break clay and stone"), "hovering pickaxe shows what it does")
	_hover_tool(hud, TN.TOOL_PICKAXE, false)
	_assert(not _tip_visible(hud), "leaving the rail hides the tip")
	if hands_role != null:
		_assert(str(hands_role.text) == "Pick up small finds", "hands stay Pick up small finds")
		_assert(int(hands_role.horizontal_alignment) == HORIZONTAL_ALIGNMENT_CENTER, "hands role is centered")
	hud.call("refresh", 40.0, 40.0, TN.TOOL_BRUSH, true)
	_assert(_arrays_match(heights_hands, _visible_slot_heights(hud)), "selecting brush does not change row heights")
	_assert(not _any_role_visible(hud), "keyboard select keeps the slim cards")
	hud.queue_free()


func _test_tool_card_icon_stack_layout() -> void:
	_reset()
	GS.money = 5000
	GS.buy("shovel_click")
	GS.buy("pick_click")
	GS.buy("brush_speed")
	var hud: CanvasLayer = _make_hud()
	if hud == null:
		return
	hud.call("refresh", 40.0, 40.0, TN.TOOL_HANDS, true)
	var shovel: Button = _button_for(hud, TN.TOOL_SHOVEL)
	_assert(shovel != null, "shovel has a card")
	if shovel == null:
		hud.queue_free()
		return
	_assert_rail_card_layout(shovel, "shovel")
	var rest_name := _name_row_rect_in_card(shovel)
	var rest_h: float = _card_size(shovel).y
	_assert(rest_name.size.x > 1.0 and rest_name.size.y > 1.0, "idle shovel has a laid-out name")
	_hover_tool(hud, TN.TOOL_SHOVEL, true)
	var role: Label = _role_for(hud, TN.TOOL_SHOVEL)
	_assert(_tip_shows(hud, "Clear dirt fast"), "hovering shovel shows its tip")
	if role != null:
		_assert(str(role.text) == "Clear dirt fast", "shovel keeps Clear dirt fast")
		_assert(str(role.text).find(" ") >= 0, "Clear dirt keeps its space")
		_assert(not role.clip_text, "role does not clip the space out of Clear dirt")
		_assert(int(role.horizontal_alignment) == HORIZONTAL_ALIGNMENT_CENTER, "role copy is centered")
		var font: Font = role.get_theme_font("font")
		var sized: int = role.get_theme_font_size("font_size")
		var need: float = font.get_string_size("Clear dirt", HORIZONTAL_ALIGNMENT_LEFT, -1, sized).x
		_assert(role.custom_minimum_size.x + 0.5 >= need, "role min width keeps Clear dirt's space")
	var hover_name := _name_row_rect_in_card(shovel)
	_assert(rest_name.position.is_equal_approx(hover_name.position), "hover does not move the shovel name")
	_assert(rest_name.size.is_equal_approx(hover_name.size), "hover does not resize the shovel name")
	_assert(is_equal_approx(_card_size(shovel).y, rest_h), "hover does not change shovel card height")
	_hover_tool(hud, TN.TOOL_SHOVEL, false)
	_hover_tool(hud, TN.TOOL_HANDS, true)
	var hands: Button = _button_for(hud, TN.TOOL_HANDS)
	var hands_role: Label = _role_for(hud, TN.TOOL_HANDS)
	if hands != null:
		_assert_rail_card_layout(hands, "hands")
	if hands != null and hands_role != null:
		_assert(_tip_shows(hud, "Pick up small finds"), "hovering Hands shows its tip")
		_assert(int(hands_role.horizontal_alignment) == HORIZONTAL_ALIGNMENT_CENTER, "Harvest role is centered")
	_hover_tool(hud, TN.TOOL_HANDS, false)
	hud.queue_free()


func _test_tool_cards_stay_in_the_gutter() -> void:
	_reset()
	if TN.has_method("apply_site_layout"):
		TN.view_w = 1280.0
		TN.view_h = 720.0
		TN.site_size_rank = 0
		TN.apply_site_layout()
	GS.money = 5000
	GS.buy("shovel_click")
	GS.buy("pick_click")
	GS.buy("brush_speed")
	var hud: CanvasLayer = _make_hud()
	if hud == null:
		return
	hud.call("refresh", 40.0, 40.0, TN.TOOL_HANDS, true)
	var pit := Rect2(TN.grid_origin, Vector2(float(TN.grid_w) * TN.cell_w, float(TN.grid_h) * TN.cell_h))
	if TN.has_method("pit_grid_rect"):
		pit = TN.pit_grid_rect()
	var heights_rest: PackedFloat32Array = _visible_slot_heights(hud)
	var matched: int = 0
	for tool in [TN.TOOL_HANDS, TN.TOOL_SHOVEL, TN.TOOL_PICKAXE, TN.TOOL_BRUSH]:
		var button: Button = _button_for(hud, tool)
		_assert(button != null and button.visible, "owned tool has a left card")
		if button == null:
			continue
		matched += 1
		var card := _card_size(button)
		var card_rect := Rect2(button.global_position if button.global_position != Vector2.ZERO else button.position, card)
		_assert(not pit.intersects(card_rect), "tool card stays off the pit")
		_assert(card.y <= 110.0 + 0.5, "stacked tool cards do not grow past the pit")
		var gutter_w: float = maxf(pit.position.x - 8.0 - 1.0, 1.0)
		_assert(card.x <= gutter_w + 0.01, "tool card width stays in the left gutter")
		_assert_rail_card_layout(button, GS.tool_display_name(tool))
	_assert(matched == 4, "all four owned tools stay in the gutter")
	_hover_tool(hud, TN.TOOL_PICKAXE, true)
	_assert(_arrays_match(heights_rest, _visible_slot_heights(hud)), "hovering a taller card still does not slide neighbors")
	_hover_tool(hud, TN.TOOL_PICKAXE, false)
	hud.queue_free()


func _test_rail_section_labels() -> void:
	_reset()
	GS.money = 5000
	GS.buy("shovel_click")
	var hud: CanvasLayer = _make_hud()
	if hud == null:
		return
	hud.call("refresh", 40.0, 40.0, TN.TOOL_HANDS, true)
	var tools: Label = _rail_section_label(hud, "Tools")
	_assert(tools != null and str(tools.text) == "Tools", "left rail is labeled Tools")
	_assert(_rail_section_label(hud, "Working find") == null, "Working find left the live HUD")
	if tools == null:
		hud.queue_free()
		return
	var pit := Rect2(TN.grid_origin, Vector2(float(TN.grid_w) * TN.cell_w, float(TN.grid_h) * TN.cell_h))
	if TN.has_method("pit_grid_rect"):
		pit = TN.pit_grid_rect()
	_assert(not pit.intersects(Rect2(tools.global_position if tools.global_position != Vector2.ZERO else tools.position, tools.size)), "Tools label stays off the pit")
	var hands: Button = _button_for(hud, TN.TOOL_HANDS)
	if hands != null:
		_assert(tools.global_position.y + tools.size.y <= hands.global_position.y + 0.5 or tools.position.y + tools.size.y <= hands.position.y + 0.5, "Tools sits above the first tool card")
	hud.queue_free()


func _test_selected_tool_chrome_is_unmistakable() -> void:
	_reset()
	GS.money = 5000
	GS.buy("shovel_click")
	GS.buy("pick_click")
	var hud: CanvasLayer = _make_hud()
	if hud == null:
		return
	hud.call("refresh", 40.0, 40.0, TN.TOOL_SHOVEL, true)
	var buttons: Array = hud.get("_tool_buttons") as Array
	var slot_tools: Array = hud.get("_slot_tools") as Array
	var selected: Button = null
	var neighbor: Button = null
	for i in slot_tools.size():
		if int(slot_tools[i]) == int(TN.TOOL_SHOVEL):
			selected = buttons[i] as Button
		elif int(slot_tools[i]) == int(TN.TOOL_HANDS):
			neighbor = buttons[i] as Button
	_assert(selected != null and neighbor != null, "owned tools both have buttons")
	if selected == null or neighbor == null:
		hud.queue_free()
		return
	var sel_box: StyleBox = selected.get_theme_stylebox("normal")
	var idle_box: StyleBox = neighbor.get_theme_stylebox("normal")
	_assert(sel_box != null and idle_box != null, "tool rows still use brass boxes")
	if sel_box != null and idle_box != null and "border_width" in sel_box and "border_width" in idle_box:
		_assert(int(sel_box.border_width) >= 4, "the live tool has thicker selected chrome")
		_assert(int(sel_box.border_width) > int(idle_box.border_width), "neighbors stay thinner than the live tool")
	_assert(is_equal_approx(neighbor.modulate.a, 1.0) and neighbor.modulate.r >= 0.95 and neighbor.modulate.g >= 0.95, "idle owned tools stay at full brightness")
	_assert(is_equal_approx(selected.modulate.a, 1.0) and selected.modulate.r >= 0.95 and selected.modulate.g >= 0.95, "the live tool stays at full brightness")
	if idle_box != null and "bg_color" in idle_box:
		_assert(_looks_like_available_brass(idle_box.bg_color), "idle owned cards use idle brass / available NEXT fill")
	var sel_size: Vector2 = _card_size(selected)
	var idle_size: Vector2 = _card_size(neighbor)
	_assert(is_equal_approx(sel_size.y, idle_size.y), "selected chrome does not grow the card")
	var role: Label = _role_for(hud, TN.TOOL_SHOVEL)
	_assert(role != null and str(role.text) == "Clear dirt fast", "shovel still owns Clear dirt fast")
	_assert(role != null and not role.visible, "selected chrome keeps the card slim")
	var hud_src: String = FileAccess.get_file_as_string("res://hud.gd")
	_assert(hud_src.find("damage") < 0 or hud_src.find("integrity") < 0, "the rail is still not a HUD stat sheet")
	hud.queue_free()


func _test_tool_hover_matches_selected_gold_outline() -> void:
	_reset()
	GS.money = 5000
	GS.buy("shovel_click")
	var hud: CanvasLayer = _make_hud()
	if hud == null:
		return
	hud.call("refresh", 40.0, 40.0, TN.TOOL_SHOVEL, true)
	var selected: Button = _button_for(hud, TN.TOOL_SHOVEL)
	var idle: Button = _button_for(hud, TN.TOOL_HANDS)
	_assert(selected != null and idle != null, "selected and idle tools have cards")
	if selected == null or idle == null:
		hud.queue_free()
		return
	var sel_normal: StyleBox = selected.get_theme_stylebox("normal")
	var sel_hover: StyleBox = selected.get_theme_stylebox("hover")
	var idle_hover: StyleBox = idle.get_theme_stylebox("hover")
	_assert(sel_normal != null and sel_hover != null and idle_hover != null, "tool cards expose hover styleboxes")
	if sel_normal == null or sel_hover == null or idle_hover == null:
		hud.queue_free()
		return
	_assert("border_color" in idle_hover and _color_is_gold(idle_hover.border_color), "idle tool hover uses the gold outline")
	_assert("border_width" in idle_hover and int(idle_hover.border_width) >= 4, "idle tool hover matches selected outline width")
	_assert("border_width" in sel_hover and "border_width" in sel_normal and int(sel_hover.border_width) == int(sel_normal.border_width), "selected+hover does not stack a second outline")
	_assert("shadow_size" in idle_hover and int(idle_hover.shadow_size) > 0 and int(idle_hover.shadow_size) <= 4, "tool hover shadow is lighter than the old 8–12px drop")
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
	var role: Label = _role_for(hud, TN.TOOL_PICKAXE)
	_assert(role != null, "pickaxe still has a role line inside its card")
	if role != null:
		_assert(str(role.text).find("Fine") < 0, "HUD role does not mention Fine")
	GS.levels["precision"] = 5
	GS.apply_upgrades()
	hud.call("refresh", 40.0, 40.0, TN.TOOL_HANDS, true)
	var hands_role: Label = _role_for(hud, TN.TOOL_HANDS)
	if hands_role != null:
		_assert(str(hands_role.text) == "Pick up small finds", "hands stay Pick up small finds")
		_assert(str(hands_role.text).find("Fine") < 0, "leftover Fine ranks do not change the hands role")
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


func _test_next_plate_glyphs_match_left_rail() -> void:
	_reset()
	GS.money = 5000
	GS.buy("shovel_click")
	GS.buy("pick_click")
	GS.buy("brush_speed")
	var hud: CanvasLayer = _make_hud()
	if hud == null:
		return
	hud.call("refresh", 40.0, 40.0, TN.TOOL_HANDS, true)
	var plates: Variant = hud.get("_next_plates")
	var plate_tools: Variant = hud.get("_plate_tools")
	_assert(plates is Array and plate_tools is Array, "HUD still exposes NEXT plates")
	if not (plates is Array and plate_tools is Array):
		hud.queue_free()
		return
	for i in plates.size():
		var plate: Button = plates[i] as Button
		var tool: int = int(plate_tools[i])
		_assert(plate != null and plate.visible, "%s NEXT plate stays on the rail" % GS.tool_display_name(tool))
		var plate_icon: Node = _find_tool_icon(plate)
		var rail_icon: Node = _find_tool_icon(_button_for(hud, tool))
		_assert(plate_icon != null, "%s NEXT plate has the toolbar glyph" % GS.tool_display_name(tool))
		_assert(rail_icon != null, "%s left rail still has its glyph" % GS.tool_display_name(tool))
		if plate_icon != null and rail_icon != null:
			_assert(int(plate_icon.get("tool_id")) == int(rail_icon.get("tool_id")), "%s plate and rail share a tool_id" % GS.tool_display_name(tool))
			var plate_mark: Control = plate_icon as Control
			var rail_mark: Control = rail_icon as Control
			_assert(is_equal_approx(plate_mark.size.x, 22.0) and is_equal_approx(plate_mark.size.y, 22.0), "%s NEXT glyph is the shared 22px tool box" % GS.tool_display_name(tool))
			_assert(rail_mark.size.x >= 36.0 and rail_mark.size.y >= 36.0, "%s rail glyph is the large stacked icon" % GS.tool_display_name(tool))
			_assert(rail_mark.size.x > plate_mark.size.x + 0.5, "%s rail icon is larger than the NEXT glyph" % GS.tool_display_name(tool))
	hud.queue_free()


func _rail_section_label(hud: Node, text: String) -> Label:
	for raw in [hud.get("_tools_label"), hud.get("_working_label")]:
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


func _role_for(hud: CanvasLayer, tool: int) -> Label:
	var raw_roles = hud.get("_tool_roles")
	if raw_roles == null or not (raw_roles is Array):
		return null
	var roles: Array = raw_roles
	var slot_tools: Array = hud.get("_slot_tools") as Array
	for i in slot_tools.size():
		if int(slot_tools[i]) == tool and i < roles.size():
			return roles[i] as Label
	return null


func _plate_for_tool(hud: CanvasLayer, tool: int) -> Button:
	var plates: Variant = hud.get("_next_plates")
	var plate_tools: Variant = hud.get("_plate_tools")
	if plates is Array and plate_tools is Array:
		for i in plates.size():
			if i < plate_tools.size() and int(plate_tools[i]) == tool:
				return plates[i] as Button
	return null


func _card_size(button: Button) -> Vector2:
	return Vector2(maxf(button.size.x, button.custom_minimum_size.x), maxf(button.size.y, button.custom_minimum_size.y))


func _name_row_rect_in_card(button: Button) -> Rect2:
	if button == null:
		return Rect2()
	var name: Label = button.find_child("ToolName", true, false) as Label
	if name != null:
		return _control_rect_in_card(name, button)
	var icon: Control = _find_tool_icon(button) as Control
	if icon == null:
		return Rect2()
	return _control_rect_in_card(icon.get_parent() as Control, button)


func _assert_rail_card_layout(button: Button, where: String) -> void:
	var icon: Control = _find_tool_icon(button) as Control
	var name: Label = button.find_child("ToolName", true, false) as Label
	var role: Label = button.find_child("ToolRole", true, false) as Label
	var key: Label = button.find_child("ToolKey", true, false) as Label
	_assert(icon != null and name != null and role != null and key != null, "%s card has icon, name, role, and hotkey" % where)
	if icon == null or name == null or role == null or key == null:
		return
	var card := _card_size(button)
	var icon_rect := _control_rect_in_card(icon, button)
	var name_rect := _control_rect_in_card(name, button)
	var role_rect := _control_rect_in_card(role, button)
	var key_rect := _control_rect_in_card(key, button)
	var stack: VBoxContainer = button.get_node_or_null("ToolStack") as VBoxContainer
	var gap: float = 8.0
	if stack != null:
		gap = float(stack.get_theme_constant("separation"))
	_assert(icon_rect.size.x >= 28.0 and icon_rect.size.y >= 28.0, "%s icon is the stacked glyph" % where)
	_assert(icon_rect.size.y > float(name.get_theme_font_size("font_size")), "%s icon is larger than the name type" % where)
	_assert(icon_rect.position.y + icon_rect.size.y * 0.5 < card.y * 0.5 - 1.0, "%s icon sits above the card center" % where)
	_assert(absf(icon_rect.position.x + icon_rect.size.x * 0.5 - card.x * 0.5) <= 3.0, "%s icon is horizontally centered" % where)
	_assert(int(name.horizontal_alignment) == HORIZONTAL_ALIGNMENT_CENTER, "%s name is centered" % where)
	_assert(absf(name_rect.position.x + name_rect.size.x * 0.5 - card.x * 0.5) <= 3.0, "%s name sits under the icon" % where)
	_assert(absf(name_rect.position.y - icon_rect.end.y - gap) <= 2.0, "%s keeps a gap under the icon" % where)
	_assert(not role.visible, "%s role lives in the hover tip" % where)
	_assert(key_rect.position.y <= 6.0, "%s hotkey sits at the top of the card" % where)
	_assert(key_rect.end.x >= card.x - 8.0, "%s hotkey sits in the top-right" % where)
	_assert(key_rect.end.y <= name_rect.position.y + 0.5, "%s hotkey is not in the name row" % where)


func _flush_tool_card(button: Button) -> void:
	if button == null:
		return
	for raw in button.get_children():
		if raw is Container:
			(raw as Container).notification(Container.NOTIFICATION_SORT_CHILDREN)


func _control_rect_in_card(node: Control, button: Button) -> Rect2:
	if node == null or button == null:
		return Rect2()
	var pos := Vector2.ZERO
	var walk: Node = node
	while walk != null and walk != button:
		if walk is Control:
			pos += (walk as Control).position
		walk = walk.get_parent()
	return Rect2(pos, node.size)


func _button_for(hud: CanvasLayer, tool: int) -> Button:
	var buttons: Array = hud.get("_tool_buttons") as Array
	var slot_tools: Array = hud.get("_slot_tools") as Array
	for i in slot_tools.size():
		if int(slot_tools[i]) == tool and i < buttons.size():
			return buttons[i] as Button
	return null


func _hover_tool(hud: CanvasLayer, tool: int, inside: bool) -> void:
	var button: Button = _button_for(hud, tool)
	_assert(button != null, "hovered tool has a card")
	if button == null:
		return
	if inside:
		button.mouse_entered.emit()
	else:
		button.mouse_exited.emit()
	_flush_tool_card(button)


func _visible_slot_heights(hud: CanvasLayer) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var slots: Array = hud.get("_tool_slots") as Array
	for raw in slots:
		var slot: Control = raw as Control
		if slot == null or not slot.visible:
			continue
		out.append(slot.get_combined_minimum_size().y)
	return out


func _heights_match(heights: PackedFloat32Array, expected: float) -> bool:
	for h in heights:
		if not is_equal_approx(h, expected):
			return false
	return heights.size() > 0


func _arrays_match(a: PackedFloat32Array, b: PackedFloat32Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if not is_equal_approx(a[i], b[i]):
			return false
	return true


func _tip_visible(hud: CanvasLayer) -> bool:
	var tip: Label = hud.get("_tool_tip") as Label
	return tip != null and tip.visible


func _tip_shows(hud: CanvasLayer, text: String) -> bool:
	var tip: Label = hud.get("_tool_tip") as Label
	return tip != null and tip.visible and str(tip.text).contains(text)


func _any_role_visible(hud: CanvasLayer) -> bool:
	var raw_roles = hud.get("_tool_roles")
	if raw_roles == null or not (raw_roles is Array):
		return false
	var roles: Array = raw_roles
	for raw in roles:
		var role: Label = raw as Label
		if role != null and role.visible:
			return true
	return false


func _assert_role_inside_card(hud: CanvasLayer, role: Label, tool: int) -> void:
	var slots: Array = hud.get("_tool_slots") as Array
	var slot_tools: Array = hud.get("_slot_tools") as Array
	var slot: Control = null
	for i in slot_tools.size():
		if int(slot_tools[i]) == tool:
			slot = slots[i] as Control
			break
	_assert(slot != null, "tool has a toolbar slot")
	if slot == null or role == null:
		return
	var button: Button = _button_for(hud, tool)
	_assert(button != null and button.is_ancestor_of(role), "role text lives inside the card")
	_assert(role.get_parent() != slot, "role does not protrude under the stack")
	var ink: Color = role.get_theme_color("font_color")
	_assert(ink.get_luminance() > 0.45, "role text is light enough to read on the card")
	var rail: Control = hud.get("_tool_rail") as Control
	_assert(rail is VBoxContainer, "tools are a vertical list")
	var slot_right: float = slot.global_position.x + maxf(slot.size.x, slot.get_combined_minimum_size().x)
	if slot_right <= 8.0 and rail != null:
		slot_right = rail.position.x + maxf(rail.size.x, 112.0)
	_assert(slot_right <= float(TN.grid_origin.x) + 10.0, "tool rows stay in the left rail and off the pit")


func _looks_like_available_brass(fill: Color) -> bool:
	return fill.is_equal_approx(Color("3F3126")) or fill.is_equal_approx(Color("8A4E24"))


func _color_is_gold(color: Color) -> bool:
	return color.r > 0.75 and color.g > 0.55 and color.b < 0.55


func _assert(ok: bool, label: String) -> void:
	if ok:
		_passed += 1
		print("PASS  %s" % label)
	else:
		_failed += 1
		print("FAIL  %s" % label)
