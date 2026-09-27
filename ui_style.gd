extends RefCounted

const BrassBox := preload("res://brass_style_box.gd")

const FONT_PATH := "res://fonts/libre_baskerville/LibreBaskerville-Regular.ttf"
const INK := Color("F6EDE0")
const MUTED := Color("C9B8A2")
const GOLD := Color("E4B75A")
const PAPER := Color("2C2118")
const PAPER_DEEP := Color("1B1410")
const LINE := Color("6A523C")
const ACCENT := Color("C47A3A")
const FIELD := Color("16110D")
const PANEL := Color("2A1F18")
const DIM := Color(0.06, 0.04, 0.03, 0.72)
const TITLE_SIZE := 26
const WALLET_SIZE := 26
const SECTION_SIZE := 22
const BODY_SIZE := 16
const CAPTION_SIZE := 14
const META_SIZE := 13
const HEADER_H := 86.0
const HEADER_PAD := 16.0
const NAV_SIZE := Vector2(100, 40)
const ACTION_ICON := 18.0
const TOOL_ICON := 22.0
const RAIL_TOOL_ICON := 44.0
const ICON_GAP := 8.0
const CORNER := 6
const HOVER_OUTLINE := 4
const HUD_SHADOW_SIZE := 3
const HUD_SHADOW_OFFSET := Vector2(0, 1)
const HUD_SHADOW := Color(0.05, 0.03, 0.02, 0.28)

static var _font: Font


static func display_font() -> Font:
	if _font != null:
		return _font
	if ResourceLoader.exists(FONT_PATH):
		var loaded: Resource = load(FONT_PATH)
		if loaded is Font:
			_font = loaded
			return _font
	var file := FontFile.new()
	if file.load_dynamic_font(FONT_PATH) == OK:
		_font = file
		return _font
	return ThemeDB.fallback_font


static func apply_font(control: Control) -> void:
	control.add_theme_font_override("font", display_font())


static func brass_box(fill: Color, inset: bool = false):
	var box = BrassBox.new()
	box.bg_color = fill
	box.inset = inset
	box.border_color = LINE
	box.set_border_width_all(2)
	box.set_corner_radius_all(CORNER)
	if inset:
		box.shadow_size = 0
		box.shadow_offset = Vector2.ZERO
	else:
		box.shadow_color = Color(0.05, 0.03, 0.02, 0.55)
		box.shadow_size = 10
		box.shadow_offset = Vector2(1, 3)
	return box


static func panel_box(fill: Color = PAPER):
	var box = brass_box(fill, false)
	box.content_margin_left = 16
	box.content_margin_right = 16
	box.content_margin_top = 12
	box.content_margin_bottom = 12
	return box


static func button_box(fill: Color, border: Color = LINE, inset: bool = false, width: int = 2, rail: bool = false):
	var box = brass_box(fill, inset)
	box.border_color = border
	box.set_border_width_all(width)
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	if not inset:
		if rail:
			_apply_hud_shadow(box)
		else:
			box.shadow_size = 8 if width < 4 else 12
			box.shadow_offset = Vector2(1, 2)
	return box


static func hud_button_box(fill: Color, border: Color = LINE, inset: bool = false, width: int = 2):
	return button_box(fill, border, inset, width, true)


static func apply_hover_outline(box) -> void:
	if box == null:
		return
	box.border_color = GOLD
	box.set_border_width_all(HOVER_OUTLINE)


static func _apply_hud_shadow(box) -> void:
	if box != null and box.has_method("apply_hud_shadow"):
		box.apply_hud_shadow()
		return
	if box == null:
		return
	box.shadow_color = HUD_SHADOW
	box.shadow_size = HUD_SHADOW_SIZE
	box.shadow_offset = HUD_SHADOW_OFFSET


static func copy_stylebox(box: StyleBox) -> StyleBox:
	if box != null and box.has_method("clone_chrome"):
		return box.clone_chrome()
	return box.duplicate() if box != null else StyleBoxEmpty.new()


static func apply_button(button: Button, prominent: bool = false) -> void:
	_paint_button(button, prominent, false)


static func apply_hud_button(button: Button, prominent: bool = false) -> void:
	_paint_button(button, prominent, true)


static func _paint_button(button: Button, prominent: bool, rail: bool) -> void:
	var fill := Color("8A4E24") if prominent else Color("3F3126")
	var hover := Color("B86A2E") if prominent else Color("534233")
	_stamp_button_boxes(button, fill, hover, GOLD if prominent else LINE, 2, rail)
	apply_font(button)
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", GOLD)
	button.add_theme_color_override("font_disabled_color", Color("7A6A58"))


static func apply_tool_button(button: Button, selected: bool) -> void:
	var fill := Color("8A4E24") if selected else Color("3F3126")
	var hover := Color("B86A2E") if selected else Color("534233")
	var width: int = HOVER_OUTLINE if selected else 2
	var border := GOLD if selected else LINE
	_stamp_button_boxes(button, fill, hover, border, width, true)
	apply_font(button)
	button.add_theme_color_override("font_color", GOLD if selected else INK)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", GOLD)
	button.add_theme_color_override("font_disabled_color", Color("7A6A58"))


static func _stamp_button_boxes(button: Button, fill: Color, hover: Color, border: Color, width: int, rail: bool = false) -> void:
	## Isolated theme so Godot's default focus (white, r=3, expand=2) cannot under-draw.
	var hover_box = button_box(hover, GOLD, false, width, rail)
	apply_hover_outline(hover_box)
	var boxes := {
		"normal": button_box(fill, border, false, width, rail),
		"hover": hover_box,
		"pressed": button_box(Color("6E3C1C"), GOLD, true, width, rail),
		"disabled": button_box(Color("2A221C"), Color("4A3C30"), true, 2, rail),
		"focus": button_box(fill, border, false, width, rail),
		"hover_pressed": button_box(Color("6E3C1C"), GOLD, true, width, rail),
	}
	var theme := Theme.new()
	for name in boxes:
		theme.set_stylebox(str(name), "Button", boxes[name])
		button.add_theme_stylebox_override(str(name), boxes[name])
	button.theme = theme
	button.clip_contents = false
	button.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_DISABLED


static func apply_tab(button: Button, selected: bool, affordable: bool = false) -> void:
	var fill := Color("4A3420") if selected else Color("2A221C")
	if affordable and not selected:
		fill = Color("3A2A18")
	var border := GOLD if selected or affordable else LINE
	var hover := Color("5C4030") if selected else Color("3F3126")
	var tab_hover = button_box(hover, GOLD, false)
	apply_hover_outline(tab_hover)
	button.add_theme_stylebox_override("normal", button_box(fill, border, false))
	button.add_theme_stylebox_override("hover", tab_hover)
	button.add_theme_stylebox_override("pressed", button_box(Color("6E3C1C"), GOLD, true))
	button.add_theme_stylebox_override("focus", button_box(fill, GOLD, false))
	apply_font(button)
	button.add_theme_color_override("font_color", GOLD if selected else INK)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", GOLD)
	button.add_theme_color_override("font_focus_color", GOLD)


static func chapter_box():
	var box = panel_box(Color("221A14"))
	box.border_color = Color("8A6A40")
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 12
	box.content_margin_bottom = 12
	return box


static func gate_box():
	var box = brass_box(Color("16110D"), true)
	box.border_color = Color("4A3C30")
	box.content_margin_left = 18
	box.content_margin_right = 18
	box.content_margin_top = 18
	box.content_margin_bottom = 18
	return box


static func chip_box(progress: float):
	var t := clampf(progress, 0.0, 1.0)
	var fill := Color("261E18").lerp(Color("4A3418"), t)
	var border := Color("5A4A3A").lerp(GOLD, t)
	var width := 2
	var glow := int(round(lerpf(8.0, 16.0, t)))
	if t >= 0.995:
		fill = Color("3A2A18")
		border = GOLD
		width = 3
		glow = 16
	var box = panel_box(fill)
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(CORNER)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	box.shadow_color = Color(0.89, 0.72, 0.35, lerpf(0.12, 0.55, t))
	box.shadow_size = glow
	box.shadow_offset = Vector2(1, 3)
	return box


static func row_box(heat: String):
	var fill := Color("2A211A")
	var border := LINE
	var width := 2
	var glow := 8
	match heat:
		"glow":
			fill = Color("3A2A18")
			border = GOLD
			width = 3
			glow = 14
		"maxed":
			fill = Color("3A2C18")
			border = Color("C9A056")
		"locked":
			fill = Color("1E1914")
			border = Color("4A3C30")
		"dim":
			fill = Color("261E18")
			border = Color("5A4A3A")
	var box = panel_box(fill)
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(CORNER)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	box.shadow_color = Color(0.89, 0.72, 0.35, 0.5) if heat == "glow" else Color(0.05, 0.03, 0.02, 0.40)
	box.shadow_size = glow
	box.shadow_offset = Vector2(1, 3)
	return box


static func apply_panel(panel: Panel, fill: Color = PAPER) -> void:
	panel.add_theme_stylebox_override("panel", panel_box(fill))


static func icon_well_box(fill: Color):
	var box = brass_box(fill, true)
	box.content_margin_left = 0
	box.content_margin_right = 0
	box.content_margin_top = 0
	box.content_margin_bottom = 0
	return box


static func apply_icon_well(panel: Panel, fill: Color) -> void:
	panel.add_theme_stylebox_override("panel", icon_well_box(fill))


static func bar_box(fill: Color = PAPER_DEEP, top_edge: bool = true) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = LINE
	box.border_width_top = 2 if top_edge else 0
	box.border_width_bottom = 0 if top_edge else 2
	box.border_width_left = 0
	box.border_width_right = 0
	box.set_corner_radius_all(0)
	box.content_margin_left = 16
	box.content_margin_right = 16
	return box


static func apply_bar(panel: Panel, fill: Color = PAPER_DEEP, top_edge: bool = true) -> void:
	panel.add_theme_stylebox_override("panel", bar_box(fill, top_edge))


static func apply_label(label: Label, size: int, color: Color = INK) -> void:
	apply_font(label)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)


static func apply_copy(label: Label, text: String, size: int, color: Color = INK, max_w: float = 0.0, wrap: bool = false) -> void:
	label.text = text
	label.clip_text = false
	label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	var fit: int = size
	var font: Font = display_font()
	if wrap and max_w > 0.0:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD
		for raw in text.split(" ", false):
			var word_w: float = font.get_string_size(str(raw), HORIZONTAL_ALIGNMENT_LEFT, -1, fit).x
			while fit > 9 and word_w > max_w:
				fit -= 1
				word_w = font.get_string_size(str(raw), HORIZONTAL_ALIGNMENT_LEFT, -1, fit).x
		apply_label(label, fit, color)
		label.custom_minimum_size = Vector2(maxf(max_w, 8.0), 0)
		return
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	var wide: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fit).x
	if max_w > 0.0:
		while fit > 9 and wide > max_w:
			fit -= 1
			wide = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fit).x
	apply_label(label, fit, color)
	label.custom_minimum_size = Vector2(ceili(wide + 2.0), 0)


static func apply_title(label: Label) -> void:
	apply_label(label, TITLE_SIZE, GOLD)


static func apply_section(label: Label) -> void:
	apply_label(label, SECTION_SIZE, GOLD)


static func apply_field_section(label: Label, text: String, max_w: float = 0.0) -> void:
	## Dark dirt ink on tan ground — gold catalog titles fail on sand.
	## Size to glyphs only. Never stretch min-size to the rail (that paints a plate).
	apply_label(label, SECTION_SIZE, PAPER_DEEP)
	label.add_theme_constant_override("outline_size", 0)
	label.clip_text = false
	label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var font: Font = display_font()
	var line_w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, SECTION_SIZE).x
	if max_w > 0.0 and line_w > max_w and text.contains(" "):
		label.autowrap_mode = TextServer.AUTOWRAP_WORD
		var word_w: float = 0.0
		for raw in text.split(" ", false):
			word_w = maxf(word_w, font.get_string_size(str(raw), HORIZONTAL_ALIGNMENT_LEFT, -1, SECTION_SIZE).x)
		label.text = text
		label.custom_minimum_size = Vector2(ceili(word_w + 2.0), 0)
	else:
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.text = text
		label.custom_minimum_size = Vector2(ceili(line_w + 2.0), 0)
	apply_text_only(label)


static func apply_text_only(label: Label) -> void:
	## Glyphs only — isolate from Godot's default Label/focus white plate.
	var empty := StyleBoxEmpty.new()
	var theme := Theme.new()
	theme.set_stylebox("normal", "Label", empty)
	theme.set_stylebox("focus", "Label", empty)
	label.theme = theme
	label.add_theme_stylebox_override("normal", empty)
	label.add_theme_stylebox_override("focus", empty)
	label.focus_mode = Control.FOCUS_NONE
	label.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_DISABLED
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE


static func apply_wallet(label: Label) -> void:
	apply_label(label, WALLET_SIZE, GOLD)


static func apply_body(label: Label) -> void:
	apply_label(label, BODY_SIZE, INK)


static func apply_caption(label: Label) -> void:
	apply_label(label, CAPTION_SIZE, MUTED)


static func apply_nav(button: Button, prominent: bool = false) -> void:
	button.custom_minimum_size = NAV_SIZE
	button.clip_text = false
	apply_font(button)
	button.add_theme_font_size_override("font_size", 16)
	apply_button(button, prominent)


static func apply_action_icon(mark: Control) -> void:
	if mark == null:
		return
	mark.custom_minimum_size = Vector2(ACTION_ICON, ACTION_ICON)
	mark.size = Vector2(ACTION_ICON, ACTION_ICON)
	mark.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER


static func apply_tool_icon(mark: Control) -> void:
	if mark == null:
		return
	mark.custom_minimum_size = Vector2(TOOL_ICON, TOOL_ICON)
	mark.size = Vector2(TOOL_ICON, TOOL_ICON)
	mark.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER


static func apply_rail_tool_icon(mark: Control, px: float = -1.0) -> void:
	if mark == null:
		return
	var box: float = RAIL_TOOL_ICON if px < 0.0 else px
	mark.custom_minimum_size = Vector2(box, box)
	mark.size = Vector2(box, box)
	mark.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	mark.size_flags_vertical = Control.SIZE_SHRINK_BEGIN


static func field_frame_box():
	var box := StyleBoxFlat.new()
	box.bg_color = Color("3A2C22")
	box.draw_center = true
	box.border_color = LINE
	box.set_border_width_all(2)
	box.set_corner_radius_all(CORNER)
	box.shadow_size = 0
	box.shadow_offset = Vector2.ZERO
	box.content_margin_left = 6
	box.content_margin_right = 6
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	return box


static func icon_row_gap(row: HBoxContainer) -> void:
	if row == null:
		return
	row.add_theme_constant_override("separation", int(ICON_GAP))


static func align_icon_row(row: HBoxContainer) -> void:
	if row == null:
		return
	icon_row_gap(row)
	row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.custom_minimum_size.y = TOOL_ICON
	var icon: Control = null
	var label: Label = null
	for child in row.get_children():
		if child is Label and label == null:
			label = child as Label
		var script: Script = child.get_script() as Script
		if script != null and str(script.resource_path).ends_with("tool_icon.gd"):
			icon = child as Control
	if icon != null:
		apply_tool_icon(icon)
	if label != null:
		label.size_flags_vertical = Control.SIZE_FILL
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.custom_minimum_size.y = maxf(label.custom_minimum_size.y, TOOL_ICON)
	row.notification(Container.NOTIFICATION_SORT_CHILDREN)


static func indent_button_for_icon(button: Button, gap: float = ICON_GAP) -> void:
	if button == null or bool(button.get_meta("icon_indented", false)):
		return
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var box: StyleBox = button.get_theme_stylebox(state)
		if box == null:
			continue
		var copy: StyleBox = copy_stylebox(box)
		copy.content_margin_left = box.content_margin_left + ACTION_ICON + gap
		button.add_theme_stylebox_override(state, copy)
	button.set_meta("icon_indented", true)


static func place_icon_left_of_label(button: Button, mark: Control, gap: float = ICON_GAP) -> void:
	if button == null or mark == null:
		return
	apply_action_icon(mark)
	indent_button_for_icon(button, gap)
	var box: StyleBox = button.get_theme_stylebox("normal")
	var pad_l: float = box.content_margin_left if box != null else 12.0 + ACTION_ICON + gap
	var font: Font = button.get_theme_font("font")
	var sized: int = button.get_theme_font_size("font_size")
	var line_h: float = mark.size.y
	if font != null:
		line_h = font.get_height(sized)
	var mark_x: float = pad_l - mark.size.x - gap
	var line_mid: float = (button.size.y - line_h) * 0.5 + line_h * 0.5
	mark.position = Vector2(mark_x, line_mid - mark.size.y * 0.5)


static func apply_field(rect: ColorRect) -> void:
	rect.color = FIELD
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE


static func apply_modal(panel: Panel) -> void:
	apply_panel(panel, PANEL)


static func apply_header_bar(bar: Panel) -> void:
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_bottom = HEADER_H
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	apply_bar(bar, PAPER_DEEP, false)


static func place_header_back(button: Button) -> void:
	button.position = Vector2(HEADER_PAD, (HEADER_H - NAV_SIZE.y) * 0.5)
	button.size = NAV_SIZE


static func place_header_title(label: Label) -> void:
	label.position = Vector2(HEADER_PAD + NAV_SIZE.x + 12.0, (HEADER_H - 36.0) * 0.5)
	label.size = Vector2(280, 36)


static func wallet_box():
	var box = panel_box(PAPER)
	box.set_corner_radius_all(CORNER)
	box.content_margin_left = 8
	box.content_margin_right = 20
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	box.shadow_size = 8
	box.shadow_offset = Vector2(1, 3)
	return box


static func tooltip_box():
	var box = panel_box(Color("2C2118"))
	box.border_color = GOLD
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	box.shadow_color = Color(0.89, 0.72, 0.35, 0.38)
	box.shadow_size = 10
	box.shadow_offset = Vector2(1, 3)
	return box


static func badge_box():
	var box = brass_box(GOLD, false)
	box.border_color = Color("8A6A28")
	box.content_margin_left = 6
	box.content_margin_right = 6
	box.content_margin_top = 1
	box.content_margin_bottom = 1
	box.shadow_size = 4
	box.shadow_offset = Vector2(0, 2)
	return box


static func apply_slider(slider: Slider) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = PAPER_DEEP
	track.border_color = LINE
	track.set_border_width_all(2)
	track.set_corner_radius_all(6)
	track.content_margin_top = 6
	track.content_margin_bottom = 6
	track.content_margin_left = 4
	track.content_margin_right = 4
	var fill := StyleBoxFlat.new()
	fill.bg_color = GOLD
	fill.set_corner_radius_all(6)
	slider.add_theme_stylebox_override("slider", track)
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill)


static func apply_check(button: Button) -> void:
	apply_button(button)
	apply_font(button)
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", GOLD)
	button.add_theme_color_override("font_focus_color", GOLD)
