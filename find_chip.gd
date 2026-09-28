class_name FindChip
extends Panel

const Ui := preload("res://ui_style.gd")
const ArtCatalogScript := preload("res://art_catalog.gd")
const FossilDataScript := preload("res://fossil_data.gd")
const StarRating := preload("res://star_rating.gd")

var _icon: Control
var _name_label: Label
var _grade_row: VBoxContainer
var _grade_label: Label
var _stars: Control
var _status_label: Label
var _price_label: Label
var _data: FossilDataScript
var _piece_id: String = ""
var _index: int = 0
var _status: String = "underground"
var _card: Dictionary = {}
var _extra: String = ""
var _pop: float = 0.0
var _lit: float = 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(232, 70)
	clip_contents = true
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 8
	row.offset_right = -8
	row.offset_top = 5
	row.offset_bottom = -5
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	_icon = Control.new()
	_icon.custom_minimum_size = Vector2(36, 36)
	_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.draw.connect(_draw_icon)
	row.add_child(_icon)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.clip_contents = true
	col.add_theme_constant_override("separation", 0)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	_name_label = Label.new()
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_name_label.max_lines_visible = 2
	_name_label.clip_text = false
	_name_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	_name_label.add_theme_constant_override("line_spacing", -2)
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Ui.apply_label(_name_label, 16, Ui.GOLD)
	col.add_child(_name_label)
	_grade_row = VBoxContainer.new()
	_grade_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_grade_row.add_theme_constant_override("separation", 0)
	_grade_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grade_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_grade_row)
	_grade_label = Label.new()
	_grade_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grade_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_grade_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grade_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_grade_label.clip_text = false
	_grade_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	Ui.apply_label(_grade_label, 12, Ui.MUTED)
	_grade_row.add_child(_grade_label)
	_stars = Control.new()
	_stars.set_script(StarRating)
	_stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stars.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_stars.custom_minimum_size = Vector2(46, 8)
	_stars.visible = false
	_grade_row.add_child(_stars)
	_status_label = Label.new()
	_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_status_label.clip_text = false
	_status_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	Ui.apply_label(_status_label, 12, Ui.MUTED)
	col.add_child(_status_label)
	_price_label = Label.new()
	_price_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_price_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_price_label.size_flags_horizontal = Control.SIZE_SHRINK_END
	_price_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_price_label.custom_minimum_size = Vector2(50, 28)
	_price_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_price_label.clip_text = false
	_price_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	Ui.apply_label(_price_label, 12, Ui.GOLD)
	row.add_child(_price_label)
	_refresh_chrome()


func apply_card(card: Dictionary) -> void:
	var was_named: bool = bool(_card.get("extracted", false)) or bool(_card.get("fully_exposed", false)) or _status == "bagged" or _status == "brush"
	_card = card
	_index = int(card.get("index", 0))
	_piece_id = str(card.get("piece_id", ""))
	_status = str(card.get("status", "underground"))
	var find_name: String = str(card.get("name", "")).strip_edges()
	var named: bool = bool(card.get("extracted", false)) or bool(card.get("fully_exposed", false)) or _status == "bagged" or _status == "brush"
	if named and not find_name.is_empty() and find_name != "Bone":
		_name_label.text = find_name
	else:
		_name_label.text = "Bone"
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
	_apply_stat_lines()
	_refresh_chrome()
	if _icon != null:
		_icon.queue_redraw()


func set_extra(_text: String) -> void:
	_extra = ""
	_apply_stat_lines()


func fit_tray(width: float, crowded: bool) -> void:
	var w: float = maxf(90.0, width)
	var tight: bool = w < 140.0
	var compact: bool = crowded or w < 200.0
	custom_minimum_size = Vector2(w, 64.0 if tight else 70.0)
	size = custom_minimum_size
	var name_size: int = 11 if tight else (13 if compact else 16)
	var meta_size: int = 10 if tight else (11 if compact else 12)
	var price_size: int = 10 if tight else (11 if compact else 12)
	Ui.apply_label(_name_label, name_size, Ui.GOLD)
	Ui.apply_label(_grade_label, meta_size, Ui.MUTED)
	Ui.apply_label(_status_label, meta_size, Ui.MUTED)
	Ui.apply_label(_price_label, price_size, Ui.GOLD)
	_price_label.custom_minimum_size = Vector2(28 if tight else (36 if compact else 50), 24 if tight else 28)
	if _stars != null:
		_stars.custom_minimum_size = Vector2(40.0 if compact else 46.0, 7.0 if compact else 8.0)
	if _icon != null:
		var icon_s: float = 22.0 if tight else (28.0 if compact else 36.0)
		_icon.custom_minimum_size = Vector2(icon_s, icon_s)
	if tight:
		_grade_row.visible = false
		_status_label.visible = false
	else:
		_grade_row.visible = not _grade_label.text.is_empty() or (_stars != null and _stars.visible)
		_status_label.visible = not _status_label.text.is_empty()


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


func _apply_stat_lines() -> void:
	_grade_label.text = _condition_line(_card)
	_status_label.text = _meter_line(_card)
	_price_label.text = _price_text(_card)
	var stars: int = int(_card.get("stars", 0))
	var show_stars: bool = stars > 0 and _status != "underground"
	if _stars != null and _stars.has_method("set_rating"):
		_stars.call("set_rating", stars)
	if _stars != null:
		_stars.visible = show_stars
	_grade_label.visible = not _grade_label.text.is_empty()
	_grade_row.visible = _grade_label.visible or show_stars
	_status_label.visible = not _status_label.text.is_empty()
	_price_label.visible = not _price_label.text.is_empty()


func _condition_line(card: Dictionary) -> String:
	var grade: String = str(card.get("grade", "")).strip_edges()
	if not grade.is_empty():
		return grade
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
		return "%s · crumbles in %ds" % [str(card.get("kind_name", "Fragile")), int(ceil(left))]
	if bool(card.get("cast", false)):
		return "In a plaster cast"
	if _status == "bagged" or bool(card.get("extracted", false)):
		var fate: String = str(card.get("fate", "")).strip_edges()
		if not fate.is_empty():
			return fate
	var progress: String = str(card.get("progress", "")).strip_edges()
	if not progress.is_empty() and (bool(card.get("fully_exposed", false)) or _status == "brush"):
		return progress
	return _tidy_dirt(str(card.get("dirt", "")))


func _price_text(card: Dictionary) -> String:
	var value: int = int(card.get("value", 0))
	if value > 0 and _status != "underground":
		return "$%d" % value
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
		return
	var color := Color("8A7355").lerp(Color("F7E9C6"), clampf(_lit, 0.0, 1.0))
	if _status == "underground":
		color = Color("5A4330")
	if _data != null:
		_data.draw_silhouette(_icon, dest.grow(-1.0), color)


func _process(delta: float) -> void:
	if _pop <= 0.0:
		return
	_pop = maxf(0.0, _pop - delta * 2.8)
	_refresh_chrome()
