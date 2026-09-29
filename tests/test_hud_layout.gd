extends SceneTree

## Dig-screen HUD rails: money left, clock center, tools left, finds under the pit.
## Run: godot --headless --path <project> -s res://tests/test_hud_layout.gd

var _failed: int = 0
var _passed: int = 0
var GS: Node
var TN: Node


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	GS = root.get_node("GameState")
	TN = root.get_node("Tuning")
	_test_money_is_top_left_clock_is_top_center()
	_test_income_hides_until_museum_pays()
	_test_loot_flies_retarget_the_pouch()
	_test_tools_are_a_left_owned_list()
	_test_tool_cards_stay_in_the_gutter()
	_test_rail_section_labels()
	_test_selected_tool_uses_outline_not_dim()
	_test_dig_buttons_share_gold_hover_and_light_shadow()
	_test_unowned_tools_stay_hidden()
	_test_live_hud_has_no_next_or_meta_doors()
	_test_working_find_left_the_live_hud()
	_test_header_menu_and_end_shift()
	_test_header_actions_carry_glyphs()
	_test_wallet_width_does_not_follow_digits()
	_test_find_chips_sit_under_the_pit()
	_test_deep_cells_stay_off_finds()
	_test_finds_section_label()
	_test_find_chips_scale_in_tray()
	_test_hud_stays_off_the_pit()
	_test_pit_stays_1024_by_400()
	_test_tools_section_uses_the_wide_left_gutter()
	_test_shop_and_museum_open_from_shift_over()
	_test_shop_overlay_has_dig_museum_menu()
	_test_museum_overlay_has_dig_upgrades_menu()
	_test_overlay_dig_starts_a_new_shift()
	_test_overlay_museum_and_upgrades_swap_screens()
	_test_overlay_header_clears_wallet_and_museum_stats()
	_test_overlays_hide_dig_header_menu()
	_test_wallet_stays_top_left_on_overlays()
	_test_menu_and_back_stay_top_right()
	print("hud_layout %d passed, %d failed" % [_passed, _failed])
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
	TN.view_w = 1280.0
	TN.view_h = 720.0
	TN.site_size_rank = 0
	TN.apply_site_layout()


func _test_money_is_top_left_clock_is_top_center() -> void:
	_reset()
	var hud: CanvasLayer = _make_hud()
	if hud == null:
		return
	hud.call("refresh", 47.0, 60.0, TN.TOOL_HANDS, true)
	var wallet: Control = hud.get("_wallet") as Control
	var clock: Control = hud.get("_clock") as Control
	var money: Label = hud.get("_money") as Label
	var clock_time: Label = hud.get("_clock_time") as Label
	var clock_caption: Label = hud.get("_clock_caption") as Label
	_assert(wallet != null and clock != null and money != null, "HUD exposes the wallet and clock")
	if wallet == null or clock == null or money == null:
		hud.queue_free()
		return
	_assert(wallet.position.x <= 16.0 and wallet.position.y <= 16.0, "wallet sits top-left")
	_assert(wallet.position.y + wallet.size.y <= _pit_rect().position.y - 2.0, "wallet stays off the pit")
	_assert(clock.size.x >= 64.0 and clock.size.y >= 64.0, "clock face fills the header band")
	_assert(absf((clock.position.x + clock.size.x * 0.5) - TN.view_w * 0.5) > 40.0 or clock_time != null, "clock keeps remaining-time digits")
	var cluster_left: float = clock.position.x
	var cluster_right: float = clock.position.x + clock.size.x
	if clock_time != null:
		cluster_left = minf(cluster_left, clock_time.position.x)
		cluster_right = maxf(cluster_right, clock_time.position.x + clock_time.size.x)
	if clock_caption != null:
		cluster_right = maxf(cluster_right, clock_caption.position.x + clock_caption.size.x)
	_assert(absf((cluster_left + cluster_right) * 0.5 - TN.view_w * 0.5) <= 40.0, "clock sits top-center")
	if clock_time != null:
		_assert(str(clock_time.text).find("0:47") >= 0 or str(clock_time.text).find(":47") >= 0, "clock prints remaining m:ss")
		_assert(int(clock_time.get_theme_font_size("font_size")) >= 28, "timer digits fill the header type size")
		_assert(_color_is_dirt_ink(clock_time.get_theme_color("font_color")), "timer digits are dark enough to read")
	if clock_caption != null:
		_assert(_color_is_dirt_ink(clock_caption.get_theme_color("font_color")), "Shift remaining is dark enough to read")
	_assert(clock.position.y + clock.size.y <= float(TN.hud_h) + 0.5, "clock stays in the header")
	_assert(clock.position.y + clock.size.y <= _pit_rect().position.y - 2.0, "clock stays off the pit")
	_assert(clock.position.x < TN.view_w * 0.7, "clock left the top-right corner")
	_assert(wallet.position.x + wallet.size.x < clock.position.x - 8.0, "money and clock do not share a corner")
	_assert(money.get_theme_font_size("font_size") >= 26, "wallet is the largest HUD number")
	_assert(str(money.text).begins_with("$"), "wallet is the one bank")
	_assert(clock_caption != null and str(clock_caption.text) == "Shift remaining", "clock says Shift remaining")
	hud.queue_free()


func _test_income_hides_until_museum_pays() -> void:
	_reset()
	var hud: CanvasLayer = _make_hud()
	if hud == null:
		return
	hud.call("refresh", 40.0, 40.0, TN.TOOL_HANDS, true)
	var income: Label = hud.get("_income") as Label
	var wallet: Control = hud.get("_wallet") as Control
	_assert(income != null, "HUD exposes the museum rate caption")
	if income == null:
		hud.queue_free()
		return
	_assert(not income.visible, "museum $/sec stays hidden until income exists")
	GS.install_find("tooth", "Tooth", 1.0, true)
	hud.call("refresh", 40.0, 40.0, TN.TOOL_HANDS, true)
	_assert(income.visible, "museum $/sec appears under the wallet once the hall pays")
	_assert(str(income.text).contains("/s"), "rate caption is a quiet $/sec")
	var rate_mark: Node = hud.get("_income_mark")
	_assert(rate_mark != null, "museum rate keeps the hall glyph")
	if rate_mark != null and "glyph" in rate_mark:
		_assert(str(rate_mark.glyph) == "exhibit", "rate caption uses the museum mark")
	if wallet != null:
		_assert(income.global_position.y >= wallet.global_position.y, "rate sits with the wallet cluster")
		_assert(income.global_position.x < TN.view_w * 0.35, "rate stays on the left with the bank")
	hud.queue_free()


func _test_loot_flies_retarget_the_pouch() -> void:
	_reset()
	var hud: CanvasLayer = _make_hud()
	if hud == null:
		return
	hud.call("refresh", 40.0, 40.0, TN.TOOL_HANDS, true)
	_assert(hud.has_method("money_catch_pos"), "HUD still exposes the pouch catch")
	var pos: Vector2 = hud.call("money_catch_pos")
	_assert(pos.x < 160.0 and pos.y < 90.0, "loot flies retarget the top-left pouch")
	hud.queue_free()


func _test_tools_are_a_left_owned_list() -> void:
	_reset()
	GS.money = 5000
	GS.buy("shovel_click")
	GS.buy("pick_click")
	GS.buy("brush_speed")
	var hud: CanvasLayer = _make_hud()
	if hud == null:
		return
	hud.call("refresh", 40.0, 40.0, TN.TOOL_HANDS, true)
	var rail: Control = hud.get("_tool_rail") as Control
	_assert(rail is VBoxContainer, "owned tools are a vertical left list")
	if rail == null:
		hud.queue_free()
		return
	_assert(rail.position.x <= 20.0, "tool list sits in the left gutter")
	_assert(rail.position.y >= float(TN.hud_h), "tool list starts with the pit, not the header")
	_assert(rail.position.x + rail.size.x <= float(TN.grid_origin.x) + 8.0, "tool list stays off the pit")
	var slots: Array = hud.get("_tool_slots") as Array
	var visible_n: int = 0
	var keys: PackedStringArray = PackedStringArray()
	for raw in slots:
		var slot: Control = raw as Control
		if slot == null or not slot.visible:
			continue
		visible_n += 1
		_assert(slot.get_combined_minimum_size().y >= 52.0 or _slot_button_h(slot) >= 52.0, "tool rows are fat hit targets")
		var blob: String = _slot_text(slot)
		_assert(not blob.contains("$"), "tool rows have no prices")
		_assert(not blob.contains("NEXT") and not blob.contains("Next"), "tool rows have no NEXT")
		_assert(not blob.contains("LOCKED"), "tool rows have no LOCKED fillers")
		if blob.contains("1"):
			keys.append("1")
		if blob.contains("2"):
			keys.append("2")
		if blob.contains("3"):
			keys.append("3")
		if blob.contains("4"):
			keys.append("4")
	_assert(visible_n == 4, "all owned tools appear once they are bought")
	_assert(keys.has("1") and keys.has("2") and keys.has("3") and keys.has("4"), "hotkeys are 1 through 4")
	var roles: Array = hud.get("_tool_roles") as Array
	_assert(roles.size() == 4, "each tool card has its own role line")
	var row_h: float = -1.0
	for raw_slot in slots:
		var slot: Control = raw_slot as Control
		if slot == null or not slot.visible:
			continue
		var h: float = slot.get_combined_minimum_size().y
		if row_h < 0.0:
			row_h = h
		else:
			_assert(is_equal_approx(h, row_h), "owned rows keep one shared height")
	if roles.size() >= 1:
		var hands_role: Label = roles[0] as Label
		_assert(hands_role != null and str(hands_role.text) == "Pick up small finds", "hands keep the harvest role")
		_assert(hands_role != null and not hands_role.visible, "role moved to the hover tip (slim rail)")
		var buttons: Array = hud.get("_tool_buttons") as Array
		if hands_role != null and buttons.size() > 0:
			var card: Button = buttons[0] as Button
			_assert(card != null and card.is_ancestor_of(hands_role), "role sits inside the Hands card")
			_assert(hands_role.get_parent() != slots[0], "role does not protrude under the stack")
	hud.queue_free()


func _test_tool_cards_stay_in_the_gutter() -> void:
	_reset()
	GS.money = 5000
	GS.buy("shovel_click")
	GS.buy("pick_click")
	GS.buy("brush_speed")
	var hud: CanvasLayer = _make_hud()
	if hud == null:
		return
	hud.call("refresh", 40.0, 40.0, TN.TOOL_HANDS, true)
	var pit := _pit_rect()
	var buttons: Array = hud.get("_tool_buttons") as Array
	var slots: Array = hud.get("_tool_slots") as Array
	var slot_tools: Array = hud.get("_slot_tools") as Array
	var matched: int = 0
	var rest_heights := PackedFloat32Array()
	for i in slot_tools.size():
		var slot: Control = slots[i] as Control
		var button: Button = buttons[i] as Button
		if slot == null or button == null or not slot.visible:
			continue
		matched += 1
		var card := _card_size(button, slot)
		var card_right: float = _control_rect(button).end.x
		if card_right <= 8.0:
			card_right = _control_rect(slot).end.x
		_assert(not pit.intersects(_control_rect(button)), "tool card stays off the pit")
		_assert(not pit.intersects(_control_rect(slot)), "tool slot stays off the pit")
		_assert(card.y <= 110.0 + 0.5, "stacked tool cards do not grow past the pit")
		_assert(_control_rect(slot).end.y <= pit.end.y + 0.5, "tool stack stays inside the pit height")
		var gutter_w: float = maxf(pit.position.x - 8.0 - 1.0, 1.0)
		_assert(card.x <= gutter_w + 0.01, "tool card width stays in the left gutter")
		_assert_rail_card_layout(button, GS.tool_display_name(int(slot_tools[i])))
		rest_heights.append(card.y)
	_assert(matched == 4, "all four owned tools stay in the gutter")
	var rest_names: Array[Rect2] = []
	for i in slot_tools.size():
		var button: Button = buttons[i] as Button
		if button == null:
			rest_names.append(Rect2())
			continue
		rest_names.append(_name_row_rect_in_card(button))
	for raw_button in buttons:
		var live: Button = raw_button as Button
		if live != null:
			live.mouse_entered.emit()
			_flush_tool_card(live)
	for i in slot_tools.size():
		var slot: Control = slots[i] as Control
		var button: Button = buttons[i] as Button
		if slot == null or button == null or not slot.visible:
			continue
		_assert(is_equal_approx(_card_size(button, slot).y, rest_heights[0] if rest_heights.size() > 0 else 0.0), "hover keeps a shared card height")
		var hover_name := _name_row_rect_in_card(button)
		if i < rest_names.size() and rest_names[i].size.y > 1.0:
			_assert(rest_names[i].position.is_equal_approx(hover_name.position), "name position does not depend on hover")
		var role: Label = (hud.get("_tool_roles") as Array)[i] as Label
		if role != null:
			_assert(not role.visible, "slim cards keep the role in the hover tip")
			_assert(int(role.horizontal_alignment) == HORIZONTAL_ALIGNMENT_CENTER, "role copy is centered")
			var role_rect := _control_rect_in_card(role, button)
			_assert(absf(role_rect.position.x + role_rect.size.x * 0.5 - _card_size(button, slot).x * 0.5) <= 3.0, "role sits in the horizontal center")
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
	_assert(tools != null, "left rail is labeled Tools")
	_assert(_rail_section_label(hud, "Working find") == null, "Working find left the live HUD")
	if tools == null:
		hud.queue_free()
		return
	_assert(str(tools.text) == "Tools", "Tools label keeps its copy")
	_assert(_rail_section_label(hud, "Next Upgrades") == null, "Next Upgrades left the live HUD")
	_assert(int(tools.horizontal_alignment) == HORIZONTAL_ALIGNMENT_CENTER, "Tools is centered over the left rail")
	_assert(int(tools.get_theme_font_size("font_size")) >= 22, "Tools uses section-size type, not caption whisper")
	var tools_ink: Color = tools.get_theme_color("font_color")
	_assert(not _color_is_muted(tools_ink), "Tools is not washed caption beige")
	_assert(not _color_is_gold(tools_ink), "Tools is not gold-on-tan")
	_assert(_color_is_light_ink(tools_ink), "Tools is light ink on the dark rail")
	_assert(int(tools.get_theme_constant("outline_size")) == 0, "Tools has no stroke halo")
	_assert(not _label_paints_plate(tools), "Tools title is text only, no plate")
	_assert(int(tools.focus_mode) == Control.FOCUS_NONE, "Tools title has no focus box")
	_assert(_title_width_tracks_glyphs(tools), "Tools width tracks the glyphs, not a StyleBox")
	var pit := _pit_rect()
	_assert(not pit.intersects(_control_rect(tools)), "Tools label stays off the pit")
	_assert(tools.global_position.y + tools.size.y <= pit.position.y + 0.5 or _control_rect(tools).end.x <= pit.position.x + 0.5, "Tools sits in the header or left gutter")
	var rail: Control = hud.get("_tool_rail") as Control
	var first_card: Control = _first_visible_tool_card(hud)
	if first_card != null:
		_assert(_control_rect(tools).end.y <= _control_rect(first_card).position.y + 0.5, "Tools sits above the first tool card")
		_assert(_control_rect(first_card).position.y - _control_rect(tools).end.y >= 10.0, "Tools clears the first card corner")
		_assert(absf((_control_rect(tools).get_center().x) - _control_rect(first_card).get_center().x) <= 8.0, "Tools is centered on the left rail")
	var tools_frame: Control = hud.get("_tools_frame") as Control
	if tools_frame != null:
		_assert(_control_rect(tools).position.y + 0.5 >= tools_frame.position.y + 10.0, "Tools title sits inside the section, not on the rim")
		_assert(_control_rect(tools).end.y <= tools_frame.position.y + tools_frame.size.y + 0.5, "Tools title stays inside the section")
	if tools_frame != null and first_card != null:
		_assert(_control_rect(first_card).position.x + 0.5 >= tools_frame.position.x + 8.0, "tool cards keep padding inside the section")
		_assert(_control_rect(first_card).end.x <= tools_frame.position.x + tools_frame.size.x - 8.0 + 0.5, "tool cards keep right padding inside the section")
	if first_card is Button:
		_assert_rail_card_has_one_rounded_box(first_card as Button, "tool card")
	if rail != null:
		_assert(not pit.intersects(_control_rect(rail)), "labeled tool rail stays off the pit")
	_assert(hud.get("_work_frame") == null, "Working find frame left the live HUD")
	for raw_frame in [hud.get("_tools_frame"), hud.get("_finds_frame")]:
		var frame: Control = raw_frame as Control
		_assert(frame != null, "section frames mark Tools and Finds")
		if frame == null:
			continue
		_assert(_panel_paints_fill(frame), "section frames have a panel fill")
		var box: StyleBox = frame.get_theme_stylebox("panel")
		_assert(box is StyleBoxFlat and (box as StyleBoxFlat).border_width_left >= 2, "section frames have a visible outline")
	if tools_frame != null:
		_assert(absf(tools_frame.position.y - pit.position.y) <= 0.5, "Tools frame lines up with the pit top")
		_assert(absf(tools_frame.size.y - (pit.size.y + float(TN.chunk_front))) <= 0.5, "Tools frame runs the pit's full height")
		var fill_box: StyleBox = tools_frame.get_theme_stylebox("panel")
		_assert(fill_box is StyleBoxFlat and _color_is_dark_panel((fill_box as StyleBoxFlat).bg_color), "Tools fill is dark")
	hud.queue_free()


func _test_selected_tool_uses_outline_not_dim() -> void:
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
	_assert_rail_card_has_one_rounded_box(selected, "selected tool")
	_assert_rail_card_has_one_rounded_box(neighbor, "idle tool")
	_assert(is_equal_approx(neighbor.modulate.a, 1.0) and neighbor.modulate.r >= 0.95 and neighbor.modulate.g >= 0.95, "idle owned tools stay at full brightness")
	_assert(is_equal_approx(selected.modulate.a, 1.0) and selected.modulate.r >= 0.95 and selected.modulate.g >= 0.95, "the live tool stays at full brightness")
	if idle_box != null and "bg_color" in idle_box:
		_assert(_looks_like_available_brass(idle_box.bg_color), "idle owned cards use idle brass / available NEXT fill")
	var sel_size: Vector2 = _card_size(selected, null)
	var idle_size: Vector2 = _card_size(neighbor, null)
	_assert(is_equal_approx(sel_size.y, idle_size.y), "selected chrome does not grow the card")
	hud.queue_free()


func _test_dig_buttons_share_gold_hover_and_light_shadow() -> void:
	_reset()
	GS.money = 0
	GS.levels["shovel_click"] = 1
	GS.apply_upgrades()
	var hud: CanvasLayer = _make_hud()
	if hud == null:
		return
	hud.call("refresh", 40.0, 40.0, TN.TOOL_HANDS, true)
	var selected: Button = null
	var idle: Button = null
	var buttons: Array = hud.get("_tool_buttons") as Array
	var slot_tools: Array = hud.get("_slot_tools") as Array
	for i in slot_tools.size():
		if int(slot_tools[i]) == int(TN.TOOL_HANDS):
			selected = buttons[i] as Button
		elif int(slot_tools[i]) == int(TN.TOOL_SHOVEL):
			idle = buttons[i] as Button
	_assert(selected != null and idle != null, "owned tools expose hover styleboxes")
	if selected != null:
		_assert_gold_hover_outline(selected, "selected tool")
		_assert_hud_button_shadow(selected, "selected tool")
		var sel_normal: StyleBox = selected.get_theme_stylebox("normal")
		var sel_hover: StyleBox = selected.get_theme_stylebox("hover")
		if sel_normal != null and sel_hover != null and "border_width" in sel_normal and "border_width" in sel_hover:
			_assert(int(sel_hover.border_width) == int(sel_normal.border_width), "selected+hover keeps one gold outline")
	if idle != null:
		_assert_gold_hover_outline(idle, "idle tool")
		_assert_hud_button_shadow(idle, "idle tool")
	var settings: Node = _show_shared_nav()
	for raw in [_nav_btn(settings, "_menu_btn"), _nav_btn(settings, "_back_btn"), _nav_btn(settings, "_end_btn")]:
		var header: Button = raw as Button
		_assert(header != null, "header action is a button")
		if header != null:
			_assert_gold_hover_outline(header, header.text)
			_assert_hud_button_shadow(header, header.text)
	_assert(hud.get("_shop_btn") == null, "Upgrades is gone from the live HUD")
	_assert(hud.get("_museum_btn") == null, "Museum is gone from the live HUD")
	var catalog := Button.new()
	root.add_child(catalog)
	var Ui: GDScript = load("res://ui_style.gd") as GDScript
	Ui.apply_button(catalog)
	var shop_box: StyleBox = catalog.get_theme_stylebox("normal")
	_assert(shop_box != null and "shadow_size" in shop_box and int(shop_box.shadow_size) >= 6, "catalog apply_button keeps a deeper drop")
	catalog.queue_free()
	hud.queue_free()


func _test_unowned_tools_stay_hidden() -> void:
	_reset()
	var hud: CanvasLayer = _make_hud()
	if hud == null:
		return
	hud.call("refresh", 40.0, 40.0, TN.TOOL_HANDS, true)
	var slots: Array = hud.get("_tool_slots") as Array
	var slot_tools: Array = hud.get("_slot_tools") as Array
	var shown: int = 0
	for i in slots.size():
		var slot: Control = slots[i] as Control
		if slot != null and slot.visible:
			shown += 1
			_assert(int(slot_tools[i]) == int(TN.TOOL_HANDS), "the only start row is Hands")
	_assert(shown == 1, "unowned shovel/pick/brush stay hidden")
	hud.queue_free()


func _test_live_hud_has_no_next_or_meta_doors() -> void:
	_reset()
	GS.money = 5000
	GS.buy("shovel_click")
	GS.buy("pick_click")
	GS.buy("brush_speed")
	var hud: CanvasLayer = _make_hud()
	if hud == null:
		return
	hud.call("refresh", 40.0, 40.0, TN.TOOL_HANDS, true)
	_assert(not hud.has_signal("shop_pressed"), "live HUD has no shop_pressed mid-shift")
	_assert(not hud.has_signal("museum_pressed"), "live HUD has no museum_pressed mid-shift")
	_assert(hud.get("_shop_btn") == null, "Upgrades button is gone from the pit")
	_assert(hud.get("_museum_btn") == null, "Museum button is gone from the pit")
	_assert(hud.get("_chip") == null, "NEXT chip is gone from the pit")
	_assert(_visible_next_plates(hud).is_empty(), "NEXT plates are gone from the pit")
	_assert(_rail_section_label(hud, "Next Upgrades") == null, "Next Upgrades label is gone")
	_assert(_find_button(hud, "Upgrades") == null, "no Upgrades door on the live HUD")
	_assert(_find_button(hud, "Museum") == null, "no Museum door on the live HUD")
	_assert(hud.get("_right_dock") == null, "right rail left the live HUD")
	_assert(_find_button(hud, "Upgrades") == null, "doors do not live on a reserved right rail")
	hud.queue_free()


func _test_working_find_left_the_live_hud() -> void:
	_reset()
	var hud: CanvasLayer = _make_hud()
	if hud == null:
		return
	hud.call("refresh", 40.0, 40.0, TN.TOOL_HANDS, true)
	_assert(hud.get("_work_card") == null, "Working find card left the live HUD")
	_assert(hud.get("_work_frame") == null, "Working find frame left the live HUD")
	_assert(hud.get("_right_dock") == null, "right rail left the live HUD")
	_assert(_rail_section_label(hud, "Working find") == null, "Working find title left the live HUD")
	hud.call("set_find_cards", [_card("T. rex Tooth", "t_rex_tooth", "brush", 5, "Brushed 40%", 80, 0, "New · 1/6")])
	_assert(_hud_chips(hud).size() == 1, "Finds still shows the uncovered bone")
	hud.queue_free()


func _retired_next_plates_show_every_owned_tool() -> void:
	_reset()
	GS.money = 5000
	GS.buy("shovel_click")
	GS.buy("pick_click")
	GS.buy("brush_speed")
	var hud: CanvasLayer = _make_hud()
	if hud == null:
		return
	hud.call("refresh", 40.0, 40.0, TN.TOOL_HANDS, true)
	var plates: Array = _visible_next_plates(hud)
	_assert(plates.size() == 4, "every owned tool can show a NEXT plate at once")
	var shown_tools: Array = []
	for raw in plates:
		var plate: Button = raw as Button
		var tool: int = _plate_tool(hud, plate)
		shown_tools.append(tool)
		_assert(GS.owns_tool(tool), "NEXT plates follow the same hide-unowned rule as the left list")
		_assert(not str(GS.next_shop_id(tool)).is_empty(), "owned tools that still have a buy show that buy")
		var caption: String = _chip_caption(plate)
		var effect: String = str(GS.shop_effect_line(str(GS.next_shop_id(tool))))
		_assert(caption.contains(GS.tool_display_name(tool)) or caption.contains("Next"), "plate names its tool or says Next")
		_assert(_caption_has_effect(caption, effect), "plate uses that tool's this-buy line")
		_assert(caption.contains("$"), "plate shows that tool's cost")
		_assert(not caption.contains("Nextupgrade"), "Next upgrade keeps its space")
		_assert(_plate_words_stay_apart(plate), "plate copy does not smash word spaces")
	_assert(shown_tools.has(TN.TOOL_HANDS) and shown_tools.has(TN.TOOL_SHOVEL), "Hands selected still shows the shovel plate")
	_assert(shown_tools.has(TN.TOOL_PICKAXE) and shown_tools.has(TN.TOOL_BRUSH), "selected-only NEXT is gone")
	var dock: Control = hud.get("_right_dock") as Control
	_assert(dock != null, "right rail hosts the NEXT plates")
	if dock != null:
		_assert(dock.position.x >= TN.view_w - float(TN.hud_rail_w()) - 8.0, "NEXT plates sit in the right gutter")
		_assert(dock.position.y < float(TN.footer_top()), "NEXT plates left the footer")
		var pit := _pit_rect()
		_assert(not pit.intersects(Rect2(dock.position, dock.size).grow(-2.0)), "NEXT plates stay off the pit")
		for raw_child in dock.get_children():
			_assert(raw_child is Button and str((raw_child as Button).text) != "Upgrades", "doors do not live on the right rail")
	hud.queue_free()


func _test_next_plate_buys_its_own_tool() -> void:
	_reset()
	GS.money = 5000
	GS.buy("shovel_click")
	var hud: CanvasLayer = _make_hud()
	if hud == null:
		return
	hud.call("refresh", 40.0, 40.0, TN.TOOL_HANDS, true)
	var shovel_plate: Button = _plate_for_tool(hud, TN.TOOL_SHOVEL)
	_assert(shovel_plate != null and shovel_plate.visible, "shovel plate shows while Hands is selected")
	if shovel_plate == null:
		hud.queue_free()
		return
	var shop_id: String = str(GS.next_shop_id(TN.TOOL_SHOVEL))
	var before_shovel: int = int(GS.levels.get(shop_id, 0))
	var before_hands: int = int(GS.levels.get("hands_click", 0))
	GS.money = int(GS.cost_of(shop_id))
	hud.call("refresh", 40.0, 40.0, TN.TOOL_HANDS, true)
	shovel_plate.pressed.emit()
	_assert(int(GS.levels.get(shop_id, 0)) == before_shovel + 1, "clicking the shovel plate buys the shovel next")
	_assert(int(GS.levels.get("hands_click", 0)) == before_hands, "the shovel plate does not buy the selected tool")
	hud.queue_free()


func _test_next_plates_keep_sku_when_money_changes() -> void:
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
	var broke: Dictionary = {}
	for tool in [TN.TOOL_HANDS, TN.TOOL_SHOVEL, TN.TOOL_PICKAXE, TN.TOOL_BRUSH]:
		var plate: Button = _plate_for_tool(hud, tool)
		_assert(plate != null and plate.visible, "%s plate stays up while broke" % GS.tool_display_name(tool))
		broke[tool] = str(GS.next_shop_id(tool))
		_assert(not str(broke[tool]).is_empty(), "%s still has a cheapest next" % GS.tool_display_name(tool))
	_assert(str(broke[TN.TOOL_HANDS]) == "hands_click", "broke Hands plate is the cheap Hands rank")
	_assert(str(broke[TN.TOOL_SHOVEL]) == "shovel_click", "broke Shovel plate is the cheap shovel rank")
	GS.money = 40
	hud.call("refresh", 40.0, 40.0, TN.TOOL_PICKAXE, true)
	for tool in broke.keys():
		var plate: Button = _plate_for_tool(hud, tool)
		_assert(str(GS.next_shop_id(tool)) == str(broke[tool]), "%s SKU does not swap at $40" % GS.tool_display_name(tool))
		var caption: String = _chip_caption(plate)
		_assert(_caption_has_effect(caption, str(GS.shop_effect_line(str(broke[tool])))), "%s plate still shows the same this-buy" % GS.tool_display_name(tool))
	hud.queue_free()


func _test_next_plate_shows_maxed() -> void:
	_reset()
	for item in GS.catalog:
		var id: String = str(item["id"])
		if GS.tool_for_upgrade(id) == TN.TOOL_SHOVEL:
			GS.levels[id] = int(item["max"])
	GS.apply_upgrades()
	var hud: CanvasLayer = _make_hud()
	if hud == null:
		return
	hud.call("refresh", 40.0, 40.0, TN.TOOL_HANDS, true)
	var shovel: Button = _plate_for_tool(hud, TN.TOOL_SHOVEL)
	_assert(shovel != null and shovel.visible, "maxed shovel keeps its plate")
	if shovel != null:
		var caption: String = _chip_caption(shovel)
		_assert(caption.contains("Maxed") or caption.contains("maxed"), "maxed shovel plate reads Maxed")
		_assert(caption.contains("Shovel") or caption.contains("shovel"), "maxed plate still names Shovel")
		_assert(not caption.contains("$"), "maxed plate is not a buy")
		_assert(shovel.disabled, "maxed plate is not clickable-as-success")
	var brush: Button = _plate_for_tool(hud, TN.TOOL_BRUSH)
	_assert(brush == null or not brush.visible, "unowned brush still has no plate")
	var hands: Button = _plate_for_tool(hud, TN.TOOL_HANDS)
	_assert(hands != null and hands.visible, "maxed shovel does not hide Hands")
	hud.queue_free()


func _test_next_plate_afford_vs_unafford_chrome() -> void:
	_reset()
	GS.levels["shovel_click"] = 1
	GS.apply_upgrades()
	GS.money = 0
	var hud: CanvasLayer = _make_hud()
	if hud == null:
		return
	hud.call("refresh", 40.0, 40.0, TN.TOOL_HANDS, true)
	if hud.has_method("_process"):
		hud._process(0.016)
	var plate: Button = _plate_for_tool(hud, TN.TOOL_SHOVEL)
	_assert(plate != null and plate.visible, "shovel plate shows while Hands is selected")
	if plate == null:
		hud.queue_free()
		return
	var shop_id: String = str(GS.next_shop_id(TN.TOOL_SHOVEL))
	var cost: int = int(GS.cost_of(shop_id))
	var caption: String = _chip_caption(plate)
	_assert(caption.contains("$%d" % cost), "unaffordable plate still shows the price")
	_assert(plate.disabled, "unaffordable plate is not clickable-as-success")
	_assert(_plate_is_muted(plate), "unaffordable plate is muted")
	var price: Label = _plate_price_label(hud, plate)
	_assert(price != null and str(price.text).begins_with("$"), "unaffordable price stays visible")
	if price != null:
		_assert(_color_is_muted(price.get_theme_color("font_color")), "unaffordable price is muted")
	GS.money = cost
	hud.call("refresh", 40.0, 40.0, TN.TOOL_HANDS, true)
	if hud.has_method("_process"):
		hud._process(0.016)
	_assert(str(GS.next_shop_id(TN.TOOL_SHOVEL)) == shop_id, "crossing the price does not swap the SKU")
	_assert(not plate.disabled, "affordable plate can buy")
	_assert(_plate_looks_live(plate), "affordable plate looks live")
	_assert(_chip_caption(plate).contains("$%d" % cost), "affordable plate keeps the loud price")
	if price != null:
		var gold: Color = price.get_theme_color("font_color")
		_assert(gold.r > 0.75 and gold.g > 0.55 and gold.b < 0.55, "affordable price is gold")
	hud.queue_free()


func _test_integrity_plate_keeps_word_spaces() -> void:
	_reset()
	for item in GS.catalog:
		var id: String = str(item["id"])
		if id.begins_with("pick") and id != "pick_soft":
			GS.levels[id] = int(item["max"])
	GS.apply_upgrades()
	GS.money = 0
	var hud: CanvasLayer = _make_hud()
	if hud == null:
		return
	hud.call("refresh", 40.0, 40.0, TN.TOOL_HANDS, true)
	var plate: Button = _plate_for_tool(hud, TN.TOOL_PICKAXE)
	_assert(plate != null and plate.visible, "Blunted Point still gets a pick plate")
	if plate == null:
		hud.queue_free()
		return
	var shop_id: String = str(GS.next_shop_id(TN.TOOL_PICKAXE))
	_assert(shop_id == "pick_soft", "pick next is the Gentle Picking buy")
	var effect: String = str(GS.shop_effect_line(shop_id))
	_assert(effect.contains("Great or Perfect"), "odds line names Great or Perfect bones")
	_assert(effect.contains("→"), "odds line shows before → after")
	var caption: String = _chip_caption(plate)
	_assert(_caption_has_effect(caption, effect), "integrity plate shows the full Hits cost line")
	_assert(not caption.contains("GreatorPerfect"), "odds line keeps its spaces")
	_assert(not caption.contains("Perfectbones"), "Perfect bones is not cut off mid-word")
	_assert(caption.contains("$"), "integrity plate still shows the wallet price")
	_assert(_plate_words_stay_apart(plate), "integrity plate wraps instead of clipping")
	hud.queue_free()


func _test_header_menu_and_end_shift() -> void:
	_reset()
	var hud: CanvasLayer = _make_hud()
	if hud == null:
		return
	hud.call("refresh", 40.0, 40.0, TN.TOOL_HANDS, true)
	var settings: Node = _show_shared_nav()
	var header: Control = _nav_bar(settings)
	var wallet: Control = hud.get("_wallet") as Control
	var clock: Control = hud.get("_clock") as Control
	var menu_btn: Button = _nav_btn(settings, "_menu_btn")
	var back_btn: Button = _nav_btn(settings, "_back_btn")
	var end_btn: Button = _nav_btn(settings, "_end_btn")
	_assert(hud.get("_shop_btn") == null, "live HUD has no Upgrades door")
	_assert(hud.get("_museum_btn") == null, "live HUD has no Museum door")
	_assert(hud.get("_menu_btn") == null and hud.get("_end_btn") == null, "the dig HUD does not host a second Menu")
	_assert(menu_btn != null and str(menu_btn.text) == "Menu", "header has Menu")
	_assert(back_btn != null and str(back_btn.text) == "Back", "header has Back")
	_assert(end_btn != null and str(end_btn.text) == "End shift", "End shift stays in the shared header")
	_assert(header != null, "Menu lives in the header band")
	if header == null or wallet == null or clock == null:
		hud.queue_free()
		return
	_assert(menu_btn.get_parent() == header, "Menu sits in the header, not the pit")
	_assert(back_btn.get_parent() == header, "Back sits in the header with Menu")
	_assert(end_btn.get_parent() == header, "End shift sits in the header with Menu")
	_assert(hud.get("_right_dock") == null, "End shift is not parked on a working-find rail")
	_assert(_control_rect(end_btn).position.x >= TN.view_w * 0.55, "End shift sits on the right")
	_assert(_control_rect(end_btn).end.x <= TN.view_w - 4.0, "End shift stays on screen")
	_assert(_control_rect(end_btn).end.y <= float(TN.hud_h) + 0.5, "End shift stays in the header band")
	_assert(header.position.y + header.size.y <= float(TN.hud_h) + 0.5, "Menu stays in the header")
	_assert(header.position.y + header.size.y <= float(TN.grid_origin.y) - 0.5, "header does not grow into the dirt")
	_assert(header.position.x >= TN.view_w * 0.55, "Menu sits top-right")
	_assert(header.position.x + header.size.x <= TN.view_w - 4.0, "Menu stays on screen")
	_assert(_control_rect(menu_btn).position.x > _control_rect(back_btn).position.x, "Menu is the rightmost button")
	var pit := _pit_rect()
	var hole := Rect2(pit.position - Vector2(TN.chunk_pad, TN.chunk_pad), pit.size + Vector2(TN.chunk_pad * 2.0, TN.chunk_pad))
	var finds_frame: Control = hud.get("_finds_frame") as Control
	_assert(not pit.intersects(Rect2(header.position, header.size)), "Menu does not overlap the pit")
	_assert(not pit.intersects(_control_rect(end_btn)), "End shift stays off the pit")
	_assert(not hole.intersects(_control_rect(end_btn)), "End shift stays off the whole hole")
	if finds_frame != null:
		_assert(not _control_rect(end_btn).intersects(_control_rect(finds_frame)), "End shift does not clip Finds")
	_assert(_control_rect(clock).end.y <= pit.position.y - 2.0, "timer stays above the pit")
	_assert(_rail_section_label(hud, "Working find") == null, "Working find is gone so Menu cannot overlap it")
	hud.queue_free()


func _test_header_actions_carry_glyphs() -> void:
	_reset()
	var hud: CanvasLayer = _make_hud()
	if hud == null:
		return
	hud.call("refresh", 40.0, 40.0, TN.TOOL_HANDS, true)
	var settings: Node = _show_shared_nav()
	var menu_btn: Button = _nav_btn(settings, "_menu_btn")
	var end_btn: Button = _nav_btn(settings, "_end_btn")
	_assert(menu_btn != null and str(menu_btn.text) == "Menu", "Menu still says Menu")
	_assert(end_btn != null and str(end_btn.text) == "End shift", "End shift keeps its space")
	_assert(_action_glyph(menu_btn) == "gear", "Menu carries a gear mark")
	_assert(_action_glyph(end_btn) == "shift", "End shift carries a simple clock mark")
	_assert(_find_clock_face(end_btn) == null, "End shift is not a second analog clock face")
	_assert(_mark_sits_left_of_label(menu_btn), "Menu glyph sits left of the word")
	_assert(_mark_sits_left_of_label(end_btn), "End shift glyph sits left of the words")
	_assert_action_icon_spec(menu_btn, "Menu")
	_assert_action_icon_spec(end_btn, "End shift")
	var menu_mark: Control = _find_shop_icon(menu_btn) as Control
	var end_mark: Control = _find_shop_icon(end_btn) as Control
	if menu_mark != null and end_mark != null:
		_assert(is_equal_approx(menu_mark.size.x, end_mark.size.x) and is_equal_approx(menu_mark.size.y, end_mark.size.y), "header action glyphs share one box")
	hud.queue_free()


func _test_next_plates_reuse_left_rail_glyphs() -> void:
	_reset()
	GS.money = 5000
	GS.buy("shovel_click")
	GS.buy("pick_click")
	GS.buy("brush_speed")
	var hud: CanvasLayer = _make_hud()
	if hud == null:
		return
	hud.call("refresh", 40.0, 40.0, TN.TOOL_HANDS, true)
	for tool in [TN.TOOL_HANDS, TN.TOOL_SHOVEL, TN.TOOL_PICKAXE, TN.TOOL_BRUSH]:
		var plate: Button = _plate_for_tool(hud, tool)
		var rail_icon: Node = _rail_tool_icon(hud, tool)
		_assert(plate != null and plate.visible, "%s NEXT plate is on the right rail" % GS.tool_display_name(tool))
		if plate == null:
			continue
		var plate_icon: Node = _find_tool_icon(plate)
		_assert(plate_icon != null, "%s NEXT plate reuses the tool glyph" % GS.tool_display_name(tool))
		_assert(rail_icon != null, "%s left rail still has its tool glyph" % GS.tool_display_name(tool))
		if plate_icon != null:
			_assert(int(plate_icon.get("tool_id")) == int(tool), "%s plate glyph matches the left rail tool" % GS.tool_display_name(tool))
		_assert_tool_icons_match(plate_icon as Control, rail_icon as Control, GS.tool_display_name(tool))
		var caption: String = _chip_caption(plate)
		_assert(_caption_has_effect(caption, str(GS.shop_effect_line(str(GS.next_shop_id(tool))))), "%s plate still shows the this-buy line" % GS.tool_display_name(tool))
		_assert(caption.contains("$"), "%s plate still shows $" % GS.tool_display_name(tool))
	hud.queue_free()


func _test_wallet_width_does_not_follow_digits() -> void:
	_reset()
	var hud: CanvasLayer = _make_hud()
	if hud == null:
		return
	GS.money = 1
	hud.call("refresh", 40.0, 40.0, TN.TOOL_HANDS, true)
	var wallet: Control = hud.get("_wallet") as Control
	var money: Label = hud.get("_money") as Label
	_assert(wallet != null and money != null, "wallet card is on the HUD")
	if wallet == null or money == null:
		hud.queue_free()
		return
	var thin_w: float = wallet.size.x
	var thin_text: String = str(money.text)
	GS.money = 8888888
	hud.call("refresh", 40.0, 40.0, TN.TOOL_HANDS, true)
	var fat_w: float = wallet.size.x
	var fat_text: String = str(money.text)
	_assert(thin_text == "$1", "thin wallet still prints $1")
	_assert(fat_text == "$8888888", "fat wallet still prints $8888888")
	_assert(is_equal_approx(thin_w, fat_w), "wallet width does not follow money digits")
	GS.install_find("tooth", "Tooth", 1.0, true)
	hud.call("refresh", 40.0, 40.0, TN.TOOL_HANDS, true)
	var with_rate: float = wallet.size.x
	_assert(is_equal_approx(fat_w, with_rate), "wallet width does not follow the $/s caption")
	var hug: float = _copy_width("$1", 26) + 32.0 + 8.0 + 20.0
	_assert(thin_w > hug + 16.0, "wallet keeps room for a fat $8888888 amount")
	_assert(wallet.position.x <= 16.0 and wallet.position.y <= 16.0, "fixed wallet stays top-left")
	hud.queue_free()


func _test_find_chips_sit_under_the_pit() -> void:
	_reset()
	var hud: CanvasLayer = _make_hud()
	if hud == null:
		return
	hud.call("refresh", 40.0, 40.0, TN.TOOL_HANDS, true, true)
	hud.call("set_find_cards", [_card("Tooth", "t_rex_tooth", "brush", 5, "Brushed 40%", 80)])
	var find_box: Control = hud.get("_find_box") as Control
	_assert(find_box != null, "find tray lives on the HUD")
	if find_box == null:
		hud.queue_free()
		return
	var pit := _pit_rect()
	var rail: Rect2 = hud.call("finds_rail_rect")
	_assert(find_box.position.x >= pit.end.x + float(TN.chunk_pad) - 0.5, "chips sit in the right rail, beside the pit")
	_assert(find_box.position.y >= pit.position.y - 0.5, "chips start level with the pit")
	_assert(find_box.position.y + find_box.size.y <= rail.end.y + 0.5, "chips stay inside the Finds rail")
	_assert(is_equal_approx(find_box.size.x, rail.size.x - 20.0), "chips use the rail width")
	var tray_rect := Rect2(find_box.position, find_box.size)
	_assert(not pit.intersects(tray_rect), "chips do not sit on the pit grid")
	_assert(hud.get("_work_card") == null, "find chips have no working-find card to overlap")
	hud.queue_free()


func _test_deep_cells_stay_off_finds() -> void:
	_reset()
	var script: Script = load("res://dig_site.gd") as Script
	_assert(script != null, "dig site loads")
	if script == null:
		return
	var site: Node = script.new()
	root.add_child(site)
	if site.has_method("start_round"):
		site.call("start_round")
	var grid: Variant = site.get("_top_layer")
	_assert(grid is Array and not grid.is_empty(), "the pit has a layer grid")
	if not (grid is Array) or grid.is_empty():
		site.free()
		return
	for x in grid.size():
		var col: Array = grid[x]
		for y in col.size():
			col[y] = int(TN.layer_count)
	var last: Rect2 = site.call("_top_rect", 0, int(TN.grid_h) - 1)
	var south: float = float(TN.pit_face_bottom()) + float(TN.chunk_front)
	var plan_last_end: float = float(TN.pit_face_bottom()) - float(TN.cell_gap)
	_assert(last.end.y > plan_last_end + 4.0, "a fully dug last row actually steps down")
	_assert(last.end.y <= south - 2.0, "deep dirt stays inside the hole, not over Finds")
	var last_y: int = int(TN.grid_h) - 1
	if last_y >= 1:
		var col: Array = grid[0]
		col[last_y - 1] = 0
		col[last_y] = int(TN.layer_count)
		var shallow: Rect2 = site.call("_top_rect", 0, last_y - 1)
		var deep: Rect2 = site.call("_top_rect", 0, last_y)
		_assert(deep.position.y > shallow.position.y, "a deep hole still sits lower than the row above")
		_assert(deep.end.y <= south - 2.0, "interior depth stays off Finds")
	var hud: CanvasLayer = _make_hud()
	if hud != null:
		hud.call("refresh", 40.0, 40.0, TN.TOOL_HANDS, true)
		var finds_frame: Control = hud.get("_finds_frame") as Control
		var find_box: Control = hud.get("_find_box") as Control
		if finds_frame != null:
			_assert(last.end.x <= finds_frame.position.x - 2.0, "deep dirt stays off the Finds frame")
		if find_box != null:
			_assert(last.end.x <= find_box.position.x - 2.0, "deep dirt stays off the find chips")
		hud.queue_free()
	site.free()


func _test_finds_section_label() -> void:
	_reset()
	var hud: CanvasLayer = _make_hud()
	if hud == null:
		return
	hud.call("refresh", 40.0, 40.0, TN.TOOL_HANDS, true)
	hud.call("set_find_cards", [_card("Tooth", "t_rex_tooth", "brush", 5, "Brushed 40%", 80)])
	var finds: Label = _rail_section_label(hud, "Finds")
	_assert(finds != null, "footer tray is labeled Finds")
	if finds == null:
		hud.queue_free()
		return
	_assert(str(finds.text) == "Finds", "Finds label keeps its copy")
	_assert(int(finds.horizontal_alignment) == HORIZONTAL_ALIGNMENT_CENTER, "Finds is centered over the chip tray")
	_assert(int(finds.get_theme_font_size("font_size")) >= 22, "Finds uses section-size type, not caption whisper")
	var ink: Color = finds.get_theme_color("font_color")
	_assert(not _color_is_muted(ink), "Finds is not washed caption beige")
	_assert(not _color_is_gold(ink), "Finds is not gold-on-tan")
	_assert(_color_is_light_ink(ink), "Finds is light ink on the dark tray")
	_assert(int(finds.get_theme_constant("outline_size")) == 0, "Finds has no stroke halo")
	_assert(not _label_paints_plate(finds), "Finds title is text only, no plate")
	_assert(int(finds.focus_mode) == Control.FOCUS_NONE, "Finds title has no focus box")
	_assert(_title_width_tracks_glyphs(finds), "Finds width tracks the glyphs, not a StyleBox")
	_assert(finds.size.x + 8.0 < 117.0, "Finds is not a 117px plate")
	var pit := _pit_rect()
	var find_box: Control = hud.get("_find_box") as Control
	_assert(not pit.intersects(_control_rect(finds)), "Finds label stays off the pit")
	_assert(_control_rect(finds).position.x + 0.5 >= pit.end.x + float(TN.chunk_pad), "Finds sits in the right rail, clear of the pit")
	var finds_frame: Control = hud.get("_finds_frame") as Control
	if finds_frame != null:
		_assert(_control_rect(finds).position.y + 0.5 >= finds_frame.position.y + 10.0, "Finds title sits inside the section, not on the rim")
	if find_box != null:
		_assert(_control_rect(finds).end.y <= _control_rect(find_box).position.y + 0.5, "Finds sits above the chip tray")
		_assert(absf(_control_rect(finds).get_center().x - _control_rect(find_box).get_center().x) <= 8.0, "Finds is centered on the chip tray")
	var settings: Node = _show_shared_nav()
	var header: Control = _nav_bar(settings)
	if header != null:
		_assert(not _control_rect(finds).intersects(_control_rect(header)), "Finds stays out of the header Menu/End shift row")
	var end_btn: Control = _nav_btn(settings, "_end_btn")
	if finds_frame != null and end_btn != null:
		_assert(not _control_rect(end_btn).intersects(_control_rect(finds_frame)), "End shift does not sit on the Finds tray")
	hud.queue_free()


func _test_find_chips_scale_in_tray() -> void:
	_reset()
	var hud: CanvasLayer = _make_hud()
	if hud == null:
		return
	hud.call("refresh", 40.0, 40.0, TN.TOOL_HANDS, true)
	hud.call("set_find_cards", [_card("Tooth", "t_rex_tooth", "brush", 5, "Brushed 40%", 80, 0)])
	var one: Array = _hud_chips(hud)
	_assert(one.size() == 1, "one uncovered bone makes one tray chip")
	if one.size() == 1:
		var lone: Control = one[0] as Control
		_assert(lone != null and lone.visible and lone.get_parent() == hud.get("_find_box"), "the single chip lives in the tray")
		_assert(lone.custom_minimum_size.x >= 196.0, "one chip stays a comfortable width")
		_assert(_chip_shows_name_and_price(lone), "one chip still shows a name and $")
	var packed: Array = [
		_card("Tooth", "t_rex_tooth", "brush", 5, "Brushed 40%", 80, 0),
		_card("Plate", "stegosaurus_plate", "bagged", 4, "Brushed 100%", 40, 1),
		_card("Femur", "brachiosaurus_femur", "brush", 3, "Brushed 20%", 12, 2),
		_card("Pebble", "pebble", "bagged", 1, "Brushed 100%", 2, 3),
		_card("Flake", "flake", "brush", 1, "Brushed 10%", 1, 4),
		_card("Shell", "shell", "bagged", 2, "Brushed 100%", 6, 5),
	]
	hud.call("set_find_cards", packed)
	var chips: Array = _hud_chips(hud)
	_assert(chips.size() == 6, "six uncovered finds all become tray chips, including scraps")
	var find_box: Control = hud.get("_find_box") as Control
	_assert(find_box != null, "find tray lives on the HUD")
	if find_box == null:
		hud.queue_free()
		return
	var pit := _pit_rect()
	var rail: Rect2 = hud.call("finds_rail_rect")
	_assert(is_equal_approx(find_box.size.x, rail.size.x - 20.0), "packed chips use the rail width")
	_assert(not pit.intersects(Rect2(find_box.position, find_box.size)), "packed tray does not sit on the pit")
	var used: float = 0.0
	var row_y: float = -1.0
	for raw in chips:
		var chip: Control = raw as Control
		_assert(chip != null and chip.visible, "no packed chip is hidden")
		_assert(chip.get_parent() == find_box, "every packed chip sits in the tray")
		_assert(chip.custom_minimum_size.x + 0.5 >= 90.0, "packed chips stay readable, not postage stamps")
		_assert(_chip_shows_name_and_price(chip), "packed chips keep icon-name-$ at minimum")
		_assert(not pit.intersects(_control_rect(chip)), "a packed chip does not overlap the pit")
		used += chip.custom_minimum_size.y
		if row_y < 0.0:
			row_y = chip.position.x
		else:
			_assert(absf(chip.position.x - row_y) <= 1.0, "six chips stack in one column")
	used += 8.0 * 5.0
	_assert(used <= find_box.size.y + 1.0, "six chips fit in the rail")
	hud.queue_free()


func _test_hud_stays_off_the_pit() -> void:
	_reset()
	GS.money = 5000
	GS.buy("shovel_click")
	var hud: CanvasLayer = _make_hud()
	if hud == null:
		return
	hud.call("refresh", 40.0, 40.0, TN.TOOL_SHOVEL, true)
	hud.call("set_find_cards", [_card("Tooth", "t_rex_tooth", "brush", 5, "Brushed 40%", 80)])
	var pit := _pit_rect()
	var settings: Node = _show_shared_nav()
	var boxes: Array = [
		hud.get("_wallet"),
		hud.get("_clock"),
		hud.get("_tool_rail"),
		hud.get("_tools_frame"),
		hud.get("_find_box"),
		_nav_bar(settings),
		_nav_btn(settings, "_menu_btn"),
		_nav_btn(settings, "_back_btn"),
		_nav_btn(settings, "_end_btn"),
		hud.get("_tools_label"),
		hud.get("_finds_label"),
		hud.get("_clock_time"),
		hud.get("_clock_caption"),
	]
	for raw in boxes:
		var box: Control = raw as Control
		if box == null or not box.visible:
			continue
		var rect := _control_rect(box)
		_assert(not pit.intersects(rect), "%s does not intersect the pit grid" % box.name)
		var hole := Rect2(pit.position - Vector2(TN.chunk_pad, TN.chunk_pad), pit.size + Vector2(TN.chunk_pad * 2.0, TN.chunk_pad))
		if box == _nav_bar(settings) or box == _nav_btn(settings, "_menu_btn") or box == _nav_btn(settings, "_back_btn") or box == _nav_btn(settings, "_end_btn"):
			_assert(not hole.intersects(rect), "%s stays off the dig-site hole" % box.name)
	hud.queue_free()


func _test_pit_stays_1024_by_400() -> void:
	_reset()
	var pit: Vector2 = TN.fitted_pit_size()
	_assert(is_equal_approx(float(TN.grid_w) * TN.cell_w, pit.x), "cells fill the fitted pit width")
	_assert(is_equal_approx(float(TN.grid_h) * TN.cell_h, pit.y), "cells fill the fitted pit height")
	_assert(TN.hud_rail_w() <= 110.0, "left rail is a slim icon rail")
	_assert(TN.hud_rail_w() + pit.x + float(TN.finds_rail_w()) <= TN.view_w, "pit fits between the two rails")


func _test_tools_section_uses_the_wide_left_gutter() -> void:
	_reset()
	TN.apply_site_layout()
	var pit := _pit_rect()
	_assert(pit.size.x >= 800.0, "the pit stays large between the rails")
	_assert(pit.position.x >= TN.hud_rail_w(), "pit starts right of the tools rail")
	_assert(TN.view_w - pit.end.x >= float(TN.finds_rail_w()), "right side leaves room for the Finds rail")
	var hud: CanvasLayer = _make_hud()
	if hud == null:
		return
	hud.call("refresh", 40.0, 40.0, TN.TOOL_HANDS, true)
	var frame: Control = hud.get("_tools_frame") as Control
	_assert(frame != null, "Tools still has a section frame")
	if frame == null:
		hud.queue_free()
		return
	_assert(frame.size.x <= 100.0, "Tools section is a slim icon rail")
	_assert(frame.position.x + frame.size.x <= pit.position.x + 0.5, "wide Tools frame stays off the pit grid")
	var hole_left: float = pit.position.x - float(TN.chunk_pad)
	var frame_right: float = frame.position.x + frame.size.x
	_assert(frame_right <= hole_left - 1.0, "Tools frame stays off the dig-site hole, including the west pad")
	_assert(hole_left - frame_right >= 8.0, "Tools outline and pit outline keep a visible gap")
	hud.queue_free()


func _test_shop_and_museum_open_from_shift_over() -> void:
	_reset()
	var main: Node = _boot_main()
	if main == null:
		return
	var title: Node = main.get_node_or_null("Title")
	if title != null:
		var start: Variant = title.get("_start")
		if start is Button:
			start.pressed.emit()
	_assert(bool(main.round_active) and str(main.screen) == "dig", "Start is on the live pit")
	var hud: Node = main.get_node_or_null("HUD")
	_assert(hud != null, "live pit has a HUD")
	if hud == null:
		_cleanup_main(main)
		return
	_assert(not hud.has_signal("shop_pressed"), "HUD cannot open Upgrades mid-shift")
	_assert(not hud.has_signal("museum_pressed"), "HUD cannot open Museum mid-shift")
	_assert(hud.get("_shop_btn") == null, "the live-shift door is gone")
	if hud.has_signal("end_shift"):
		hud.end_shift.emit()
	var summary: Node = main.get_node_or_null("Summary")
	_assert(summary != null and bool(summary.visible), "End shift still shows the card")
	var upgrades: Button = _find_button(summary, "Upgrades")
	var museum_btn: Button = _find_button(summary, "Museum")
	_assert(upgrades != null, "shop still opens from shift-over Upgrades")
	_assert(museum_btn != null, "museum still opens from shift-over Museum")
	if upgrades != null:
		upgrades.pressed.emit()
	_assert(str(main.screen) == "shop", "shift-over Upgrades opens the existing shop overlay")
	_assert(bool(main.get_tree().paused), "Upgrades pauses the clock like Menu")
	var shop: Node = main.get_node_or_null("Shop")
	_assert(shop != null and bool(shop.visible), "full shop stays an overlay")
	_assert_dig_header_hidden(hud, "shop")
	_assert(_find_button(shop, "Back") == null, "shop does not host its own Back")
	_assert(_find_button(summary, "Dig again") != null, "shift-over still has Dig again")
	_assert(_find_button(summary, "Museum") != null, "shift-over still has Museum")
	_assert(_find_button(summary, "Upgrades") != null, "shift-over still has Upgrades")
	if museum_btn != null:
		museum_btn.pressed.emit()
	_assert(str(main.screen) == "museum", "shift-over Museum opens the existing hall")
	_assert(bool(main.get_tree().paused), "Museum pauses the clock like Menu")
	var museum: Node = main.get_node_or_null("Museum")
	_assert_dig_header_hidden(hud, "museum")
	if museum != null:
		museum.closed.emit()
	_cleanup_main(main)


func _test_shop_overlay_has_dig_museum_menu() -> void:
	_reset()
	var main: Node = _boot_main()
	if main == null:
		return
	_start_and_end_shift(main)
	var upgrades: Button = _find_button(main.get_node_or_null("Summary"), "Upgrades")
	if upgrades != null:
		upgrades.pressed.emit()
	_assert(str(main.screen) == "shop", "Upgrades opens the shop overlay")
	var settings: Node = root.get_node_or_null("Settings")
	var dig: Button = _nav_btn(settings, "_dig_btn")
	var museum: Button = _nav_btn(settings, "_museum_btn")
	var menu: Button = _nav_btn(settings, "_menu_btn")
	var back: Button = _nav_btn(settings, "_back_btn")
	var shop_btn: Button = _nav_btn(settings, "_upgrades_btn")
	_assert(dig != null and str(dig.text) == "Dig" and _is_drawn(dig), "shop overlay has Dig")
	_assert(museum != null and str(museum.text) == "Museum" and _is_drawn(museum), "shop overlay has Museum")
	_assert(menu != null and str(menu.text) == "Menu" and _is_drawn(menu), "shop overlay has Menu")
	_assert(not _is_drawn(back), "shop overlay drops Back")
	_assert(not _is_drawn(shop_btn), "shop overlay does not show Upgrades")
	_assert(not _is_drawn(_nav_btn(settings, "_end_btn")), "shop overlay has no End shift")
	_cleanup_main(main)


func _test_museum_overlay_has_dig_upgrades_menu() -> void:
	_reset()
	var main: Node = _boot_main()
	if main == null:
		return
	_start_and_end_shift(main)
	var museum_btn: Button = _find_button(main.get_node_or_null("Summary"), "Museum")
	if museum_btn != null:
		museum_btn.pressed.emit()
	_assert(str(main.screen) == "museum", "Museum opens the hall overlay")
	var settings: Node = root.get_node_or_null("Settings")
	var dig: Button = _nav_btn(settings, "_dig_btn")
	var upgrades: Button = _nav_btn(settings, "_upgrades_btn")
	var menu: Button = _nav_btn(settings, "_menu_btn")
	var back: Button = _nav_btn(settings, "_back_btn")
	var hall: Button = _nav_btn(settings, "_museum_btn")
	_assert(dig != null and str(dig.text) == "Dig" and _is_drawn(dig), "museum overlay has Dig")
	_assert(upgrades != null and str(upgrades.text) == "Upgrades" and _is_drawn(upgrades), "museum overlay has Upgrades")
	_assert(menu != null and str(menu.text) == "Menu" and _is_drawn(menu), "museum overlay has Menu")
	_assert(not _is_drawn(back), "museum overlay drops Back")
	_assert(not _is_drawn(hall), "museum overlay does not show Museum")
	_assert(not _is_drawn(_nav_btn(settings, "_end_btn")), "museum overlay has no End shift")
	_cleanup_main(main)


func _test_overlay_dig_starts_a_new_shift() -> void:
	_reset()
	var main: Node = _boot_main()
	if main == null:
		return
	_start_and_end_shift(main)
	var summary: Node = main.get_node_or_null("Summary")
	var upgrades: Button = _find_button(summary, "Upgrades")
	if upgrades != null:
		upgrades.pressed.emit()
	_assert(str(main.screen) == "shop", "shop is open before Dig")
	_assert(not bool(main.round_active), "the finished shift is over before Dig")
	var dig: Button = _nav_btn(root.get_node_or_null("Settings"), "_dig_btn")
	_assert(dig != null, "shop Dig is its own header button")
	if dig != null:
		_assert(str(dig.text) == "Dig", "Dig is the short overlay label")
		dig.pressed.emit()
	_assert(str(main.screen) == "dig", "Dig starts a new shift")
	_assert(bool(main.round_active), "Dig is the same as shift-over Dig again")
	_assert(summary == null or not bool(summary.visible), "the new shift hides shift-over")
	_cleanup_main(main)


func _test_overlay_museum_and_upgrades_swap_screens() -> void:
	_reset()
	var main: Node = _boot_main()
	if main == null:
		return
	_start_and_end_shift(main)
	var upgrades: Button = _find_button(main.get_node_or_null("Summary"), "Upgrades")
	if upgrades != null:
		upgrades.pressed.emit()
	_assert(str(main.screen) == "shop", "start on the shop overlay")
	_assert(bool(main.get_tree().paused), "shop keeps the clock paused")
	var settings: Node = root.get_node_or_null("Settings")
	var museum: Button = _nav_btn(settings, "_museum_btn")
	_assert(museum != null and _is_drawn(museum), "shop can swap to Museum")
	if museum != null:
		museum.pressed.emit()
	_assert(str(main.screen) == "museum", "Museum from shop swaps to the hall")
	if str(main.screen) != "museum":
		_cleanup_main(main)
		return
	_assert(bool(main.get_tree().paused), "the hall swap keeps the clock paused")
	var shop_btn: Button = _nav_btn(settings, "_upgrades_btn")
	_assert(shop_btn != null and _is_drawn(shop_btn), "museum can swap to Upgrades")
	if shop_btn != null:
		shop_btn.pressed.emit()
	_assert(str(main.screen) == "shop", "Upgrades from museum swaps back to the shop")
	_assert(bool(main.get_tree().paused), "the shop swap keeps the clock paused")
	_cleanup_main(main)


func _test_overlay_header_clears_wallet_and_museum_stats() -> void:
	_reset()
	var main: Node = _boot_main()
	if main == null:
		return
	_start_and_end_shift(main)
	var settings: Node = root.get_node_or_null("Settings")
	var museum_btn: Button = _find_button(main.get_node_or_null("Summary"), "Museum")
	if museum_btn != null:
		museum_btn.pressed.emit()
	_assert(str(main.screen) == "museum", "hall overlay is open")
	var wallet: Control = settings.get("_wallet") as Control if settings != null else null
	var nav: Control = _nav_bar(settings)
	_assert(wallet != null and _is_drawn(wallet), "wallet stays top-left on the hall")
	_assert(nav != null and _is_drawn(nav), "Dig/Upgrades/Menu stay top-right on the hall")
	if wallet != null and nav != null:
		_assert(wallet.position.x <= 16.0 and wallet.position.y <= 16.0, "wallet stays top-left")
		_assert(wallet.position.x + wallet.size.x + 8.0 <= nav.position.x, "header cluster stays clear of the wallet")
		_assert(nav.position.y <= 16.0, "overlay nav stays in the 86px header")
		_assert(nav.position.y + nav.size.y <= 86.0, "overlay nav stays inside HEADER_H")
	var museum: Node = main.get_node_or_null("Museum")
	if museum != null and museum.has_method("header_cluster_rect") and settings != null:
		var cluster: Rect2 = museum.call("header_cluster_rect")
		_assert(cluster.size.x > 1.0, "museum stats sit in the header")
		if settings.has_method("overlay_content_right"):
			_assert(cluster.end.x <= float(settings.call("overlay_content_right")) + 0.5, "museum stats stay clear of Dig/Upgrades/Menu")
		if nav != null:
			_assert(cluster.end.x <= nav.position.x - 4.0, "museum stats do not sit under the overlay nav")
		_assert_museum_header_stats_centered(museum, settings)
	if main.has_method("start_round"):
		main.start_round()
	_assert(str(main.screen) == "dig" and bool(main.round_active), "live pit is back for hole chrome")
	_assert_live_nav_off_the_hole(main)
	_cleanup_main(main)


func _test_overlays_hide_dig_header_menu() -> void:
	_reset()
	var main: Node = _boot_main()
	if main == null:
		return
	var title: Node = main.get_node_or_null("Title")
	if title != null:
		var start: Variant = title.get("_start")
		if start is Button:
			start.pressed.emit()
	var hud: Node = main.get_node_or_null("HUD")
	_assert(hud != null, "live pit has a HUD")
	if hud == null:
		_cleanup_main(main)
		return
	_assert_dig_header_shown(hud, "live pit")
	var settings: Node = root.get_node_or_null("Settings")
	if settings != null and settings.has_method("open_menu"):
		settings.call("open_menu")
		_assert_dig_header_hidden(hud, "settings")
		_assert(bool(settings.call("is_open")), "in-overlay settings still opens")
		settings.call("close_menu")
		_assert_dig_header_shown(hud, "closing settings")
	if hud.has_signal("end_shift"):
		hud.end_shift.emit()
	var summary: Node = main.get_node_or_null("Summary")
	_assert(summary != null and bool(summary.visible), "End shift still shows the card")
	_assert_dig_header_hidden(hud, "shift-over")
	_cleanup_main(main)


func _test_wallet_stays_top_left_on_overlays() -> void:
	_reset()
	var main: Node = _boot_main()
	if main == null:
		return
	var settings: Node = root.get_node_or_null("Settings")
	var title: Node = main.get_node_or_null("Title")
	_assert(settings != null and settings.get("_wallet") != null, "Settings hosts the one bank")
	if settings == null:
		_cleanup_main(main)
		return
	if title != null:
		_assert(not _is_drawn(settings.get("_wallet") as CanvasItem), "title hides the bank")
		var start: Variant = title.get("_start")
		if start is Button:
			start.pressed.emit()
	var hud: Node = main.get_node_or_null("HUD")
	var wallet: Control = settings.get("_wallet") as Control
	_assert(wallet != null, "the persistent wallet exists after Start")
	if wallet != null:
		_assert(_is_drawn(wallet), "the bank stays up on the live pit")
		_assert(wallet.position.x <= 16.0 and wallet.position.y <= 16.0, "the bank stays top-left on the pit")
	if hud != null and hud.has_signal("end_shift"):
		hud.end_shift.emit()
	_assert(_is_drawn(wallet), "the bank stays up on shift-over")
	var summary: Node = main.get_node_or_null("Summary")
	var upgrades: Button = _find_button(summary, "Upgrades")
	if upgrades != null:
		upgrades.pressed.emit()
	_assert(str(main.screen) == "shop", "Upgrades still opens the shop")
	_assert(_is_drawn(wallet), "the bank stays up on Upgrades")
	_assert(wallet.position.x <= 16.0 and wallet.position.y <= 16.0, "the bank stays top-left on Upgrades")
	var shop: Node = main.get_node_or_null("Shop")
	if shop != null:
		_assert(shop.get("_wallet") == null, "Upgrades does not keep its own $")
		shop.closed.emit()
	var museum_btn: Button = _find_button(summary, "Museum")
	if museum_btn != null:
		museum_btn.pressed.emit()
	_assert(_is_drawn(wallet), "the bank stays up in the hall")
	_assert(wallet.position.x <= 16.0 and wallet.position.y <= 16.0, "the bank stays top-left in the hall")
	_cleanup_main(main)


func _test_menu_and_back_stay_top_right() -> void:
	_reset()
	var main: Node = _boot_main()
	if main == null:
		return
	var settings: Node = root.get_node_or_null("Settings")
	_assert(settings != null, "Settings hosts the shared header")
	if settings == null:
		_cleanup_main(main)
		return
	var title: Node = main.get_node_or_null("Title")
	_assert(not _is_drawn(settings.get("_menu_btn") as CanvasItem), "title hides Menu")
	_assert(not _is_drawn(settings.get("_back_btn") as CanvasItem), "title hides Back")
	if title != null:
		var start: Variant = title.get("_start")
		if start is Button:
			start.pressed.emit()
	var menu: Control = settings.get("_menu_btn") as Control
	var back: Control = settings.get("_back_btn") as Control
	var end_btn: Control = settings.get("_end_btn") as Control
	_assert(_is_drawn(menu) and not _is_drawn(back) and _is_drawn(end_btn), "the live pit keeps Menu and End shift, no Back")
	_assert(menu.position.y <= 16.0 and back.position.y <= 16.0 and end_btn.position.y <= 16.0, "the cluster stays top-right on the pit")
	_assert(menu.global_position.x > back.global_position.x, "Menu stays the rightmost button")
	var hud: Node = main.get_node_or_null("HUD")
	if hud != null and hud.has_signal("end_shift"):
		hud.end_shift.emit()
	_assert(_is_drawn(menu) and _is_drawn(back), "shift-over keeps Menu and Back")
	_assert(not _is_drawn(end_btn), "End shift leaves after the shift ends")
	var upgrades: Button = _find_button(main.get_node_or_null("Summary"), "Upgrades")
	if upgrades != null:
		upgrades.pressed.emit()
	var dig: Control = settings.get("_dig_btn") as Control
	var hall: Control = settings.get("_museum_btn") as Control
	var shop_btn: Control = settings.get("_upgrades_btn") as Control
	_assert(_is_drawn(menu) and _is_drawn(dig) and _is_drawn(hall), "Upgrades keeps Dig, Museum, and Menu")
	_assert(not _is_drawn(back), "Upgrades drops Back")
	_assert(not _is_drawn(end_btn), "End shift stays off Upgrades")
	_assert(not _is_drawn(shop_btn), "Upgrades does not show itself")
	_assert(_control_rect(menu).position.x >= TN.view_w * 0.55, "Menu stays top-right on Upgrades")
	var museum_btn: Button = _nav_btn(settings, "_museum_btn")
	if museum_btn != null:
		museum_btn.pressed.emit()
	_assert(_is_drawn(menu) and _is_drawn(dig) and _is_drawn(shop_btn), "the hall keeps Dig, Upgrades, and Menu")
	_assert(not _is_drawn(back), "the hall drops Back")
	_assert(_control_rect(menu).position.x >= TN.view_w * 0.55, "Menu stays top-right in the hall")
	_cleanup_main(main)


func _make_hud() -> CanvasLayer:
	var hud_script: Script = load("res://hud.gd") as Script
	_assert(hud_script != null, "HUD script loads")
	if hud_script == null:
		return null
	var hud: CanvasLayer = hud_script.new() as CanvasLayer
	root.add_child(hud)
	return hud


func _boot_main() -> Node:
	var packed: PackedScene = load("res://main.tscn") as PackedScene
	_assert(packed != null, "main.tscn loads")
	if packed == null:
		return null
	var main: Node = packed.instantiate()
	root.add_child(main)
	return main


func _start_and_end_shift(main: Node) -> void:
	var title: Node = main.get_node_or_null("Title")
	if title != null:
		var start: Variant = title.get("_start")
		if start is Button:
			start.pressed.emit()
	var hud: Node = main.get_node_or_null("HUD")
	if hud != null and hud.has_signal("end_shift"):
		hud.end_shift.emit()


func _assert_live_nav_off_the_hole(main: Node) -> void:
	var settings: Node = root.get_node_or_null("Settings")
	if settings != null and settings.has_method("set_nav_context"):
		settings.call("set_nav_context", "dig")
	if settings != null and settings.has_method("set_end_shift_visible"):
		settings.call("set_end_shift_visible", true)
	if settings != null and settings.has_method("set_nav_visible"):
		settings.call("set_nav_visible", true)
	if settings != null and settings.has_method("_layout_nav_chrome"):
		settings.call("_layout_nav_chrome")
	var pit := _pit_rect()
	var hole := Rect2(pit.position - Vector2(TN.chunk_pad, TN.chunk_pad), pit.size + Vector2(TN.chunk_pad * 2.0, TN.chunk_pad))
	var header: Control = _nav_bar(settings)
	for raw in [header, _nav_btn(settings, "_menu_btn"), _nav_btn(settings, "_back_btn"), _nav_btn(settings, "_end_btn")]:
		var box: Control = raw as Control
		if box == null or not _is_drawn(box):
			continue
		_assert(not hole.intersects(_control_rect(box)), "%s stays off the dig-site hole" % box.name)


func _cleanup_main(main: Node) -> void:
	if main != null and main.get_tree() != null:
		main.get_tree().paused = false
	if main != null:
		main.free()


func _pit_rect() -> Rect2:
	if TN.has_method("pit_grid_rect"):
		return TN.pit_grid_rect()
	return Rect2(TN.grid_origin, Vector2(float(TN.grid_w) * TN.cell_w, float(TN.grid_h) * TN.cell_h))


func _rail_section_label(hud: Node, text: String) -> Label:
	for raw in [hud.get("_tools_label"), hud.get("_working_label"), hud.get("_finds_label")]:
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


func _first_visible_tool_card(hud: Node) -> Control:
	var buttons: Array = hud.get("_tool_buttons") as Array
	var slots: Array = hud.get("_tool_slots") as Array
	for i in buttons.size():
		var button: Button = buttons[i] as Button
		var slot: Control = slots[i] as Control if i < slots.size() else null
		if button != null and button.visible and (slot == null or slot.visible):
			return button
	return null


func _card_size(button: Button, _slot: Control) -> Vector2:
	return Vector2(maxf(button.size.x, button.custom_minimum_size.x), maxf(button.size.y, button.custom_minimum_size.y))


func _plate_size(plate: Button) -> Vector2:
	return Vector2(maxf(plate.size.x, plate.custom_minimum_size.x), maxf(plate.size.y, plate.custom_minimum_size.y))


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
	var card := _card_size(button, null)
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


func _slot_button_h(slot: Control) -> float:
	for child in slot.get_children():
		if child is Button:
			return maxf(child.custom_minimum_size.y, child.size.y)
	return slot.get_combined_minimum_size().y


func _slot_text(slot: Control) -> String:
	var parts: PackedStringArray = PackedStringArray()
	_collect_text(slot, parts)
	return " ".join(parts)


func _collect_text(node: Node, parts: PackedStringArray) -> void:
	if node is Label:
		parts.append(str(node.text))
	elif node is Button:
		parts.append(str(node.text))
	for child in node.get_children():
		_collect_text(child, parts)


func _chip_caption(chip: Button) -> String:
	var parts: PackedStringArray = PackedStringArray()
	_collect_text(chip, parts)
	return " ".join(parts)


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


func _control_rect(box: Control) -> Rect2:
	var rect := Rect2(box.global_position if box.global_position != Vector2.ZERO else box.position, box.size)
	if rect.position == Vector2.ZERO and box.get_parent() is Control:
		var parent: Control = box.get_parent() as Control
		rect.position = parent.position + box.position
	return rect


func _assert_museum_header_stats_centered(mus: Node, settings: Node) -> void:
	var left: float = 16.0
	var right: float = float(TN.view_w) - 16.0
	if settings != null and settings.has_method("overlay_content_left"):
		left = float(settings.call("overlay_content_left"))
	if settings != null and settings.has_method("overlay_content_right"):
		right = float(settings.call("overlay_content_right"))
	var header_mid: float = float(TN.view_w) * 0.5
	if mus.has_method("_view"):
		header_mid = mus._view().x * 0.5
	var text_cluster := Rect2()
	var started := false
	for pair in [
		["_visitors", "_visitors_cap", "visitors"],
		["_each", "_each_cap", "each"],
		["_rate", "_rate_cap", "rate"],
	]:
		var value: Label = mus.get(str(pair[0])) as Label
		var caption: Label = mus.get(str(pair[1])) as Label
		var name: String = str(pair[2])
		_assert(value != null and caption != null, "hall %s pair exists in the header" % name)
		if value == null or caption == null:
			continue
		var value_text: Rect2 = _museum_header_text_rect(value)
		var cap_text: Rect2 = _museum_header_text_rect(caption)
		_assert(value_text.size.x > 1.0 and cap_text.size.x > 1.0, "hall %s number and word have text" % name)
		_assert(absf(value_text.get_center().x - cap_text.get_center().x) <= 2.0, "hall %s number and word are centered as a unit" % name)
		var pair_text: Rect2 = value_text.merge(cap_text)
		if not started:
			text_cluster = pair_text
			started = true
		else:
			text_cluster = text_cluster.merge(pair_text)
	_assert(started, "hall visitor and money text sit in the header gutter")
	if started:
		_assert(text_cluster.position.x >= left - 0.5, "hall stats stay right of the wallet")
		_assert(text_cluster.end.x <= right + 0.5, "hall stats stay left of Dig/Upgrades/Menu")
		var ideal_left: float = header_mid - text_cluster.size.x * 0.5
		var placed_left: float = clampf(ideal_left, left, right - text_cluster.size.x)
		_assert(absf(text_cluster.get_center().x - (placed_left + text_cluster.size.x * 0.5)) <= 8.0, "hall visitor and money text are centered in the museum header")


func _museum_header_text_rect(label: Label) -> Rect2:
	if label == null:
		return Rect2()
	var font: Font = label.get_theme_font("font")
	var sized: int = label.get_theme_font_size("font_size")
	var text: String = str(label.text)
	var width: float = 0.0
	var lines: int = 0
	for line in text.split("\n"):
		lines += 1
		if font != null:
			width = maxf(width, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, sized).x)
	var height: float = maxf(label.size.y, float(maxi(1, lines) * (sized + 4)))
	var x: float = label.position.x
	if int(label.horizontal_alignment) == HORIZONTAL_ALIGNMENT_RIGHT:
		x = label.position.x + label.size.x - width
	elif int(label.horizontal_alignment) == HORIZONTAL_ALIGNMENT_CENTER:
		x = label.position.x + (label.size.x - width) * 0.5
	return Rect2(x, label.position.y, width, height)


func _header_cluster_rect(hud: Node) -> Rect2:
	var header: Control = hud.get("_header_bar") as Control
	var buttons: Array = [
		hud.get("_menu_btn"),
		hud.get("_end_btn"),
		hud.get("_museum_btn"),
		hud.get("_shop_btn"),
	]
	var cluster := Rect2()
	var started: bool = false
	for raw in buttons:
		var btn: Control = raw as Control
		if btn == null or not btn.visible:
			continue
		var rect := _control_rect(btn)
		if header != null:
			rect.position = header.position + btn.position
			if rect.size.x < 1.0:
				rect.size = btn.get_combined_minimum_size()
			if rect.size.x < 1.0:
				rect.size = btn.custom_minimum_size
		if not started:
			cluster = rect
			started = true
		else:
			cluster = cluster.merge(rect)
	return cluster


func _copy_width(text: String, size: int) -> float:
	var ui_script: Script = load("res://ui_style.gd") as Script
	if ui_script != null and ui_script.has_method("display_font"):
		var font: Font = ui_script.call("display_font")
		if font != null:
			return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	return float(text.length()) * float(size) * 0.6


func _plate_words_stay_apart(plate: Button) -> bool:
	for label in _plate_labels(plate):
		if label.clip_text:
			return false
		var text: String = str(label.text)
		if text.contains("  "):
			return false
		if text.contains("Great or Perfect") or text.contains("Next"):
			if text.contains("Hitscost") or text.contains("lessintegrit") or text.contains("Nextupgrade"):
				return false
	return true


func _plate_labels(node: Node) -> Array[Label]:
	var labels: Array[Label] = []
	if node is Label:
		labels.append(node)
	for child in node.get_children():
		labels.append_array(_plate_labels(child))
	return labels


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


func _hud_chips(hud: Node) -> Array:
	var raw: Variant = hud.get("_chips")
	if raw is Array:
		return raw
	return []


func _chip_shows_name_and_price(chip: Control) -> bool:
	if chip == null:
		return false
	var name_label: Label = chip.get("_name_label") as Label
	var price_label: Label = chip.get("_price_label") as Label
	var icon: Control = chip.get("_icon") as Control
	if name_label == null or price_label == null or icon == null:
		return false
	if name_label.text.strip_edges().is_empty():
		return false
	return price_label.text.find("$") >= 0


func _card(find_name: String, piece_id: String, status: String, stars: int, dirt: String, value: int, index: int = 0, progress: String = "") -> Dictionary:
	return {
		"index": index,
		"name": find_name,
		"piece_id": piece_id,
		"status": status,
		"stars": stars,
		"grade": "",
		"dirt": dirt,
		"value": value,
		"progress": progress,
		"integrity": 1.0,
		"clean": 0.4,
		"exposed": 1,
		"needed": 1,
		"centroid": Vector2(400, 300),
		"fully_exposed": true,
		"extracted": status == "bagged",
	}


func _partial_card(find_name: String, piece_id: String, integrity: float = 1.0) -> Dictionary:
	return {
		"index": 0,
		"name": find_name,
		"piece_id": piece_id,
		"status": "uncovering",
		"stars": 0,
		"grade": "",
		"dirt": "",
		"value": 0,
		"progress": "",
		"integrity": integrity,
		"clean": 0.0,
		"exposed": 1,
		"needed": 4,
		"centroid": Vector2(400, 300),
		"fully_exposed": false,
		"extracted": false,
	}


func _assert_dig_header_hidden(hud: Node, where: String) -> void:
	_assert(hud.get("_menu_btn") == null, "HUD Menu is not drawn over %s" % where)
	_assert(hud.get("_header_bar") == null, "header actions are not drawn over %s" % where)
	var settings: Node = root.get_node_or_null("Settings")
	if settings == null:
		return
	var chrome: CanvasItem = settings.get("_menu_btn") as CanvasItem
	var back: CanvasItem = settings.get("_back_btn") as CanvasItem
	var end_btn: CanvasItem = settings.get("_end_btn") as CanvasItem
	if where == "settings":
		_assert(not _is_drawn(chrome), "settings-layer Menu hides while the overlay is open")
		_assert(not _is_drawn(back), "Back hides while the overlay is open")
		return
	_assert(_is_drawn(chrome), "Menu stays available on %s" % where)
	var dig: CanvasItem = settings.get("_dig_btn") as CanvasItem
	var museum: CanvasItem = settings.get("_museum_btn") as CanvasItem
	var upgrades: CanvasItem = settings.get("_upgrades_btn") as CanvasItem
	if where == "shop":
		_assert(not _is_drawn(back), "shop drops Back")
		_assert(_is_drawn(dig), "shop has Dig")
		_assert(_is_drawn(museum), "shop has Museum")
		_assert(not _is_drawn(upgrades), "shop does not show Upgrades")
		_assert(not _is_drawn(end_btn), "End shift hides on shop")
		return
	if where == "museum":
		_assert(not _is_drawn(back), "museum drops Back")
		_assert(_is_drawn(dig), "museum has Dig")
		_assert(_is_drawn(upgrades), "museum has Upgrades")
		_assert(not _is_drawn(museum), "museum does not show Museum")
		_assert(not _is_drawn(end_btn), "End shift hides on museum")
		return
	if where == "shift-over":
		_assert(_is_drawn(back), "Back stays available on %s" % where)
	else:
		_assert(not _is_drawn(back), "the dig screen has no Back (%s)" % where)
	if where == "shift-over":
		_assert(not _is_drawn(end_btn), "End shift hides on shift-over")
		_assert(not _is_drawn(dig), "shift-over header has no Dig")
		_assert(not _is_drawn(museum), "shift-over header has no Museum")
		_assert(not _is_drawn(upgrades), "shift-over header has no Upgrades")


func _assert_dig_header_shown(hud: Node, where: String) -> void:
	_assert(hud.get("_menu_btn") == null, "the dig HUD does not keep its own Menu after %s" % where)
	var settings: Node = root.get_node_or_null("Settings")
	_assert(_is_drawn(settings.get("_menu_btn") as CanvasItem), "header Menu is visible again after %s" % where)
	_assert(not _is_drawn(settings.get("_back_btn") as CanvasItem), "the dig header has no Back after %s" % where)
	_assert(_is_drawn(settings.get("_end_btn") as CanvasItem), "End shift is visible again after %s" % where)
	_assert(not _is_drawn(settings.get("_dig_btn") as CanvasItem), "live pit header has no Dig after %s" % where)
	_assert(not _is_drawn(settings.get("_museum_btn") as CanvasItem), "live pit header has no Museum after %s" % where)
	_assert(not _is_drawn(settings.get("_upgrades_btn") as CanvasItem), "live pit header has no Upgrades after %s" % where)


func _show_shared_nav() -> Node:
	var settings: Node = root.get_node_or_null("Settings")
	if settings == null:
		return null
	if settings.has_method("set_nav_visible"):
		settings.call("set_nav_visible", true)
	elif settings.has_method("set_menu_chrome_visible"):
		settings.call("set_menu_chrome_visible", true)
	if settings.has_method("set_end_shift_visible"):
		settings.call("set_end_shift_visible", true)
	if settings.has_method("_layout_nav_chrome"):
		settings.call("_layout_nav_chrome")
	elif settings.has_method("_layout_menu_chrome"):
		settings.call("_layout_menu_chrome")
	return settings


func _nav_bar(settings: Node) -> Control:
	if settings == null:
		return null
	return settings.get("_nav_bar") as Control


func _nav_btn(settings: Node, key: String) -> Button:
	if settings == null:
		return null
	return settings.get(key) as Button


func _is_drawn(node: Node) -> bool:
	var walk: Node = node
	while walk != null:
		if walk is CanvasLayer and not bool((walk as CanvasLayer).visible):
			return false
		if walk is CanvasItem and not bool((walk as CanvasItem).visible):
			return false
		walk = walk.get_parent()
	return node != null


func _action_glyph(node: Node) -> String:
	var mark: Node = _find_shop_icon(node)
	if mark != null and "glyph" in mark:
		return str(mark.glyph)
	return ""


func _find_shop_icon(node: Node) -> Node:
	if node == null:
		return null
	var script: Script = node.get_script() as Script
	if script != null and str(script.resource_path).ends_with("shop_icon.gd"):
		return node
	for child in node.get_children():
		var found: Node = _find_shop_icon(child)
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


func _find_clock_face(node: Node) -> Node:
	if node == null:
		return null
	var script: Script = node.get_script() as Script
	if script != null and str(script.resource_path).ends_with("clock_face.gd"):
		return node
	for child in node.get_children():
		var found: Node = _find_clock_face(child)
		if found != null:
			return found
	return null


func _rail_tool_icon(hud: Node, tool: int) -> Node:
	var slots: Array = hud.get("_tool_slots") as Array
	var slot_tools: Array = hud.get("_slot_tools") as Array
	for i in slot_tools.size():
		if int(slot_tools[i]) == int(tool) and i < slots.size():
			return _find_tool_icon(slots[i] as Node)
	return null


func _assert_action_icon_spec(button: Button, where: String) -> void:
	var mark: Control = _find_shop_icon(button) as Control
	_assert(mark != null, "%s has an action glyph" % where)
	if mark == null or button == null:
		return
	_assert(is_equal_approx(mark.size.x, 18.0) and is_equal_approx(mark.size.y, 18.0), "%s glyph is the shared 18px action box" % where)
	_assert(is_equal_approx(mark.custom_minimum_size.x, 18.0) and is_equal_approx(mark.custom_minimum_size.y, 18.0), "%s glyph min-size is the shared 18px action box" % where)
	_assert(_mark_uses_icon_gap(button, mark, 8.0), "%s keeps an 8px gap before the word" % where)
	_assert(_mark_vcenters_to_label_line(button, mark), "%s glyph is vertically centered to the word" % where)
	_assert(mark.position.x + 1.0 < button.size.x * 0.5, "%s glyph stays left, not centered in the pill" % where)


func _assert_tool_icons_match(plate: Control, rail: Control, tool_name: String) -> void:
	_assert(plate != null and rail != null, "%s plate and rail both expose a tool glyph" % tool_name)
	if plate == null or rail == null:
		return
	_assert(is_equal_approx(plate.size.x, 22.0) and is_equal_approx(plate.size.y, 22.0), "%s NEXT glyph is the shared 22px tool box" % tool_name)
	_assert(rail.size.x >= 36.0 and rail.size.y >= 36.0, "%s rail glyph is the large stacked icon" % tool_name)
	_assert(rail.size.x > plate.size.x + 0.5, "%s rail icon is larger than the NEXT glyph" % tool_name)
	_assert(_hbox_gap(plate) == 8, "%s NEXT keeps an 8px gap before the tool name" % tool_name)
	_assert(_icon_vcenters_to_sibling_label(plate), "%s NEXT glyph is vertically centered to the name line" % tool_name)


func _hbox_gap(icon: Control) -> int:
	var row: Node = icon.get_parent() if icon != null else null
	if row is HBoxContainer:
		return int((row as HBoxContainer).get_theme_constant("separation"))
	return -1


func _icon_vcenters_to_sibling_label(icon: Control) -> bool:
	if icon == null:
		return false
	var row: Node = icon.get_parent()
	if row == null:
		return false
	var label: Label = null
	for child in row.get_children():
		if child is Label:
			label = child as Label
			break
	if label == null:
		return false
	return absf((icon.position.y + icon.size.y * 0.5) - (label.position.y + label.size.y * 0.5)) <= 2.5


func _mark_uses_icon_gap(button: Button, mark: Control, gap: float) -> bool:
	var text_x: float = _button_text_left(button)
	if text_x < 0.0:
		return false
	return absf(text_x - (mark.position.x + mark.size.x) - gap) <= 1.5


func _mark_vcenters_to_label_line(button: Button, mark: Control) -> bool:
	var font: Font = button.get_theme_font("font")
	var sized: int = button.get_theme_font_size("font_size")
	if font == null:
		return false
	var line_h: float = font.get_height(sized)
	var line_mid: float = (button.size.y - line_h) * 0.5 + line_h * 0.5
	return absf((mark.position.y + mark.size.y * 0.5) - line_mid) <= 2.0


func _button_text_left(button: Button) -> float:
	if button == null:
		return -1.0
	var font: Font = button.get_theme_font("font")
	var sized: int = button.get_theme_font_size("font_size")
	if font == null:
		return -1.0
	var box: StyleBox = button.get_theme_stylebox("normal")
	var pad_l: float = box.content_margin_left if box != null else 12.0
	var pad_r: float = box.content_margin_right if box != null else 12.0
	var text_w: float = font.get_string_size(str(button.text), HORIZONTAL_ALIGNMENT_LEFT, -1, sized).x
	var inner: float = maxf(button.size.x - pad_l - pad_r, 1.0)
	if button.alignment == HORIZONTAL_ALIGNMENT_LEFT:
		return pad_l
	if button.alignment == HORIZONTAL_ALIGNMENT_RIGHT:
		return pad_l + maxf(inner - text_w, 0.0)
	return pad_l + maxf(inner - text_w, 0.0) * 0.5


func _mark_sits_left_of_label(button: Button) -> bool:
	var mark: Control = _find_shop_icon(button) as Control
	if mark == null or button == null:
		return false
	var text_x: float = _button_text_left(button)
	if text_x < 0.0:
		return mark.position.x < button.size.x * 0.5
	return mark.position.x + mark.size.x <= text_x + 1.0


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


func _title_width_tracks_glyphs(label: Label) -> bool:
	if label == null:
		return false
	var font: Font = label.get_theme_font("font")
	var sized: int = label.get_theme_font_size("font_size")
	if font == null or sized <= 0:
		return false
	var need: float = 0.0
	for raw in str(label.text).split("\n", false):
		for word in str(raw).split(" ", false):
			need = maxf(need, font.get_string_size(str(word), HORIZONTAL_ALIGNMENT_LEFT, -1, sized).x)
	if label.autowrap_mode == TextServer.AUTOWRAP_OFF and not str(label.text).contains("\n"):
		need = font.get_string_size(str(label.text), HORIZONTAL_ALIGNMENT_LEFT, -1, sized).x
	return absf(label.size.x - need) <= 8.0


func _assert_rail_card_has_one_rounded_box(button: Button, where: String) -> void:
	_assert(button != null, "%s exists" % where)
	if button == null:
		return
	_assert(not button.clip_contents, "%s does not square-clip the rounded brass" % where)
	var radii: Array[int] = []
	for name in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		var box: StyleBox = button.get_theme_stylebox(name)
		_assert(_stylebox_is_rounded_plate(box), "%s %s is one rounded brass" % [where, name])
		_assert(not _stylebox_is_square_underbox(box), "%s %s is not a 0-radius under-box" % [where, name])
		if box != null and "corner_radius" in box:
			radii.append(int(box.get("corner_radius")))
		elif box is StyleBoxFlat:
			radii.append(int((box as StyleBoxFlat).corner_radius_top_left))
	if radii.size() > 1:
		for i in range(1, radii.size()):
			_assert(radii[i] == radii[0], "%s styleboxes share one corner radius" % where)


func _stylebox_is_square_underbox(box: StyleBox) -> bool:
	if box == null or box is StyleBoxEmpty:
		return false
	if box.has_method("is_brass") and bool(box.call("is_brass")):
		return int(box.get("corner_radius")) <= 0
	if box is StyleBoxFlat:
		var flat := box as StyleBoxFlat
		return int(flat.corner_radius_top_left) <= 0 or int(flat.corner_radius_top_right) <= 0 or int(flat.corner_radius_bottom_left) <= 0 or int(flat.corner_radius_bottom_right) <= 0
	return true


func _panel_paints_fill(panel: Control) -> bool:
	if panel == null:
		return true
	var box: StyleBox = panel.get_theme_stylebox("panel")
	if box == null or box is StyleBoxEmpty:
		return false
	if box is StyleBoxFlat:
		var flat := box as StyleBoxFlat
		return flat.draw_center and flat.bg_color.a > 0.02
	if "bg_color" in box:
		return Color(box.bg_color).a > 0.02
	return true


func _label_paints_plate(label: Label) -> bool:
	if label == null:
		return true
	for child in label.get_children():
		if child is Panel or child is PanelContainer or child is ColorRect:
			return true
	for name in ["normal", "focus"]:
		if _stylebox_paints_plate(label.get_theme_stylebox(name)):
			return true
	return false


func _stylebox_paints_plate(box: StyleBox) -> bool:
	if box == null or box is StyleBoxEmpty:
		return false
	if box is StyleBoxFlat:
		var flat := box as StyleBoxFlat
		if flat.bg_color.a > 0.02:
			return true
		var border_w: int = flat.border_width_left + flat.border_width_top + flat.border_width_right + flat.border_width_bottom
		return border_w > 0 and flat.border_color.a > 0.02
	if "bg_color" in box and Color(box.bg_color).a > 0.02:
		return true
	return true


func _stylebox_is_rounded_plate(box: StyleBox) -> bool:
	if box == null:
		return false
	if box.has_method("is_brass") and bool(box.call("is_brass")):
		return int(box.get("corner_radius")) >= 6
	if box is StyleBoxFlat:
		var flat := box as StyleBoxFlat
		return int(flat.corner_radius_top_left) >= 6 and int(flat.corner_radius_top_right) >= 6 and int(flat.corner_radius_bottom_left) >= 6 and int(flat.corner_radius_bottom_right) >= 6
	return false


func _color_is_gold(color: Color) -> bool:
	return color.r > 0.75 and color.g > 0.55 and color.b < 0.55


func _color_is_dirt_ink(color: Color) -> bool:
	return color.r < 0.22 and color.g < 0.18 and color.b < 0.16


func _color_is_light_ink(color: Color) -> bool:
	return color.get_luminance() >= 0.7


func _color_is_dark_panel(color: Color) -> bool:
	return color.get_luminance() < 0.25


func _color_is_muted(color: Color) -> bool:
	return color.b >= 0.5 and color.r <= 0.85


func _looks_like_available_brass(fill: Color) -> bool:
	return fill.is_equal_approx(Color("3F3126")) or fill.is_equal_approx(Color("8A4E24"))


func _assert_gold_hover_outline(button: Button, where: String) -> void:
	var box: StyleBox = button.get_theme_stylebox("hover")
	_assert(box != null, "%s has a hover stylebox" % where)
	if box == null or not ("border_color" in box) or not ("border_width" in box):
		return
	_assert(_color_is_gold(box.border_color), "%s hover uses the gold outline" % where)
	_assert(int(box.border_width) >= 4, "%s hover outline matches selected tool width" % where)


func _assert_hud_button_shadow(button: Button, where: String) -> void:
	for name in ["normal", "hover"]:
		var box: StyleBox = button.get_theme_stylebox(name)
		_assert(box != null and "shadow_size" in box, "%s %s still casts a drop" % [where, name])
		if box == null or not ("shadow_size" in box):
			continue
		var size: int = int(box.shadow_size)
		var offset: Vector2 = box.shadow_offset if "shadow_offset" in box else Vector2.ZERO
		var alpha: float = box.shadow_color.a if "shadow_color" in box else 1.0
		_assert(size > 0 and size <= 4, "%s %s shadow is lighter than the old 8–12px drop" % [where, name])
		_assert(offset.y <= 1.5, "%s %s shadow offset is shorter than the old 2–3px drop" % [where, name])
		_assert(alpha <= 0.40, "%s %s shadow alpha is softer than the old 0.55 drop" % [where, name])


func _assert(ok: bool, label: String) -> void:
	if ok:
		_passed += 1
		print("PASS  %s" % label)
	else:
		_failed += 1
		print("FAIL  %s" % label)
