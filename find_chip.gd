class_name FindChip
extends Panel

## One card in the Finds tray. Laid out by hand (not nested containers) so
## text never spills past the card at any tray width:
##   [#n marker + bone icon] [name / stars+condition / status tag] [price]
##   [brushing progress bar along the bottom edge]
## The numbered color marker matches the one drawn on the bone in the pit.

const Ui := preload("res://ui_style.gd")
const ArtCatalogScript := preload("res://art_catalog.gd")
const FossilDataScript := preload("res://fossil_data.gd")
const StarRating := preload("res://star_rating.gd")

## Shared with the pit so card N and bone N wear the same color.
const FIND_COLORS: PackedColorArray = [
	Color("FF8A65"),
	Color("4DD0C8"),
	Color("B39DDB"),
	Color("AED581"),
	Color("FFD54F"),
	Color("64B5F6"),
]
const PAD := 8.0
const BAR_H := 6.0

var _icon: Control
var _marker: Control
var _name_label: Label
var _grade_row: HBoxContainer
var _grade_label: Label
var _stars: Control
var _status_label: Label
var _price_label: Label
var _note_label: Label
var _bar: Control
var _data: FossilDataScript
var _piece_id: String = ""
var _index: int = 0
var _status: String = "underground"
var _card: Dictionary = {}
var _extra: String = ""
var _pop: float = 0.0
var _lit: float = 0.0
var _name_size: int = 16
var _meta_size: int = 12
var _price_size: int = 15
var _tight: bool = false
var _clean_shown: float = 0.0
var _bar_flash: float = 0.0


static func color_for(index: int) -> Color:
	return FIND_COLORS[posmod(index, FIND_COLORS.size())]


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(232, 70)
	clip_contents = true
	_icon = Control.new()
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.draw.connect(_draw_icon)
	add_child(_icon)
	_marker = Control.new()
	_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marker.draw.connect(_draw_marker)
	add_child(_marker)
	_name_label = _make_label(HORIZONTAL_ALIGNMENT_CENTER)
	## Names shrink to fit instead of trimming with "...".
	_name_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	_grade_row = HBoxContainer.new()
	_grade_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grade_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_grade_row.add_theme_constant_override("separation", 5)
	add_child(_grade_row)
	_stars = Control.new()
	_stars.set_script(StarRating)
	_stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stars.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_stars.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_stars.custom_minimum_size = Vector2(46, 8)
	_stars.visible = false
	_grade_row.add_child(_stars)
	_grade_label = Label.new()
	_grade_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grade_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_grade_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_grade_row.add_child(_grade_label)
	_status_label = _make_label(HORIZONTAL_ALIGNMENT_CENTER)
	_price_label = _make_label(HORIZONTAL_ALIGNMENT_RIGHT)
	_price_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_note_label = _make_label(HORIZONTAL_ALIGNMENT_CENTER)
	_note_label.visible = false
	_bar = Control.new()
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.draw.connect(_draw_bar)
	add_child(_bar)
	resized.connect(_layout)
	_apply_fonts()
	_refresh_chrome()


func _make_label(align: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.max_lines_visible = 1
	add_child(label)
	return label


func apply_card(card: Dictionary) -> void:
	var was_named: bool = bool(_card.get("extracted", false)) or bool(_card.get("fully_exposed", false)) or _status == "bagged" or _status == "brush"
	_card = card
	_index = int(card.get("index", 0))
	_piece_id = str(card.get("piece_id", ""))
	_status = str(card.get("status", "underground"))
	var find_name: String = str(card.get("name", "")).strip_edges()
	var named: bool = bool(card.get("extracted", false)) or bool(card.get("fully_exposed", false)) or _status == "bagged" or _status == "brush"
	_name_label.text = find_name if named and not find_name.is_empty() and find_name != "Bone" else "Bone"
	if named and not was_named:
		light_up()
	var raw: Variant = card.get("data", null)
	if raw is FossilDataScript:
		_data = raw as FossilDataScript
	else:
		_data = FossilDataScript.new()
		_data.name = find_name
		_data.piece_id = _piece_id
	if _piece_id.is_empty() and _data != null:
		_piece_id = _data.piece_id if _data.piece_id != "" else _data.name.to_snake_case()
	if bool(card.get("extracted", false)) or _status == "bagged":
		_lit = maxf(_lit, 0.55)
	var clean: float = _brush_progress()
	if clean > _clean_shown + 0.001:
		_bar_flash = 1.0
	_clean_shown = clean
	_apply_stat_lines()
	_refresh_chrome()
	_layout()
	_icon.queue_redraw()
	_marker.queue_redraw()
	_bar.queue_redraw()


func set_extra(_text: String) -> void:
	_extra = ""
	_apply_stat_lines()


func fit_tray(width: float, crowded: bool) -> void:
	var w: float = maxf(90.0, width)
	_tight = w < 140.0
	var compact: bool = crowded or w < 200.0
	custom_minimum_size = Vector2(w, 64.0 if _tight else 70.0)
	size = custom_minimum_size
	_name_size = 11 if _tight else (13 if compact else 16)
	_meta_size = 10 if _tight else (11 if compact else 12)
	_price_size = 11 if _tight else (13 if compact else 15)
	## StarRating resets its own size on _ready; pin the caption size here.
	_stars.custom_minimum_size = Vector2(40.0 if compact else 46.0, 7.0 if compact else 8.0)
	_apply_fonts()
	_layout()


func _apply_fonts() -> void:
	Ui.apply_label(_name_label, _name_size, Ui.GOLD)
	Ui.apply_label(_grade_label, _meta_size, Ui.INK)
	Ui.apply_label(_status_label, _meta_size, Ui.MUTED)
	## The name always leads; the price stays one size under it.
	Ui.apply_label(_price_label, mini(_price_size, _name_size - 1), Ui.GOLD)
	Ui.apply_label(_note_label, maxi(_meta_size - 1, 9), Color("F4F0E6"))
	_status_label.add_theme_color_override("font_color", _status_color(_status_label.text))


func light_up() -> void:
	_pop = 1.0
	_lit = 1.0
	_refresh_chrome()
	if _icon != null:
		_icon.queue_redraw()


func catch_pos() -> Vector2:
	if _icon != null:
		return _icon.global_position + _icon.size * 0.5
	return global_position + size * 0.5


func _layout() -> void:
	## Explicit rects: icon | text column | price, with the bar underneath.
	var w: float = maxf(size.x, custom_minimum_size.x)
	var h: float = maxf(size.y, custom_minimum_size.y)
	var body_h: float = h - BAR_H
	var icon_s: float = clampf(body_h - PAD * 2.0, 18.0, 40.0)
	if _tight:
		icon_s = 22.0
	_icon.position = Vector2(PAD, (body_h - icon_s) * 0.5)
	_icon.size = Vector2(icon_s, icon_s)
	_marker.position = Vector2(2.0, 2.0)
	_marker.size = Vector2(18.0, 18.0)
	var price_w: float = 0.0
	if _price_label.visible and not _price_label.text.is_empty():
		var font: Font = Ui.display_font()
		price_w = font.get_string_size(_price_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, _price_label.get_theme_font_size("font_size")).x + 6.0
	var right: float = w - PAD - price_w
	var left: float = _icon.position.x + icon_s + 6.0
	var col_w: float = maxf(right - left - 4.0, 20.0)
	_price_label.position = Vector2(right, 0.0)
	_price_label.size = Vector2(price_w, body_h)
	var line_h: float = float(_meta_size) + 5.0
	var name_h: float = float(_name_size) + 5.0
	var rows: Array = [_name_label]
	if _grade_row.visible:
		rows.append(_grade_row)
	if _status_label.visible:
		rows.append(_status_label)
	if _note_label.visible and not _tight:
		rows.append(_note_label)
	_fit_name(col_w)
	var total: float = 0.0
	for row in rows:
		total += name_h if row == _name_label else line_h
	var y: float = maxf(2.0, (body_h - total) * 0.5)
	for row in rows:
		var rh: float = name_h if row == _name_label else line_h
		var ctrl: Control = row
		ctrl.position = Vector2(left, y)
		ctrl.size = Vector2(col_w, rh)
		y += rh
	_grade_row.custom_minimum_size = Vector2(0, 0)
	_bar.position = Vector2(0.0, h - BAR_H)
	_bar.size = Vector2(w, BAR_H)


func _fit_name(room: float) -> void:
	var font: Font = Ui.display_font()
	var fs: int = _name_size
	while fs > 9 and font.get_string_size(_name_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > room:
		fs -= 1
	if _name_label.get_theme_font_size("font_size") != fs:
		_name_label.add_theme_font_size_override("font_size", fs)
	var price_px: int = _price_label.get_theme_font_size("font_size")
	if price_px >= fs:
		_price_label.add_theme_font_size_override("font_size", maxi(9, fs - 1))


func _apply_stat_lines() -> void:
	if _stars.custom_minimum_size.x > 48.0:
		_stars.custom_minimum_size = Vector2(46, 8)
	_grade_label.text = _condition_line(_card)
	_status_label.text = _meter_line(_card)
	var note: String = _note_line(_card)
	_note_label.text = note
	_note_label.visible = not note.is_empty()
	_price_label.text = _price_text(_card)
	var stars: int = int(_card.get("stars", 0))
	var show_stars: bool = stars > 0 and _status != "underground"
	if _stars.has_method("set_rating"):
		_stars.call("set_rating", stars)
	_stars.visible = show_stars
	_grade_label.visible = not _grade_label.text.is_empty()
	_grade_row.visible = (_grade_label.visible or show_stars) and not _tight
	_status_label.visible = not _status_label.text.is_empty() and not _tight
	_price_label.visible = not _price_label.text.is_empty()
	_apply_fonts()


func _condition_line(card: Dictionary) -> String:
	var grade: String = str(card.get("grade", "")).strip_edges()
	if not grade.is_empty():
		var lost: int = int(card.get("crumbled", 0))
		var cond: int = int(card.get("condition", 0))
		if lost > 0 and cond > 0:
			## Show what open air cost, so the reason for the stars is visible.
			return "%s (was %s)" % [Tuning.condition_name(cond), Tuning.condition_name(cond + lost)]
		## Stars sit right beside it, so "Great condition" reads as just "Great".
		return grade.trim_suffix(" condition")
	match _status:
		"bagged":
			return "Bagged"
		"brush":
			return "Brush"
		"uncovering":
			return "Uncovering"
		"underground":
			return ""
		_:
			if not _status.is_empty():
				return _status.capitalize()
	return ""


func _meter_line(card: Dictionary) -> String:
	var left: float = float(card.get("crumble_in", INF))
	if left != INF and not bool(card.get("extracted", false)):
		return "%s · -1 star in %ds" % [str(card.get("kind_name", "Fragile")), int(ceil(left))]
	if _status == "bagged" or bool(card.get("extracted", false)):
		var fate: String = str(card.get("fate", "")).strip_edges()
		if not fate.is_empty():
			return _museum_line(fate)
	var progress: String = str(card.get("progress", "")).strip_edges()
	if not progress.is_empty() and (bool(card.get("fully_exposed", false)) or _status == "brush"):
		return _museum_line(progress)
	return _tidy_dirt(str(card.get("dirt", "")))


## Short, plain words for what this bone means for the museum.
func _museum_line(line: String) -> String:
	if line.begins_with("New ·"):
		return "New for museum · %s" % line.substr(6).strip_edges()
	if line.begins_with("Duplicate"):
		return "Duplicate · sells"
	if line.begins_with("Upgrade"):
		return "Upgrades exhibit!"
	return line


func _status_color(line: String) -> Color:
	if line.begins_with("New"):
		return Color("A8E07A")
	if line.begins_with("Upgrade"):
		return Ui.GOLD
	if line.contains("-1 star"):
		return Color("FF9A7A")
	return Ui.MUTED


## Plaster only matters for bones that crumble: say what it did.
func _note_line(card: Dictionary) -> String:
	if bool(card.get("cast", false)) and Tuning.bone_crumbles(int(card.get("kind", 0))):
		return "Plaster stopped it losing stars"
	return ""


func _price_text(card: Dictionary) -> String:
	var value: int = int(card.get("value", 0))
	if value > 0 and _status != "underground":
		return Ui.money_text(value)
	return ""


func _tidy_dirt(dirt: String) -> String:
	var compact: String = dirt.strip_edges()
	while compact.find("  ") >= 0:
		compact = compact.replace("  ", " ")
	var lower: String = compact.to_lower()
	if lower == "clean":
		return "Brushed 100%"
	if lower.begins_with("dust"):
		return "Brushed %d%%" % clampi(100 - _percent_in(compact), 0, 100)
	if lower.begins_with("brushed"):
		return "Brushed %d%%" % _percent_in(compact)
	return compact


func _percent_in(text: String) -> int:
	var digits := ""
	for i in text.length():
		var ch: String = text.substr(i, 1)
		if ch >= "0" and ch <= "9":
			digits += ch
	if digits.is_empty():
		return 0
	return clampi(int(digits), 0, 100)


func _brush_progress() -> float:
	if _card.has("clean"):
		return clampf(float(_card.get("clean", 0.0)), 0.0, 1.0)
	var dirt: String = str(_card.get("dirt", ""))
	if dirt.strip_edges().is_empty():
		return 1.0 if _status == "bagged" else 0.0
	return float(_percent_in(_tidy_dirt(dirt))) / 100.0


func _refresh_chrome() -> void:
	add_theme_stylebox_override("panel", Ui.chip_box(_brush_progress()))
	modulate = Color.WHITE.lerp(Color("FFE08A"), clampf(_pop, 0.0, 1.0) * 0.35)


func _draw_icon() -> void:
	if _icon == null:
		return
	var dest := Rect2(Vector2.ZERO, _icon.size)
	if dest.size.x < 2.0 or dest.size.y < 2.0:
		return
	if _piece_id != "" and ArtCatalogScript.draw_if_present(_icon, "bones", _piece_id, dest):
		_draw_cast_band(dest)
		return
	var color := Color("8A7355").lerp(Color("F7E9C6"), clampf(_lit, 0.0, 1.0))
	if _status == "underground":
		color = Color("5A4330")
	if _data != null:
		_data.draw_silhouette(_icon, dest.grow(-1.0), color)
	_draw_cast_band(dest)


func _draw_cast_band(dest: Rect2) -> void:
	## A white plaster band across the icon marks a wrapped bone.
	if not bool(_card.get("cast", false)):
		return
	var band := Rect2(dest.position.x, dest.get_center().y - dest.size.y * 0.14, dest.size.x, dest.size.y * 0.28)
	_icon.draw_rect(band, Color("F4F0E6", 0.9))
	_icon.draw_line(band.position + Vector2(band.size.x * 0.3, 0), band.position + Vector2(band.size.x * 0.4, band.size.y), Color("C9C0B0"), 1.5)
	_icon.draw_line(band.position + Vector2(band.size.x * 0.6, 0), band.position + Vector2(band.size.x * 0.7, band.size.y), Color("C9C0B0"), 1.5)


func _draw_marker() -> void:
	## Numbered color dot that matches the marker on this bone in the pit.
	var c: Vector2 = _marker.size * 0.5
	var r: float = minf(c.x, c.y)
	var col: Color = color_for(_index)
	_marker.draw_circle(c, r, col)
	_marker.draw_arc(c, r, 0.0, TAU, 20, Color("1B1410"), 1.5)
	var font: Font = Ui.display_font()
	var text: String = str(_index + 1)
	var fs: int = 11
	var tw: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	_marker.draw_string(font, c + Vector2(-tw * 0.5, fs * 0.38), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("1B1410"))


func _draw_bar() -> void:
	## Live brushing progress along the card's bottom edge: bright enough to
	## read from the corner of your eye while you brush in the pit.
	var rect := Rect2(Vector2.ZERO, _bar.size)
	_bar.draw_rect(rect, Color(0.08, 0.05, 0.03, 0.9))
	if _status == "underground":
		return
	var t: float = _clean_shown
	var done: bool = t >= 0.995 or _status == "bagged"
	var fill: Color = Color("B07A3A").lerp(Color("FFD66B"), t)
	if done:
		fill = Color("A8E07A")
	fill = fill.lerp(Color.WHITE, _bar_flash * 0.5)
	_bar.draw_rect(Rect2(rect.position, Vector2(rect.size.x * (1.0 if done else t), rect.size.y)), fill)


func _process(delta: float) -> void:
	if _pop > 0.0:
		_pop = maxf(0.0, _pop - delta * 2.8)
		_refresh_chrome()
	if _bar_flash > 0.0:
		_bar_flash = maxf(0.0, _bar_flash - delta * 3.0)
		_bar.queue_redraw()
