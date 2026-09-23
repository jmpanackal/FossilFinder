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
