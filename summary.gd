class_name Summary
extends CanvasLayer

signal dig_again
signal open_museum
signal open_shop

const Ui := preload("res://ui_style.gd")
const ShopIcon := preload("res://shop_icon.gd")
const StarRating := preload("res://star_rating.gd")
const SummaryFindRowScript := preload("res://summary_find_row.gd")

const PANEL_W := 600.0
## The finds table needs room for its columns.
const WIDE_PANEL_W := 860.0
const BOX_PAD := 14.0
const PANEL_MAX_H := 620.0
const FINDS_MAX_H := 280.0

var _dim: ColorRect
var _panel: Panel
var _box: VBoxContainer
var _title: Label
var _rule: ColorRect
var _pay_caption: Label
var _pay: Label
var _breakdown: Label
var _body: Label
var _finds_scroll: ScrollContainer
var _finds_box: VBoxContainer
var _find_rows: Array = []
var _stars
var _button: Button
var _museum_btn: Button
var _shop_btn: Button
var _tip: Label
var _tip_wrap: Control
var _panel_w: float = PANEL_W
var _placing_marks: bool = false
var _intro: Tween


func _ready() -> void:
	layer = 20
	visible = false
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_dim = ColorRect.new()
	_dim.color = Ui.DIM
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(_dim)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_panel = Panel.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.offset_left = -PANEL_W * 0.5
	_panel.offset_right = PANEL_W * 0.5
	_panel.offset_top = -130
	_panel.offset_bottom = 130
	Ui.apply_modal(_panel)
	root.add_child(_panel)

	_box = VBoxContainer.new()
	_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	_box.offset_left = BOX_PAD
	_box.offset_right = -BOX_PAD
	_box.offset_top = BOX_PAD
	_box.offset_bottom = -BOX_PAD
	_box.add_theme_constant_override("separation", 8)
	_panel.add_child(_box)

	_title = Label.new()
	_title.text = "Shift over"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.autowrap_mode = TextServer.AUTOWRAP_OFF
	_title.clip_text = false
	Ui.apply_title(_title)
	_box.add_child(_title)

	## A short brass rule and a quiet caption give the total a small ceremony.
	_rule = ColorRect.new()
	_rule.color = Color(Ui.GOLD.r, Ui.GOLD.g, Ui.GOLD.b, 0.6)
	_rule.custom_minimum_size = Vector2(150, 2)
	_rule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(_rule)

	_pay_caption = Label.new()
	_pay_caption.text = "EARNED THIS SHIFT"
	_pay_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pay_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Ui.apply_label(_pay_caption, 12, Ui.MUTED)
	_box.add_child(_pay_caption)

	_pay = Label.new()
	_pay.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pay.autowrap_mode = TextServer.AUTOWRAP_OFF
	_pay.clip_text = false
	Ui.apply_wallet(_pay)
	_pay.add_theme_font_size_override("font_size", 46)
	_box.add_child(_pay)

	_breakdown = Label.new()
	_breakdown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_breakdown.autowrap_mode = TextServer.AUTOWRAP_OFF
	_breakdown.clip_text = false
	Ui.apply_caption(_breakdown)
	var pill := StyleBoxFlat.new()
	pill.bg_color = Color("3A2C20")
	pill.border_color = Ui.LINE
	pill.set_border_width_all(1)
	pill.set_corner_radius_all(12)
	pill.content_margin_left = 16.0
	pill.content_margin_right = 16.0
	pill.content_margin_top = 4.0
	pill.content_margin_bottom = 4.0
	_breakdown.add_theme_stylebox_override("normal", pill)
	_breakdown.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_box.add_child(_breakdown)

	_body = Label.new()
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.autowrap_mode = TextServer.AUTOWRAP_OFF
	_body.clip_text = false
	Ui.apply_body(_body)
	_box.add_child(_body)

	_finds_scroll = ScrollContainer.new()
	_finds_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_finds_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_finds_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_finds_scroll.visible = false
	_box.add_child(_finds_scroll)

	_finds_box = VBoxContainer.new()
	_finds_box.add_theme_constant_override("separation", 4)
	_finds_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_finds_box.visible = false
	_finds_scroll.add_child(_finds_box)

	_stars = Control.new()
	_stars.set_script(StarRating)
	_stars.visible = false
	_box.add_child(_stars)

	_button = Button.new()
	_button.text = "Dig again"
	_button.custom_minimum_size = Vector2(0, 58)
	_button.clip_text = false
	_button.add_theme_font_size_override("font_size", 24)
	Ui.apply_button(_button, true)
	_button.pressed.connect(_on_dig_again)
	_box.add_child(_button)

	var extras := HBoxContainer.new()
	extras.add_theme_constant_override("separation", 10)
	_box.add_child(extras)
	_museum_btn = _small_nav("Museum", func() -> void: open_museum.emit())
	_shop_btn = _small_nav("Upgrades", func() -> void: open_shop.emit())
	extras.add_child(_museum_btn)
	extras.add_child(_shop_btn)

	## Tips for this screen show here, in the card, not in a toast under the dim.
	## The wrapper has a fixed size we compute, so the card never depends on how a
	## wrapping label measures itself before it has been laid out.
	_tip_wrap = Control.new()
	_tip_wrap.visible = false
	_tip_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(_tip_wrap)
	_tip = Label.new()
	_tip.visible = false
	_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tip.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Ui.apply_label(_tip, 13, Ui.MUTED)
	_tip_wrap.add_child(_tip)
	_tip.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func show_summary(fossil_pay: int, finds_pay: int, fossil_line: String, stars: int = 0, finds: Array = []) -> void:
	var shift_pay: int = fossil_pay + finds_pay
	_pay.text = pay_headline(shift_pay)
	_breakdown.text = pay_breakdown(fossil_pay, finds_pay)
	_breakdown.visible = not _breakdown.text.is_empty()
	_apply_finds(finds, fossil_line)
	if _stars.has_method("set_rating"):
		_stars.set_rating(stars)
	## With a finds table every row already shows its own stars.
	_stars.visible = stars > 0 and _find_rows.is_empty()
	_tip.visible = false
	_tip_wrap.visible = false
	_tip.text = ""
	_fit_panel()
	_start_intro()
	visible = true
	_button.grab_focus()


## The card eases in (fade + a small settle), the dim fades with it, and the
## total gives one small pop. The starting state is set before the card is shown,
## so there is never a frame of the finished card; pivots come from the card's
## known size, not from a layout that may not have happened yet.
func _start_intro() -> void:
	if _panel == null:
		return
	if _intro != null and _intro.is_valid():
		_intro.kill()
	var half := Vector2(_panel_w * 0.5, (_panel.offset_bottom - _panel.offset_top) * 0.5)
	_panel.pivot_offset = half
	_panel.modulate.a = 0.0
	_panel.scale = Vector2(0.95, 0.95)
	_dim.modulate.a = 0.0
	_pay.pivot_offset = Vector2((_panel_w - BOX_PAD * 2.0) * 0.5, _pay.get_combined_minimum_size().y * 0.5)
	_pay.scale = Vector2(1.14, 1.14)
	_intro = create_tween()
	_intro.set_parallel(true)
	_intro.tween_property(_dim, "modulate:a", 1.0, 0.18)
	_intro.tween_property(_panel, "modulate:a", 1.0, 0.20).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_intro.tween_property(_panel, "scale", Vector2.ONE, 0.26).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_intro.tween_property(_pay, "scale", Vector2.ONE, 0.34).set_delay(0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## A tip for this screen, shown inside the card until the shift summary closes.
func show_tip(_title_text: String, text: String) -> void:
	if _tip == null:
		return
	_tip.text = "TIP  ·  %s" % text
	_tip.visible = true
	_tip_wrap.visible = true
	_fit_panel()


static func pay_headline(shift_pay: int) -> String:
	return "$%d" % shift_pay


static func pay_breakdown(fossil_pay: int, finds_pay: int) -> String:
	if fossil_pay > 0 and finds_pay > 0:
		return "Finds $%d · Fossils $%d" % [finds_pay, fossil_pay]
	if fossil_pay > 0:
		return "Fossils $%d" % fossil_pay
	if finds_pay > 0:
		return "Finds $%d" % finds_pay
	return ""


static func find_line(piece_name: String, grade: String, dirt_tag: String, fate: String = "") -> String:
	var bits: PackedStringArray = PackedStringArray()
	if not piece_name.is_empty():
		bits.append(piece_name)
	if not grade.is_empty():
		bits.append(grade)
	if not dirt_tag.is_empty():
		bits.append(dirt_tag)
	if not fate.is_empty():
		bits.append(fate)
	return " · ".join(bits)


func _apply_finds(finds: Array, fossil_line: String) -> void:
	for child in _finds_box.get_children():
		_finds_box.remove_child(child)
		child.free()
	_find_rows.clear()
	var seen: PackedStringArray = PackedStringArray()
	for raw in finds:
		if not raw is Dictionary:
			continue
		var entry: Dictionary = raw
		var line: String = find_line(
			str(entry.get("name", "")),
			str(entry.get("grade", "")),
			str(entry.get("dirt", "")),
			str(entry.get("fate", ""))
		)
		if line.is_empty() or seen.has(line):
			continue
		seen.append(line)
		if _find_rows.is_empty():
			_finds_box.add_child(SummaryFindRowScript.make_header())
		var row: Control = SummaryFindRowScript.new() as Control
		_finds_box.add_child(row)
		if row.has_method("apply_find"):
			row.call("apply_find", entry)
		_find_rows.append(row)
	var has_rows: bool = not _find_rows.is_empty()
	_finds_box.visible = has_rows
	_finds_scroll.visible = has_rows
	_body.visible = not has_rows
	_body.text = "" if has_rows else fossil_line
	_fit_panel()


func _fit_panel() -> void:
	_panel_w = WIDE_PANEL_W if not _find_rows.is_empty() else PANEL_W
	_fit_copy(_title)
	_fit_copy(_pay)
	_fit_copy(_breakdown)
	_fit_copy(_body)
	_fit_copy(_button, 28.0)
	_fit_copy(_museum_btn, 48.0)
	_fit_copy(_shop_btn, 48.0)
	_fit_tip()
	_place_nav_marks()
	if _find_rows.is_empty():
		_finds_scroll.visible = false
		_finds_box.visible = false
		_finds_scroll.custom_minimum_size = Vector2.ZERO
		_finds_box.custom_minimum_size = Vector2.ZERO
	else:
		_finds_box.visible = true
		_finds_scroll.visible = true
		## The list gets whatever height the rest of the card leaves (up to its own
		## cap) and scrolls beyond that, so the buttons and tip are never pushed off.
		var list_h: float = _finds_box.get_combined_minimum_size().y
		_finds_scroll.custom_minimum_size = Vector2.ZERO
		var other_h: float = _box.get_combined_minimum_size().y
		var room: float = PANEL_MAX_H - BOX_PAD * 2.0 - other_h
		var cap: float = clampf(room, 120.0, FINDS_MAX_H)
		var shown: float = minf(list_h, cap)
		_finds_scroll.custom_minimum_size = Vector2(0.0, shown)
		_finds_scroll.vertical_scroll_mode = (
			ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
			if list_h > cap + 0.5
			else ScrollContainer.SCROLL_MODE_DISABLED
		)
	var content_h: float = _box.get_combined_minimum_size().y
	var height: float = clampf(content_h + BOX_PAD * 2.0, 180.0, PANEL_MAX_H)
	var half: float = height * 0.5
	_panel.offset_left = -_panel_w * 0.5
	_panel.offset_right = _panel_w * 0.5
	_panel.offset_top = -half
	_panel.offset_bottom = half


## A wrapped label only knows its height once it is laid out; measure it here so
## the card is tall enough the first time.
func _fit_tip() -> void:
	if _tip == null or _tip_wrap == null or not _tip_wrap.visible:
		return
	var inner_w: float = _panel_w - BOX_PAD * 2.0
	var font: Font = _tip.get_theme_font("font")
	var sized: int = _tip.get_theme_font_size("font_size")
	var wrapped_h: float = float(sized) + 6.0
	if font != null:
		wrapped_h = font.get_multiline_string_size(_tip.text, HORIZONTAL_ALIGNMENT_CENTER, inner_w, sized).y + 8.0
	_tip_wrap.custom_minimum_size = Vector2(inner_w, wrapped_h)


func _fit_copy(control: Control, extra_x: float = 0.0) -> void:
	if control == null:
		return
	control.clip_text = false
	var font: Font = control.get_theme_font("font")
	var sized: int = control.get_theme_font_size("font_size")
	var text: String = str(control.get("text"))
	var width: float = extra_x
	if font != null:
		width += font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, sized).x
	var inner_w: float = _panel_w - BOX_PAD * 2.0
	if control is Label:
		var label: Label = control as Label
		if width > inner_w:
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			width = inner_w
		else:
			label.autowrap_mode = TextServer.AUTOWRAP_OFF
	var min_w: float = minf(inner_w, width + 2.0)
	control.custom_minimum_size.x = maxf(control.custom_minimum_size.x, min_w)
	if control.size.x < min_w:
		control.size.x = min_w


static func join_find_lines(lines: PackedStringArray) -> String:
	var unique: PackedStringArray = PackedStringArray()
	for line in lines:
		if line.is_empty() or unique.has(line):
			continue
		unique.append(line)
	return "\n".join(unique)


func hide_summary() -> void:
	visible = false
	if _intro != null and _intro.is_valid():
		_intro.kill()
	if _panel != null:
		_panel.modulate.a = 1.0
		_panel.scale = Vector2.ONE
	if _dim != null:
		_dim.modulate.a = 1.0
	if _pay != null:
		_pay.scale = Vector2.ONE
	if _tip != null:
		_tip.visible = false
		_tip_wrap.visible = false
		_tip.text = ""


func _place_nav_marks() -> void:
	## Re-centring changes a button's minimum width, which can fire `resized`
	## again; the guard keeps that from re-entering.
	if _placing_marks:
		return
	_placing_marks = true
	for raw in [_museum_btn, _shop_btn]:
		var btn: Button = raw as Button
		if btn == null:
			continue
		var mark: Control = btn.get_node_or_null("ActionMark") as Control
		if mark == null:
			continue
		Ui.place_icon_left_of_label(btn, mark)
		_center_glyph_and_word(btn, mark)
	_placing_marks = false


## Centre the glyph and the word as one group in the button (the glyph still
## sits left of the word with the shared 8px gap).
func _center_glyph_and_word(btn: Button, mark: Control) -> void:
	var font: Font = btn.get_theme_font("font")
	var sized: int = btn.get_theme_font_size("font_size")
	if font == null:
		return
	var text_w: float = font.get_string_size(btn.text, HORIZONTAL_ALIGNMENT_LEFT, -1, sized).x
	var group_w: float = mark.size.x + Ui.ICON_GAP + text_w
	var start: float = maxf((btn.size.x - group_w) * 0.5, 12.0)
	var pad_l: float = start + mark.size.x + Ui.ICON_GAP
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var box: StyleBox = btn.get_theme_stylebox(state)
		if box != null:
			box.content_margin_left = pad_l
	mark.position.x = start


func _small_nav(text: String, cb: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size.y = 42
	button.clip_text = false
	Ui.apply_button(button)
	button.pressed.connect(func() -> void:
		Sfx.play("ui")
		cb.call()
	)
	button.resized.connect(_place_nav_marks)
	var glyph: String = ShopIcon.glyph_for_action(text)
	if not glyph.is_empty():
		var mark: Control = ShopIcon.new()
		mark.name = "ActionMark"
		ShopIcon.apply_action(mark)
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if mark.has_method("setup"):
			mark.setup(glyph, Ui.GOLD)
		button.add_child(mark)
	return button


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ENTER or event.physical_keycode == KEY_SPACE:
			_on_dig_again()
			get_viewport().set_input_as_handled()


func _on_dig_again() -> void:
	Sfx.play("ui")
	dig_again.emit()
