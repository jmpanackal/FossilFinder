class_name DigHUD
extends CanvasLayer

signal tool_selected(tool: int)
signal end_shift

const Ui := preload("res://ui_style.gd")
const ClockFace := preload("res://clock_face.gd")
const ToolIcon := preload("res://tool_icon.gd")
const ShopIcon := preload("res://shop_icon.gd")
const FindChipScript := preload("res://find_chip.gd")
const RewardRibbonScript := preload("res://reward_ribbon.gd")
const FameBadgeScript := preload("res://fame_badge.gd")

const CLOCK_SIZE := 72.0
const CLOCK_TIME_SIZE := 32
const CLOCK_GAP := 12.0
const RAIL_PAD := 8.0
const DOCK_W := 120.0
const TOOL_CARD_H := 110.0
const TOOL_CARD_MIN_H := 70.0
const TOOL_GRID_GAP := 8.0
const LOCKED_ALPHA := 0.38
const TOOL_CARD_INSET := 6.0
const TOOL_CARD_INSET_TIGHT := 3.0
const TOOL_STACK_GAP := 8.0
const TOOL_STACK_GAP_TIGHT := 2.0
const RAIL_LABEL_GAP := 10.0
const SECTION_PAD := 10.0
const SECTION_TITLE_TOP := 14.0
const TOOL_ROW := Vector2(DOCK_W, TOOL_CARD_H)
const CHIP_COPY_W := 100.0
const HEADER_BTN_H := 36.0
const RailOrnament := preload("res://rail_ornament.gd")
const TOOLS_TITLE := "Tools"
const FINDS_TITLE := "Finds"
const CHIP_COMFORT_MIN := 232.0
const CHIP_COMFORT_MAX := 300.0
const CHIP_MIN_W := 56.0
## Cards sit inside the Finds frame, clear of its border.
const FIND_INSET := 10.0
const CHIP_GAP := 8.0
## Finds rail: every card is the same height; extras fold into a summary row.
const RAIL_CARD_H := 56.0
const RAIL_CARD_GAP := 6.0
const SUMMARY_H := 30.0
const FAME_FOOT_H := 44.0
## At this many finds the tray switches to condensed cards (hover for details).
const CONDENSE_AT := 5
const WALLET_MONEY_SAMPLE := "$8888888"
const WALLET_RATE_SAMPLE := "$8888.88/s"
const WALLET_RIGHT_PAD := 20.0

var _clock
var _wallet: PanelContainer
var _money: Label
var _pouch: Control
var _income: Label
var _income_row: HBoxContainer
var _income_mark: Control
var _money_flash: float = 0.0
var _pouch_pop: float = 0.0
var _shown_money: int = -1
var _clock_time: Label
var _clock_caption: Label
var _menu_btn: Button
var _end_btn: Button
var _header_bar: HBoxContainer
var _tool_rail: GridContainer
var _tools_label: Label
var _finds_label: Label
var _tools_frame: Panel
var _finds_frame: Panel
var _tool_roles: Array[Label] = []
var _tool_buttons: Array[Button] = []
var _tool_slots: Array[Control] = []
var _slot_tools: Array[int] = []
var _hovered_tool: int = -1
var _headline: String = ""
var _find_box: VBoxContainer
var _chips: Array = []
var _tool_colors := [
	Color("E4B75A"),
	Color("D96A4A"),
	Color("7EC8E3"),
	Color("E4B75A"),
]
var _tool_flash: PackedFloat32Array = PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
var _clock_flash: float = 0.0
var _equipped_tool: int = Tuning.TOOL_HANDS
## refresh() runs every frame. Restyling buttons and re-laying out the rail each
## frame cost several ms, so both only happen when their inputs change.
var _tool_style_key: String = ""
var _layout_key: String = ""
var _cards_key: String = ""
var _ribbon: Control
var _fame_label: Control
var _detail_chip: Control
var _detail_for: Control
var _finds_summary: Panel
var _summary_tip: Label
var _summary_lines: String = ""
var _finds_box_h: float = 0.0
var _tool_info: Panel
var _tool_info_name: Label
var _tool_info_role: Label
var _tool_info_stats: VBoxContainer
var _tool_info_hint: Label
var _tool_info_key: String = ""


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	## Tools: a 2x2 grid of square cards, then a panel about the tool in hand.
	_tool_rail = GridContainer.new()
	_tool_rail.name = "ToolRail"
	_tool_rail.columns = 2
	_tool_rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tool_rail.add_theme_constant_override("h_separation", int(TOOL_GRID_GAP))
	_tool_rail.add_theme_constant_override("v_separation", int(TOOL_GRID_GAP))
	root.add_child(_tool_rail)
	_add_tool_slot(_tool_rail, Tuning.TOOL_HANDS)
	_add_tool_slot(_tool_rail, Tuning.TOOL_SHOVEL)
	_add_tool_slot(_tool_rail, Tuning.TOOL_PICKAXE)
	_add_tool_slot(_tool_rail, Tuning.TOOL_BRUSH)

	_tools_label = _make_rail_title("ToolsLabel")
	root.add_child(_tools_label)
	_build_tool_info(root)

	_clock = Control.new()
	_clock.set_script(ClockFace)
	_clock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clock.custom_minimum_size = Vector2(CLOCK_SIZE, CLOCK_SIZE)
	_clock.size = Vector2(CLOCK_SIZE, CLOCK_SIZE)
	root.add_child(_clock)

	_clock_time = Label.new()
	_clock_time.name = "ClockTime"
	_clock_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_clock_time.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Ui.apply_label(_clock_time, CLOCK_TIME_SIZE, Ui.PAPER_DEEP)
	root.add_child(_clock_time)

	_clock_caption = Label.new()
	_clock_caption.name = "ClockCaption"
	_clock_caption.text = "Shift remaining"
	_clock_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_clock_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Ui.apply_caption(_clock_caption)
	root.add_child(_clock_caption)

	_bind_shared_wallet()

	_tools_frame = _make_section_frame("ToolsFrame")
	root.add_child(_tools_frame)
	_finds_frame = _make_section_frame("FindsFrame")
	root.add_child(_finds_frame)

	_finds_label = _make_rail_title("FindsLabel")
	root.add_child(_finds_label)

	## Museum fame medal: explains why late bones pay more.
	_fame_label = FameBadgeScript.new()
	_fame_label.name = "FameBadge"
	_fame_label.visible = false
	root.add_child(_fame_label)

	_find_box = VBoxContainer.new()
	_find_box.name = "FindTray"
	_find_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_find_box.clip_contents = true
	_find_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	_find_box.add_theme_constant_override("separation", int(RAIL_CARD_GAP))
	_find_box.visible = false
	root.add_child(_find_box)

	_ribbon = RewardRibbonScript.new()
	_ribbon.name = "RewardRibbon"
	root.add_child(_ribbon)

	_set_money_text(false)
	_highlight_tool(Tuning.TOOL_HANDS)
	_layout_chrome()


func set_header_actions_visible(_on: bool) -> void:
	pass


func refresh(time_left: float, time_max: float, tool: int, digging: bool, show_find: bool = false, _stars: int = 0, _grade: String = "", _clean: float = 0.0, _value: int = 0) -> void:
	visible = digging
	_equipped_tool = tool
	if _clock.has_method("set_time"):
		_clock.set_time(time_left, time_max)
	_set_clock_copy(time_left)
	_set_money_text(false)
	_highlight_tool(tool)
	_refresh_tool_info()
	_apply_tool_flashes()
	_find_box.visible = show_find or not _chips.is_empty()
	_layout_if_changed()
	_refresh_fame()


func _refresh_fame() -> void:
	if _fame_label == null or _finds_frame == null:
		return
	var mult: float = GameState.fame_mult() if GameState.has_method("fame_mult") else 1.0
	_fame_label.call("set_mult", mult)
	## Centered at the foot of the Finds rail, under the cards.
	var foot_top: float = _finds_frame.position.y + _finds_frame.size.y - SECTION_PAD - FAME_FOOT_H
	var at := Vector2(_finds_frame.position.x + (_finds_frame.size.x - _fame_label.size.x) * 0.5, foot_top + (FAME_FOOT_H - _fame_label.size.y) * 0.5).round()
	if _fame_label.position != at:
		_fame_label.position = at


func _current_layout_key() -> String:
	var nav := Rect2()
	if Settings != null and Settings.has_method("nav_rect"):
		nav = Settings.nav_rect()
	var wallet_w: float = _wallet.size.x if _wallet != null else 0.0
	var clock_len: int = _clock_time.text.length() if _clock_time != null else 0
	return "%s|%s|%s|%s|%d|%s|%s|%d" % [
		Vector2(Tuning.view_w, Tuning.view_h),
		Tuning.pit_grid_rect(),
		Tuning.chunk_front,
		nav,
		clock_len,
		wallet_w,
		_find_box.visible if _find_box != null else false,
		_visible_tool_count(),
	]


func _layout_if_changed() -> void:
	var key: String = _current_layout_key()
	if key == _layout_key:
		return
	_layout_key = key
	_layout_chrome()


func set_find_cards(cards: Array) -> void:
	var shown: Array = []
	for raw in cards:
		if raw is Dictionary and _card_is_uncovered(raw):
			shown.append(raw)
	## Tray order = discovery order, matching the numbers on the bones.
	shown.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("number", a.get("index", 0))) < int(b.get("number", b.get("index", 0))))
	_layout_if_changed()
	var key: String = _cards_signature(shown) + "|%d" % int(_finds_box_h)
	if key == _cards_key:
		return
	_cards_key = key
	## The rail fits a fixed number of full cards. When there are more finds,
	## the oldest collected ones fold into one summary row at the bottom;
	## bones you are still digging or brushing always keep their cards.
	## Use the laid-out rail height: the VBox itself grows to fit its cards.
	var box_h: float = _finds_box_h if _finds_box_h > 1.0 else 300.0
	var capacity: int = maxi(1, int(floor((box_h + RAIL_CARD_GAP) / (RAIL_CARD_H + RAIL_CARD_GAP))))
	var folded: Array = []
	if shown.size() > capacity:
		var room: int = maxi(1, int(floor((box_h - SUMMARY_H) / (RAIL_CARD_H + RAIL_CARD_GAP))))
		var need: int = shown.size() - room
		for card in shown:
			if folded.size() >= need:
				break
			if bool(card.get("extracted", false)) or str(card.get("status", "")) == "bagged":
				folded.append(card)
		for card in folded:
			shown.erase(card)
	while _chips.size() > shown.size():
		var extra: Node = _chips.pop_back()
		if extra != null:
			extra.queue_free()
	while _chips.size() < shown.size():
		var chip: Control = FindChipScript.new() as Control
		_find_box.add_child(chip)
		_chips.append(chip)
	var tray_w: float = maxf(120.0, _find_box.size.x)
	for i in shown.size():
		var card: Dictionary = shown[i]
		if not card.has("index"):
			card["index"] = i
		var chip: Control = _chips[i] as Control
		if chip != null and chip.has_method("apply_card"):
			chip.call("apply_card", card)
		if chip != null and chip.has_method("fit_rail"):
			chip.call("fit_rail", tray_w, RAIL_CARD_H)
	_update_finds_summary(folded, tray_w)
	_apply_headline_to_chips()
	_find_box.visible = not shown.is_empty() or not folded.is_empty()
	_layout_key = ""
	_layout_if_changed()
	if _find_box != null:
		_find_box.notification(Container.NOTIFICATION_SORT_CHILDREN)


## "+4 collected · $1,240" row for folded finds; hover lists them.
func _update_finds_summary(folded: Array, width: float) -> void:
	if folded.is_empty():
		if _finds_summary != null:
			_finds_summary.visible = false
		return
	if _finds_summary == null:
		_finds_summary = Panel.new()
		_finds_summary.name = "FindsSummary"
		_finds_summary.mouse_filter = Control.MOUSE_FILTER_PASS
		_finds_summary.add_theme_stylebox_override("panel", Ui.tooltip_box())
		var label := Label.new()
		label.name = "SummaryLabel"
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		Ui.apply_label(label, 13, Ui.INK)
		_finds_summary.add_child(label)
		_finds_summary.mouse_entered.connect(_show_summary_tip)
		_finds_summary.mouse_exited.connect(func() -> void:
			if _summary_tip != null:
				_summary_tip.visible = false)
		_find_box.add_child(_finds_summary)
	var total: int = 0
	var lines: PackedStringArray = []
	for raw in folded:
		var card: Dictionary = raw
		total += int(card.get("value", 0))
		lines.append("#%d %s  %s  %s" % [int(card.get("number", 0)), str(card.get("name", "Bone")), "★".repeat(int(card.get("stars", 0))), Ui.money_text(int(card.get("value", 0)))])
	_summary_lines = "\n".join(lines)
	var label: Label = _finds_summary.get_node("SummaryLabel") as Label
	label.text = "+%d collected · %s" % [folded.size(), Ui.money_text(total)]
	_finds_summary.custom_minimum_size = Vector2(width, SUMMARY_H)
	_finds_summary.visible = true
	_find_box.move_child(_finds_summary, _find_box.get_child_count() - 1)


func _show_summary_tip() -> void:
	if _summary_tip == null:
		_summary_tip = Label.new()
		_summary_tip.name = "SummaryTip"
		_summary_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_summary_tip.z_index = 20
		_summary_tip.add_theme_stylebox_override("normal", Ui.tooltip_box())
		Ui.apply_label(_summary_tip, 13, Ui.INK)
		_find_box.get_parent().add_child(_summary_tip)
	_summary_tip.text = _summary_lines
	_summary_tip.size = _summary_tip.get_combined_minimum_size()
	var r := Rect2(_finds_summary.global_position, _finds_summary.size)
	_summary_tip.position = Vector2(r.position.x - _summary_tip.size.x - 8.0, clampf(r.end.y - _summary_tip.size.y, Tuning.hud_h, Tuning.view_h - _summary_tip.size.y - 8.0)).round()
	_summary_tip.visible = true


func _cards_signature(shown: Array) -> String:
	var parts: PackedStringArray = []
	parts.append(str(Tuning.pit_grid_size()))
	for card in shown:
		var c: Dictionary = card
		var left: float = float(c.get("crumble_in", INF))
		parts.append("%s/%s/%s/%s/%s/%s/%s/%s/%s/%s/%s" % [
			c.get("index", -1), c.get("name", ""), c.get("status", ""), c.get("stars", 0),
			c.get("dirt", ""), c.get("value", 0), c.get("fate", ""), c.get("progress", ""),
			c.get("exposed", 0), -1 if left == INF else int(ceil(left)), "%s:%s:%s" % [c.get("cast", false), c.get("crumbled", 0), c.get("number", 0)],
		])
	return ";".join(parts)


func _chip_width_for_count(n: int, tray_w: float) -> float:
	if n <= 0:
		return CHIP_COMFORT_MIN
	## Always one row: the tray only has room for one, and a wrapped second
	## row would be clipped. Many finds just get narrower (condensed) cards.
	var each: float = floorf((tray_w - CHIP_GAP * float(maxi(n - 1, 0))) / float(n))
	if n <= 3:
		return minf(clampf(each, CHIP_COMFORT_MIN, CHIP_COMFORT_MAX), each)
	return maxf(CHIP_MIN_W, each)


func find_chip_catch_pos(index: int) -> Vector2:
	var chip: Control = _chip_for_find(index)
	if chip != null and chip.has_method("catch_pos"):
		return chip.call("catch_pos")
	var rail: Rect2 = finds_rail_rect()
	return Vector2(rail.get_center().x, rail.position.y + 60.0)


func catch_find(index: int) -> void:
	var chip: Control = _chip_for_find(index)
	if chip != null and chip.has_method("light_up"):
		chip.call("light_up")


## Celebrate a find on the Finds tray border, centered over its chip.
func celebrate(index: int, title: String, subtitle: String = "", stars: int = 0, tier: int = 1, hold: float = 0.0, subject: String = "", piece_id: String = "") -> void:
	if _ribbon == null:
		return
	if not _ribbon.get("anchor_for").is_valid():
		_ribbon.set("anchor_for", ribbon_anchor)
	var chip: Control = _chip_for_find(index) if index >= 0 else null
	if chip != null and chip.has_method("light_up"):
		chip.call("light_up")
	_ribbon.call("show_reward", title, subtitle, stars, tier, ribbon_anchor(index), index, hold, subject, piece_id)


## True while a ribbon is on screen (tips wait for it to clear).
func ribbon_busy() -> bool:
	return _ribbon != null and bool(_ribbon.call("is_showing"))


## Where a ribbon for this find should sit: top edge of the tray, over its card.
func ribbon_anchor(index: int) -> Vector2:
	if _find_box != null:
		_find_box.notification(Container.NOTIFICATION_SORT_CHILDREN)
	## Ribbons own the band under the pit, centered on it.
	return Vector2(Tuning.pit_grid_rect().get_center().x, rails_bottom() + 16.0)


func _on_chip_hover(chip: Control) -> void:
	## Condensed card hovered: show the full card just above it.
	if chip == null or not bool(chip.get("_condensed")):
		return
	if _detail_chip == null:
		_detail_chip = FindChipScript.new()
		_detail_chip.name = "FindDetail"
		_detail_chip.z_index = 20
		_find_box.get_parent().add_child(_detail_chip)
	_detail_for = chip
	_detail_chip.call("apply_card", chip.get("_card"))
	_detail_chip.call("fit_tray", 300.0, false, false)
	var x: float = chip.global_position.x + chip.size.x * 0.5 - 150.0
	x = clampf(x, 8.0, Tuning.view_w - 308.0)
	_detail_chip.position = Vector2(x, chip.global_position.y - _detail_chip.size.y - 6.0)
	_detail_chip.visible = true


func _on_chip_unhover(chip: Control) -> void:
	if _detail_chip != null and _detail_for == chip:
		_detail_chip.visible = false
		_detail_for = null


func ribbon() -> Control:
	return _ribbon


func set_bone_warning(_on: bool) -> void:
	pass


func _set_clock_copy(time_left: float) -> void:
	if _clock_time == null:
		return
	var secs: int = maxi(0, int(ceil(time_left)))
	_clock_time.text = "%d:%02d" % [secs / 60, secs % 60]
	_clock_time.add_theme_color_override("font_color", Ui.PAPER_DEEP)
	if _clock_caption != null:
		_clock_caption.text = "Shift remaining"
		_clock_caption.add_theme_color_override("font_color", Color("7A1E1E") if time_left <= 10.0 else Ui.PAPER_DEEP)


func _card_is_uncovered(card: Dictionary) -> bool:
	if bool(card.get("extracted", false)) or bool(card.get("fully_exposed", false)):
		return true
	var status: String = str(card.get("status", ""))
	return status == "brush" or status == "bagged" or status == "uncovering" or int(card.get("exposed", 0)) > 0


func _chip_for_find(index: int) -> Control:
	for raw in _chips:
		var chip: Control = raw as Control
		if chip != null and int(chip.get("_index")) == index:
			return chip
	return null


func set_find_headline(text: String) -> void:
	_headline = text
	_apply_headline_to_chips()


func _apply_headline_to_chips() -> void:
	for raw in _chips:
		var chip: Control = raw as Control
		if chip != null and chip.has_method("set_extra"):
			chip.call("set_extra", "")


func flash_upgraded_tools(tools: Array) -> void:
	for raw in tools:
		var tool: int = int(raw)
		if tool >= 0 and tool < _tool_flash.size():
			_tool_flash[tool] = 1.25


func flash_clock() -> void:
	_clock_flash = 1.2


func _process(delta: float) -> void:
	for i in _tool_flash.size():
		if _tool_flash[i] > 0.0:
			_tool_flash[i] = maxf(0.0, _tool_flash[i] - delta * 1.15)
	if _clock_flash > 0.0:
		_clock_flash = maxf(0.0, _clock_flash - delta * 1.6)
		var pulse: float = 0.4 + 0.6 * absf(sin(_clock_flash * TAU * 2.0))
		_clock.modulate = Color("FFE08A").lerp(Color.WHITE, 1.0 - _clock_flash * pulse)
	elif _clock.modulate != Color.WHITE:
		_clock.modulate = Color.WHITE


func money_catch_pos() -> Vector2:
	if Settings != null and Settings.has_method("money_catch_pos"):
		return Settings.money_catch_pos()
	return Vector2(40, 40)


func catch_loot() -> void:
	if Settings != null and Settings.has_method("catch_loot"):
		Settings.catch_loot()


func _bind_shared_wallet() -> void:
	if Settings == null:
		return
	_wallet = Settings.get("_wallet") as PanelContainer
	_money = Settings.get("_money") as Label
	_income = Settings.get("_income") as Label
	_income_row = Settings.get("_income_row") as HBoxContainer
	_income_mark = Settings.get("_income_mark") as Control
	_pouch = Settings.get("_pouch") as Control


func _set_money_text(flash: bool) -> void:
	if Settings != null and Settings.has_method("refresh_wallet"):
		Settings.refresh_wallet(flash)


func _section_frame_width() -> float:
	var pit := Tuning.pit_grid_rect()
	var hole_left: float = pit.position.x - Tuning.chunk_pad
	var left_w: float = hole_left - RAIL_PAD - 10.0
	return minf(Tuning.hud_rail_w() - RAIL_PAD, maxf(left_w, 1.0))


func _section_inner(frame: Rect2, title: Label = null) -> Rect2:
	var title_h: float = _section_title_h(maxf(frame.size.x - SECTION_PAD * 2.0, 1.0))
	if title != null:
		title_h = maxf(title.size.y, float(title.get_theme_font_size("font_size")) + 2.0)
	var top: float = frame.position.y + SECTION_TITLE_TOP + title_h + RAIL_LABEL_GAP
	var left: float = frame.position.x + SECTION_PAD
	var width: float = maxf(frame.size.x - SECTION_PAD * 2.0, 1.0)
	var height: float = maxf(frame.end.y - SECTION_PAD - top, 1.0)
	return Rect2(Vector2(left, top), Vector2(width, height))


func _section_title_h(copy_w: float) -> float:
	var h: float = 24.0
	if _tools_label != null:
		Ui.apply_field_section(_tools_label, TOOLS_TITLE, copy_w)
		_paint_rail_title(_tools_label)
		h = maxf(h, maxf(_tools_label.get_combined_minimum_size().y, float(_tools_label.get_theme_font_size("font_size")) + 2.0))
	if _finds_label != null:
		Ui.apply_field_section(_finds_label, FINDS_TITLE, copy_w)
		_paint_rail_title(_finds_label)
		h = maxf(h, maxf(_finds_label.get_combined_minimum_size().y, float(_finds_label.get_theme_font_size("font_size")) + 2.0))
	return h


func _tool_card_size() -> Vector2:
	var frame_w: float = _section_frame_width()
	var pit := Tuning.pit_grid_rect()
	var inner := _section_inner(Rect2(Vector2(RAIL_PAD, pit.position.y), Vector2(frame_w, rails_bottom() - pit.position.y)))
	return _tool_card_size_in(inner)


func _tool_card_size_in(inner: Rect2) -> Vector2:
	## Square cards, two per row.
	var side: float = floorf((inner.size.x - TOOL_GRID_GAP) * 0.5)
	return Vector2(maxf(side, 40.0), maxf(side, 40.0))


func _visible_tool_count() -> int:
	var n: int = 0
	for raw in _tool_slots:
		var slot: Control = raw as Control
		if slot != null and slot.visible:
			n += 1
	return n if n > 0 else 1


func _tool_icon_px(card_h: float) -> float:
	if card_h + 0.5 < TOOL_ROW.y:
		return 28.0
	return Ui.RAIL_TOOL_ICON


func _tool_stack_gap(card_h: float) -> float:
	if card_h + 0.5 < TOOL_ROW.y:
		return TOOL_STACK_GAP_TIGHT
	return TOOL_STACK_GAP


func _tool_card_inset(card_h: float) -> float:
	if card_h + 0.5 < TOOL_ROW.y:
		return TOOL_CARD_INSET_TIGHT
	return TOOL_CARD_INSET


func _make_section_frame(node_name: String) -> Panel:
	var frame := Panel.new()
	frame.name = node_name
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_theme_stylebox_override("panel", Ui.field_frame_box())
	var ornament: Control = RailOrnament.new()
	ornament.name = "Ornament"
	frame.add_child(ornament)
	return frame


func _place_section_frame(frame: Panel, rect: Rect2) -> void:
	if frame == null:
		return
	frame.anchor_left = 0.0
	frame.anchor_top = 0.0
	frame.anchor_right = 0.0
	frame.anchor_bottom = 0.0
	frame.position = rect.position
	frame.size = rect.size
	var ornament: Node = frame.get_node_or_null("Ornament")
	if ornament != null and ornament.has_method("set_header_y"):
		ornament.call("set_header_y", SECTION_TITLE_TOP + _section_title_h(maxf(rect.size.x - SECTION_PAD * 2.0, 1.0)) + 3.0)
	var parent: Node = frame.get_parent()
	if parent != null:
		parent.move_child(frame, 0)


func _make_rail_title(node_name: String) -> Label:
	var label := Label.new()
	label.name = node_name
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.focus_mode = Control.FOCUS_NONE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	Ui.apply_text_only(label)
	return label


func _layout_section_title(label: Label, text: String, frame: Rect2, title_top: float = SECTION_TITLE_TOP) -> void:
	if label == null:
		return
	var copy_w: float = maxf(frame.size.x - SECTION_PAD * 2.0, 1.0)
	Ui.apply_field_section(label, text, copy_w)
	_paint_rail_title(label)
	var label_h: float = maxf(label.get_combined_minimum_size().y, float(label.get_theme_font_size("font_size")) + 2.0)
	_place_rail_title(label, Vector2(frame.position.x + SECTION_PAD, frame.position.y + title_top), Vector2(copy_w, label_h))


func _paint_rail_title(label: Label) -> void:
	if label == null:
		return
	label.add_theme_color_override("font_color", Ui.INK)


func _place_rail_title(label: Label, pos: Vector2, size: Vector2) -> void:
	if label == null:
		return
	label.anchor_left = 0.0
	label.anchor_top = 0.0
	label.anchor_right = 0.0
	label.anchor_bottom = 0.0
	var min_sz: Vector2 = label.get_combined_minimum_size()
	var w: float = maxf(min_sz.x, 1.0)
	var h: float = maxf(min_sz.y, float(label.get_theme_font_size("font_size")))
	label.size = Vector2(w, h)
	label.position = Vector2(pos.x + (size.x - w) * 0.5, pos.y)


func _apply_tool_card_size(slot: Control, button: Button, card: Vector2) -> void:
	if slot != null:
		slot.custom_minimum_size = card
		slot.size = card
		slot.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	if button == null:
		return
	button.set_anchors_preset(Control.PRESET_TOP_LEFT)
	button.position = Vector2.ZERO
	button.custom_minimum_size = card
	button.size = card
	var stack: VBoxContainer = button.get_node_or_null("ToolStack") as VBoxContainer
	if stack != null:
		var inset: float = _tool_card_inset(card.y)
		var inner := Vector2(maxf(card.x - inset * 2.0, 1.0), maxf(card.y - inset * 2.0, 1.0))
		stack.set_anchors_preset(Control.PRESET_TOP_LEFT)
		stack.position = Vector2(inset, inset)
		stack.size = inner
		stack.alignment = BoxContainer.ALIGNMENT_CENTER
		stack.add_theme_constant_override("separation", int(_tool_stack_gap(card.y)) + 2)
		var icon: Control = stack.get_node_or_null("ToolIcon") as Control
		if icon != null:
			Ui.apply_rail_tool_icon(icon, _tool_icon_px(card.y))
		var name: Label = stack.get_node_or_null("ToolName") as Label
		if name != null:
			var name_size: int = 11 if card.y + 0.5 < TOOL_ROW.y else Ui.META_SIZE
			_fit_rail_label(name, name.text, Ui.INK, name_size, inner.x)
			name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var role: Label = stack.get_node_or_null("ToolRole") as Label
		if role != null:
			_fit_tool_role(role, inner.x, card.y)
			var used: float = 0.0
			if icon != null:
				used += icon.custom_minimum_size.y
			if name != null:
				used += name.get_combined_minimum_size().y
			used += float(stack.get_theme_constant("separation")) * 2.0
			var role_room: float = maxf(inner.y - used, 8.0)
			role.custom_minimum_size.y = minf(role.custom_minimum_size.y, role_room)
			role.size.y = role.custom_minimum_size.y
		stack.notification(Container.NOTIFICATION_SORT_CHILDREN)
	_place_tool_key(button, card)


func _add_tool_slot(parent: Container, tool: int) -> void:
	var card: Vector2 = _tool_card_size()
	var slot := Control.new()
	slot.custom_minimum_size = card
	slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	parent.add_child(slot)
	_tool_slots.append(slot)
	_slot_tools.append(tool)

	var button := Button.new()
	button.set_anchors_preset(Control.PRESET_TOP_LEFT)
	button.position = Vector2.ZERO
	button.custom_minimum_size = card
	button.size = card
	button.text = ""
	button.clip_text = true
	button.clip_contents = false
	button.focus_mode = Control.FOCUS_NONE
	Ui.apply_hud_button(button)
	button.pressed.connect(_on_tool_pressed.bind(tool))
	button.mouse_entered.connect(_on_tool_hover.bind(tool))
	button.mouse_exited.connect(_on_tool_unhover.bind(tool))
	slot.add_child(button)

	var stack := VBoxContainer.new()
	stack.name = "ToolStack"
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.alignment = BoxContainer.ALIGNMENT_BEGIN
	stack.add_theme_constant_override("separation", int(TOOL_STACK_GAP))
	stack.set_anchors_preset(Control.PRESET_TOP_LEFT)
	var inset: float = _tool_card_inset(card.y)
	stack.position = Vector2(inset, inset)
	stack.size = Vector2(maxf(card.x - inset * 2.0, 1.0), maxf(card.y - inset * 2.0, 1.0))
	button.add_child(stack)

	var icon := Control.new()
	icon.name = "ToolIcon"
	icon.set_script(ToolIcon)
	Ui.apply_rail_tool_icon(icon, _tool_icon_px(card.y))
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(icon)
	if icon.has_method("setup"):
		icon.setup(tool, _tool_colors[tool])

	var name := Label.new()
	name.name = "ToolName"
	name.text = GameState.tool_display_name(tool)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_fit_rail_label(name, name.text, Ui.INK, Ui.META_SIZE, stack.size.x)
	stack.add_child(name)

	var role := Label.new()
	role.name = "ToolRole"
	role.text = GameState.tool_role_line(tool)
	role.visible = true
	role.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	role.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	role.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	role.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	role.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fit_tool_role(role, stack.size.x, card.y)
	stack.add_child(role)
	_tool_roles.append(role)

	var key := Label.new()
	key.name = "ToolKey"
	key.text = Tuning.hotkey_for_tool(tool)
	key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	key.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	key.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	button.add_child(key)

	_tool_buttons.append(button)
	_apply_tool_card_size(slot, button, card)


func _fit_tool_role(role: Label, max_w: float, card_h: float = TOOL_ROW.y) -> void:
	if role == null:
		return
	var tight: bool = card_h + 0.5 < TOOL_ROW.y
	var size: int = 10 if tight else 11
	Ui.apply_copy(role, role.text, size, Ui.MUTED, max_w, true)
	role.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	role.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	role.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	role.max_lines_visible = 2
	role.clip_text = false
	role.add_theme_constant_override("line_spacing", -4 if tight else -3)
	if tight:
		role.custom_minimum_size.y = minf(role.custom_minimum_size.y, 16.0)
		role.size.y = role.custom_minimum_size.y


func _fit_rail_label(label: Label, text: String, color: Color, preferred: int, max_w: float) -> void:
	Ui.apply_copy(label, text, preferred, color, max_w)


func _place_tool_key(button: Button, card: Vector2) -> void:
	if button == null:
		return
	var key: Label = button.get_node_or_null("ToolKey") as Label
	if key == null:
		return
	_fit_rail_label(key, key.text, Ui.MUTED, Ui.META_SIZE, 16.0)
	key.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	key.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	var w: float = maxf(key.get_combined_minimum_size().x, key.custom_minimum_size.x)
	var h: float = maxf(key.get_combined_minimum_size().y, float(Ui.META_SIZE) + 2.0)
	key.size = Vector2(maxf(w, 1.0), maxf(h, 1.0))
	key.position = Vector2(card.x - key.size.x - 6.0, 4.0)


func _build_tool_info(root: Control) -> void:
	_tool_info = Panel.new()
	_tool_info.name = "ToolInfo"
	_tool_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Ui.apply_icon_well(_tool_info, Color("241810"))
	root.add_child(_tool_info)
	var box := VBoxContainer.new()
	box.name = "ToolInfoBox"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 10
	box.offset_right = -10
	box.offset_top = 8
	box.offset_bottom = -8
	box.add_theme_constant_override("separation", 4)
	_tool_info.add_child(box)
	_tool_info_name = Label.new()
	_tool_info_name.name = "ToolInfoName"
	Ui.apply_label(_tool_info_name, 17, Ui.GOLD)
	box.add_child(_tool_info_name)
	_tool_info_role = Label.new()
	_tool_info_role.name = "ToolInfoRole"
	_tool_info_role.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	Ui.apply_label(_tool_info_role, 13, Ui.INK)
	box.add_child(_tool_info_role)
	var rule := ColorRect.new()
	rule.color = Color(Ui.GOLD, 0.25)
	rule.custom_minimum_size = Vector2(0, 1)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(rule)
	_tool_info_stats = VBoxContainer.new()
	_tool_info_stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tool_info_stats.add_theme_constant_override("separation", 2)
	box.add_child(_tool_info_stats)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(spacer)
	_tool_info_hint = Label.new()
	_tool_info_hint.name = "ToolInfoHint"
	_tool_info_hint.text = "Keys 1-4 switch tools"
	_tool_info_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Ui.apply_label(_tool_info_hint, 11, Ui.MUTED)
	box.add_child(_tool_info_hint)


## The panel describes the hovered tool, else the one in hand. Rebuilt only
## when the tool or upgrade levels change.
func _refresh_tool_info(force: bool = false) -> void:
	if _tool_info == null:
		return
	var tool: int = _hovered_tool if _hovered_tool >= 0 else _equipped_tool
	var owned: bool = GameState.owns_tool(tool)
	var key: String = "%d|%s|%d" % [tool, owned, GameState.levels.hash()]
	if key == _tool_info_key and not force:
		return
	_tool_info_key = key
	_tool_info_name.text = GameState.tool_display_name(tool)
	_tool_info_role.text = GameState.tool_role_line(tool) if owned else "Unlock it in Upgrades."
	for child in _tool_info_stats.get_children():
		child.queue_free()
	if not owned:
		return
	var shown: int = 0
	for raw in GameState.shop_hero_stats(GameState.tool_display_name(tool)):
		var stat: Dictionary = raw
		if str(stat["value"]) == "Locked" or shown >= 4:
			continue
		shown += 1
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var label := Label.new()
		label.text = str(stat["label"])
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.clip_text = true
		Ui.apply_label(label, 11, Ui.MUTED)
		row.add_child(label)
		var value := Label.new()
		value.text = str(stat["value"])
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		Ui.apply_label(value, 12, Ui.INK)
		row.add_child(value)
		_tool_info_stats.add_child(row)


func _on_tool_hover(tool: int) -> void:
	_hovered_tool = tool
	_sync_tool_roles()


func _on_tool_unhover(tool: int) -> void:
	if _hovered_tool == tool:
		_hovered_tool = -1
	_sync_tool_roles()


func _sync_tool_roles() -> void:
	## Square cards show icon + name; what a tool does lives in the panel below.
	for i in _tool_roles.size():
		var role: Label = _tool_roles[i]
		if role == null:
			continue
		role.visible = false
	_refresh_tool_info(true)


func _on_tool_pressed(tool: int) -> void:
	if not GameState.owns_tool(tool):
		return
	tool_selected.emit(tool)


func _highlight_tool(tool: int) -> void:
	var key: String = str(tool)
	for i in _tool_buttons.size():
		key += "1" if GameState.owns_tool(_slot_tools[i]) else "0"
	if key == _tool_style_key:
		return
	_tool_style_key = key
	for i in _tool_buttons.size():
		var id: int = _slot_tools[i]
		var owned: bool = GameState.owns_tool(id)
		## Locked tools keep their square (dimmed) so the grid never looks sparse.
		_tool_slots[i].visible = true
		var on: bool = owned and id == tool
		_tool_buttons[i].disabled = not owned
		Ui.apply_tool_button(_tool_buttons[i], on)
		_tool_buttons[i].modulate = Color.WHITE if owned else Color(1, 1, 1, LOCKED_ALPHA)
	_sync_tool_roles()
	_refresh_tool_info(true)
	_layout_key = ""
	_layout_chrome()


func _apply_tool_flashes() -> void:
	for i in _tool_buttons.size():
		var id: int = _slot_tools[i]
		if not _tool_slots[i].visible or not GameState.owns_tool(id):
			continue
		if id >= _tool_flash.size() or _tool_flash[id] <= 0.0:
			if _tool_buttons[i].modulate != Color.WHITE:
				_tool_buttons[i].modulate = Color.WHITE
			continue
		var glow: float = _tool_flash[id]
		var pulse: float = 0.55 + 0.45 * absf(sin(glow * TAU * 2.2))
		_tool_buttons[i].modulate = Color("FFE08A").lerp(Color.WHITE, 1.0 - glow * pulse)


func _layout_chrome() -> void:
	var pit_top: float = Tuning.hud_h + 8.0
	if Settings != null and Settings.has_method("_layout_wallet"):
		Settings.call("_layout_wallet")
	_bind_shared_wallet()
	var pit := Tuning.pit_grid_rect()
	pit_top = pit.position.y
	if _clock != null:
		_clock.anchor_left = 0.0
		_clock.anchor_top = 0.0
		_clock.anchor_right = 0.0
		_clock.anchor_bottom = 0.0
		_clock.size = Vector2(CLOCK_SIZE, CLOCK_SIZE)
	if _clock_time != null:
		Ui.apply_copy(_clock_time, _clock_time.text, CLOCK_TIME_SIZE, Ui.PAPER_DEEP, 180.0)
		_clock_time.size = _clock_time.get_combined_minimum_size()
	if _clock_caption != null:
		Ui.apply_copy(_clock_caption, _clock_caption.text, 16, _clock_caption.get_theme_color("font_color") if _clock_caption.has_theme_color_override("font_color") else Ui.PAPER_DEEP, 200.0)
		_clock_caption.size = _clock_caption.get_combined_minimum_size()
	var text_w: float = 0.0
	var text_h: float = 0.0
	if _clock_time != null:
		text_w = maxf(text_w, _clock_time.size.x)
		text_h += _clock_time.size.y
	if _clock_caption != null:
		text_w = maxf(text_w, _clock_caption.size.x)
		text_h += 4.0 + _clock_caption.size.y
	var cluster_w: float = CLOCK_SIZE + CLOCK_GAP + text_w
	var cluster_h: float = maxf(CLOCK_SIZE, text_h)
	var header_limit: float = minf(pit_top, Tuning.hud_h) - 4.0
	var cluster_y: float = maxf(4.0, (header_limit - cluster_h) * 0.5)
	if cluster_y + cluster_h > header_limit:
		cluster_y = maxf(4.0, header_limit - cluster_h)
	var cluster_x: float = (Tuning.view_w - cluster_w) * 0.5
	var wallet_right: float = _wallet.position.x + _wallet.size.x + 12.0 if _wallet != null else 12.0
	if cluster_x < wallet_right:
		cluster_x = wallet_right
	var nav_left: float = Tuning.view_w - 8.0
	if Settings != null and Settings.has_method("nav_rect"):
		var nav: Rect2 = Settings.nav_rect()
		if nav.size.x > 1.0:
			nav_left = nav.position.x - 12.0
	if cluster_x + cluster_w > nav_left:
		cluster_x = maxf(wallet_right, nav_left - cluster_w)
	if _clock != null:
		_clock.position = Vector2(cluster_x, cluster_y + (cluster_h - CLOCK_SIZE) * 0.5)
	if _clock_time != null:
		_clock_time.position = Vector2(cluster_x + CLOCK_SIZE + CLOCK_GAP, cluster_y + (cluster_h - text_h) * 0.5)
	if _clock_caption != null:
		_clock_caption.position = Vector2(cluster_x + CLOCK_SIZE + CLOCK_GAP, _clock_time.position.y + _clock_time.size.y + 4.0)
	if _header_bar != null:
		var header_w: float = _header_cluster_width()
		var header_y: float = 6.0
		_header_bar.anchor_left = 0.0
		_header_bar.anchor_top = 0.0
		_header_bar.anchor_right = 0.0
		_header_bar.anchor_bottom = 0.0
		_header_bar.position = Vector2(Tuning.view_w - RAIL_PAD - header_w, header_y)
		_header_bar.size = Vector2(maxf(header_w, 1.0), HEADER_BTN_H)
		_header_bar.notification(Container.NOTIFICATION_SORT_CHILDREN)
	var frame_w: float = _section_frame_width()
	var tools_frame := Rect2(Vector2(RAIL_PAD, pit.position.y), Vector2(frame_w, rails_bottom() - pit.position.y))
	_place_section_frame(_tools_frame, tools_frame)
	_layout_section_title(_tools_label, TOOLS_TITLE, tools_frame)
	var tools_inner := _section_inner(tools_frame)
	var card: Vector2 = _tool_card_size_in(tools_inner)
	var grid_h: float = card.y * 2.0 + TOOL_GRID_GAP
	if _tool_rail != null:
		_tool_rail.anchor_left = 0.0
		_tool_rail.anchor_top = 0.0
		_tool_rail.anchor_right = 0.0
		_tool_rail.anchor_bottom = 0.0
		_tool_rail.position = tools_inner.position
		for i in _tool_slots.size():
			var btn: Button = _tool_buttons[i] if i < _tool_buttons.size() else null
			_apply_tool_card_size(_tool_slots[i], btn, card)
		_tool_rail.size = Vector2(tools_inner.size.x, grid_h)
		_tool_rail.notification(Container.NOTIFICATION_SORT_CHILDREN)
	if _tool_info != null:
		var info_top: float = tools_inner.position.y + grid_h + TOOL_GRID_GAP + 4.0
		_tool_info.position = Vector2(tools_inner.position.x, info_top)
		_tool_info.size = Vector2(tools_inner.size.x, maxf(tools_inner.end.y - info_top, 40.0))
	## Finds rail on the right mirrors the Tools rail; the fame medal sits at
	## its foot.
	var finds_band: Rect2 = finds_rail_rect()
	_place_section_frame(_finds_frame, finds_band)
	_layout_section_title(_finds_label, FINDS_TITLE, finds_band)
	var finds_top: float = finds_band.position.y + SECTION_TITLE_TOP
	if _finds_label != null:
		finds_top = _finds_label.position.y + _finds_label.size.y + RAIL_LABEL_GAP
	var finds_bottom: float = finds_band.end.y - SECTION_PAD - FAME_FOOT_H
	_find_box.anchor_left = 0.0
	_find_box.anchor_top = 0.0
	_find_box.anchor_right = 0.0
	_find_box.anchor_bottom = 0.0
	_find_box.custom_minimum_size = Vector2(0, 0)
	_find_box.position = Vector2(finds_band.position.x + SECTION_PAD, finds_top)
	_finds_box_h = maxf(finds_bottom - finds_top, 1.0)
	_find_box.size = Vector2(maxf(finds_band.size.x - SECTION_PAD * 2.0, 1.0), _finds_box_h)


## Both rails run from the pit's top edge to the bottom of its front face.
func rails_bottom() -> float:
	return Tuning.pit_face_bottom() + Tuning.chunk_front


func finds_rail_rect() -> Rect2:
	var pit := Tuning.pit_grid_rect()
	var left: float = pit.end.x + Tuning.chunk_pad + RAIL_PAD
	var right: float = Tuning.view_w - RAIL_PAD
	return Rect2(Vector2(left, pit.position.y), Vector2(maxf(right - left, 120.0), maxf(rails_bottom() - pit.position.y, 120.0)))


func _layout_footer() -> void:
	_layout_chrome()


func _header_cluster_width() -> float:
	if _header_bar == null:
		return 1.0
	var sep: float = float(_header_bar.get_theme_constant("separation"))
	var width: float = 0.0
	var shown: int = 0
	for raw in _header_bar.get_children():
		var child: Control = raw as Control
		if child == null or not child.visible:
			continue
		width += maxf(child.get_combined_minimum_size().x, child.custom_minimum_size.x)
		shown += 1
	if shown > 1:
		width += sep * float(shown - 1)
	return maxf(width, _header_bar.get_combined_minimum_size().x)


func _place_header_marks() -> void:
	for raw in [_menu_btn, _end_btn]:
		var btn: Button = raw as Button
		if btn == null:
			continue
		ShopIcon.place_left_of_label(btn, btn.get_node_or_null("ActionMark") as Control)


func _make_header_button(text: String, pressed: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	var font: Font = Ui.display_font()
	var text_w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, Ui.META_SIZE).x
	btn.custom_minimum_size = Vector2(maxf(96.0, ceili(text_w + 32.0 + Ui.ACTION_ICON + Ui.ICON_GAP)), HEADER_BTN_H)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.clip_text = false
	btn.autowrap_mode = TextServer.AUTOWRAP_OFF
	btn.add_theme_font_size_override("font_size", Ui.META_SIZE)
	Ui.apply_hud_button(btn)
	btn.pressed.connect(pressed)
	var glyph: String = ShopIcon.glyph_for_action(text)
	if not glyph.is_empty():
		var mark: Control = ShopIcon.new()
		mark.name = "ActionMark"
		ShopIcon.apply_action(mark)
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if mark.has_method("setup"):
			mark.setup(glyph, Ui.GOLD)
		btn.add_child(mark)
	return btn


func _wallet_rate_text_width() -> float:
	var font: Font = Ui.display_font()
	return font.get_string_size(WALLET_RATE_SAMPLE, HORIZONTAL_ALIGNMENT_LEFT, -1, Ui.CAPTION_SIZE).x


func _wallet_text_col_width() -> float:
	var font: Font = Ui.display_font()
	var money_w: float = font.get_string_size(WALLET_MONEY_SAMPLE, HORIZONTAL_ALIGNMENT_LEFT, -1, Ui.WALLET_SIZE).x
	var rate_row: float = _wallet_rate_text_width() + Ui.ACTION_ICON + Ui.ICON_GAP
	return maxf(money_w, rate_row)


func _wallet_reserved_width() -> float:
	var pad_left: float = 8.0
	var pad_right: float = WALLET_RIGHT_PAD
	if _wallet != null:
		var box: StyleBox = _wallet.get_theme_stylebox("panel")
		if box != null:
			pad_left = box.content_margin_left
			pad_right = box.content_margin_right
	return pad_left + 32.0 + 8.0 + _wallet_text_col_width() + pad_right


func _reserve_wallet_width() -> void:
	var text_w: float = _wallet_text_col_width()
	if _money != null:
		_money.custom_minimum_size.x = text_w
	if _income != null:
		_income.custom_minimum_size.x = _wallet_rate_text_width()
	if _wallet != null:
		_wallet.custom_minimum_size.x = _wallet_reserved_width()
