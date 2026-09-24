extends RefCounted

const INK := Color("F6EDE0")
const MUTED := Color("C9B8A2")
const GOLD := Color("E4B75A")
const PAPER := Color("2C2118")
const PAPER_DEEP := Color("1B1410")
const LINE := Color("6A523C")
const ACCENT := Color("C47A3A")


static func panel_box(fill: Color = PAPER) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = LINE
	box.set_border_width_all(2)
	box.set_corner_radius_all(10)
	box.content_margin_left = 16
	box.content_margin_right = 16
	box.content_margin_top = 12
	box.content_margin_bottom = 12
	box.shadow_color = Color(0, 0, 0, 0.35)
	box.shadow_size = 8
	return box


static func button_box(fill: Color, border: Color = LINE) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(2)
	box.set_corner_radius_all(8)
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	return box


static func apply_button(button: Button, prominent: bool = false) -> void:
	var fill := Color("8A4E24") if prominent else Color("3F3126")
	var hover := Color("B86A2E") if prominent else Color("534233")
	button.add_theme_stylebox_override("normal", button_box(fill, GOLD if prominent else LINE))
	button.add_theme_stylebox_override("hover", button_box(hover, GOLD))
	button.add_theme_stylebox_override("pressed", button_box(Color("6E3C1C"), GOLD))
	button.add_theme_stylebox_override("disabled", button_box(Color("2A221C"), Color("4A3C30")))
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", GOLD)
	button.add_theme_color_override("font_disabled_color", Color("7A6A58"))


static func apply_tab(button: Button, selected: bool, affordable: bool = false) -> void:
	var fill := Color("4A3420") if selected else Color("2A221C")
	if affordable and not selected:
		fill = Color("3A2A18")
	var border := GOLD if selected or affordable else LINE
	var hover := Color("5C4030") if selected else Color("3F3126")
	button.add_theme_stylebox_override("normal", button_box(fill, border))
	button.add_theme_stylebox_override("hover", button_box(hover, GOLD))
	button.add_theme_stylebox_override("pressed", button_box(Color("6E3C1C"), GOLD))
	button.add_theme_stylebox_override("focus", button_box(fill, GOLD))
	button.add_theme_color_override("font_color", GOLD if selected else INK)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", GOLD)
	button.add_theme_color_override("font_focus_color", GOLD)


static func chapter_box() -> StyleBoxFlat:
	var box := panel_box(Color("221A14"))
	box.border_color = Color("8A6A40")
	box.set_border_width_all(2)
	box.set_corner_radius_all(12)
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 12
	box.content_margin_bottom = 12
	return box


static func gate_box() -> StyleBoxFlat:
	var box := panel_box(Color("16110D"))
	box.border_color = Color("4A3C30")
	box.set_border_width_all(2)
	box.set_corner_radius_all(12)
	box.content_margin_left = 18
	box.content_margin_right = 18
	box.content_margin_top = 18
	box.content_margin_bottom = 18
	return box


static func row_box(heat: String) -> StyleBoxFlat:
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
	var box := panel_box(fill)
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(10)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	box.shadow_color = Color(0.89, 0.72, 0.35, 0.5) if heat == "glow" else Color(0, 0, 0, 0.28)
	box.shadow_size = glow
	return box


static func apply_panel(panel: Panel, fill: Color = PAPER) -> void:
	panel.add_theme_stylebox_override("panel", panel_box(fill))


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
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)


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
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", GOLD)
	button.add_theme_color_override("font_focus_color", GOLD)
