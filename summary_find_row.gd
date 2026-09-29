class_name SummaryFindRow
extends Control

## One extracted bone on the shift-over card, laid out as table columns:
## icon | name | condition (stars) | cleanliness (4-step meter) | status | dinosaur.
## The column widths are shared with the header from make_header().

const Ui := preload("res://ui_style.gd")
const ArtCatalogScript := preload("res://art_catalog.gd")
const FossilDataScript := preload("res://fossil_data.gd")
const StarTipScript := preload("res://star_tip.gd")

const COL_ICON := 44.0
const COL_NAME := 200.0
const COL_COND := 100.0
const COL_DIRT := 132.0
const COL_STATUS := 104.0
const COL_DINO := 150.0
const GAP := 8.0
const ROW_H := 42.0
const ROW_W := COL_ICON + COL_NAME + COL_COND + COL_DIRT + COL_STATUS + COL_DINO + GAP * 5.0

const STATUS_NEW := "new"
const STATUS_DUPLICATE := "duplicate"
const STATUS_UPGRADE := "upgrade"

var _icon: Control
var _label: Label
var _cond: Control
var _dirt: Control
var _status_cell: Control
var _dino: Control
var _piece_id: String = ""
var _data: FossilDataScript

## What the row shows (also readable by tests).
var condition: int = 0
var cleanliness: float = 1.0
var status: String = ""
var set_text: String = ""
var stand_title: String = ""
var stand_have: int = 0
var stand_need: int = 0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(ROW_W, ROW_H)
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", int(GAP))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	_icon = Control.new()
	_icon.custom_minimum_size = Vector2(COL_ICON, ROW_H - 6.0)
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.draw.connect(_draw_icon)
	row.add_child(_icon)
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_label.custom_minimum_size = Vector2(COL_NAME, 0)
	Ui.apply_label(_label, 16, Ui.INK)
	row.add_child(_label)
	_cond = _cell(row, COL_COND, _draw_condition)
	_dirt = _cell(row, COL_DIRT, _draw_dirt)
	_status_cell = _cell(row, COL_STATUS, _draw_status)
	_dino = _cell(row, COL_DINO, _draw_dino)


func _cell(row: Control, width: float, painter: Callable) -> Control:
	var cell := Control.new()
	cell.custom_minimum_size = Vector2(width, ROW_H - 6.0)
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.draw.connect(painter.bind(cell))
	row.add_child(cell)
	return cell


## The column captions above the rows, aligned with the cells.
static func make_header() -> Control:
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_theme_constant_override("separation", int(GAP))
	head.custom_minimum_size = Vector2(ROW_W, 18.0)
	var captions := [["", COL_ICON], ["BONE", COL_NAME], ["CONDITION", COL_COND], ["CLEANLINESS", COL_DIRT], ["STATUS", COL_STATUS], ["DINOSAUR", COL_DINO]]
	for pair in captions:
		var label := Label.new()
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.text = str(pair[0])
		label.custom_minimum_size = Vector2(float(pair[1]), 0)
		label.clip_text = false
		Ui.apply_label(label, 11, Ui.MUTED)
		head.add_child(label)
	return head


## 0 Caked, 1 Dirty, 2 Dusty, 3 Clean: the same words and edges as the museum card.
static func dirt_level(clean_pct: float) -> int:
	if clean_pct >= 0.96:
		return 3
	if clean_pct >= 0.6:
		return 2
	if clean_pct >= 0.25:
		return 1
	return 0


func apply_find(entry: Dictionary) -> void:
	var find_name: String = str(entry.get("name", ""))
	_piece_id = str(entry.get("piece_id", ""))
	_label.text = find_name
	var fate: String = str(entry.get("fate", ""))
	condition = clampi(int(entry.get("condition", entry.get("stars", 0))), 0, 5)
	var dirt_tag: String = str(entry.get("dirt", ""))
	cleanliness = clampf(float(entry.get("cleanliness", 1.0 if dirt_tag.is_empty() else 0.5)), 0.0, 1.0)
	status = str(entry.get("status", _status_from_fate(fate)))
	set_text = str(entry.get("set_text", _set_from_fate(fate)))
	stand_title = str(entry.get("stand_title", ""))
	stand_have = int(entry.get("stand_have", 0))
	stand_need = int(entry.get("stand_need", 0))
	var raw: Variant = entry.get("data", null)
	if raw is FossilDataScript:
		_data = raw as FossilDataScript
	elif not _piece_id.is_empty():
		_data = GameState.fossil_data_for(_piece_id)
	if _data == null:
		_data = FossilDataScript.new()
		_data.name = find_name
		_data.piece_id = _piece_id
	if _piece_id.is_empty() and _data != null:
		_piece_id = _data.piece_id if _data.piece_id != "" else _data.name.to_snake_case()
	for cell in [_icon, _cond, _dirt, _status_cell, _dino]:
		if cell != null:
			(cell as Control).queue_redraw()


static func _status_from_fate(fate: String) -> String:
	var lower: String = fate.to_lower()
	if lower.begins_with("upgrade"):
		return STATUS_UPGRADE
	if lower.begins_with("duplicate") or lower.find("sold") >= 0:
		return STATUS_DUPLICATE
	if lower.begins_with("new"):
		return STATUS_NEW
	return ""


static func _set_from_fate(fate: String) -> String:
	var found: RegEx = RegEx.create_from_string("(\\d+)\\s*/\\s*(\\d+)")
	var hit: RegExMatch = found.search(fate)
	if hit == null:
		return ""
	return "%s/%s" % [hit.get_string(1), hit.get_string(2)]


func _draw_icon() -> void:
	if _icon == null:
		return
	var dest := Rect2(Vector2.ZERO, _icon.size)
	if dest.size.x < 2.0 or dest.size.y < 2.0:
		return
	if _piece_id != "" and ArtCatalogScript.draw_if_present(_icon, "bones", _piece_id, dest):
		return
	var color := Color("F7E9C6")
	if _data != null:
		_data.draw_silhouette(_icon, dest.grow(-1.0), color)


static func _star_points(center: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 10:
		var ang: float = -PI * 0.5 + TAU * float(i) / 10.0
		var rad: float = r if i % 2 == 0 else r * 0.42
		pts.append(center + Vector2(cos(ang), sin(ang)) * rad)
	return pts


func _draw_condition(cell: Control) -> void:
	var r: float = 7.0
	var step: float = 17.0
	var x0: float = r + 2.0
	var y: float = cell.size.y * 0.36
	for i in 5:
		var pts: PackedVector2Array = _star_points(Vector2(x0 + step * float(i), y), r)
		if i < condition:
			cell.draw_colored_polygon(pts, Ui.GOLD)
		else:
			var closed: PackedVector2Array = pts.duplicate()
			closed.append(pts[0])
			cell.draw_polyline(closed, Color("6A523C"), 1.3)
	if condition > 0:
		var font: Font = Ui.display_font()
		cell.draw_string(font, Vector2(2.0, cell.size.y - 3.0), Tuning.condition_name(condition), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Ui.MUTED)


func _draw_dirt(cell: Control) -> void:
	var level: int = dirt_level(cleanliness)
	var tint: Color = StarTipScript.dirt_color(cleanliness)
	var seg_w: float = 15.0
	var seg_h: float = 9.0
	var gap: float = 3.0
	var y: float = cell.size.y * 0.5 - seg_h * 0.5
	for i in 4:
		var rect := Rect2(2.0 + (seg_w + gap) * float(i), y, seg_w, seg_h)
		if i <= level:
			cell.draw_rect(rect, tint)
		else:
			cell.draw_rect(rect, Color("2E241A"))
			cell.draw_rect(rect, Color("5A4632"), false, 1.0)
	var font: Font = Ui.display_font()
	var word: String = StarTipScript.dirt_word(cleanliness)
	cell.draw_string(font, Vector2(2.0 + (seg_w + gap) * 4.0 + 4.0, y + seg_h), word, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, tint)


func _draw_status(cell: Control) -> void:
	if status.is_empty():
		return
	var text: String = "NEW"
	var back := Color("35502A")
	var ink := Color("BDEFA0")
	if status == STATUS_DUPLICATE:
		text = "DUPLICATE"
		back = Color("3F3126")
		ink = Color("C9B8A2")
	elif status == STATUS_UPGRADE:
		text = "UPGRADE"
		back = Color("5A4420")
		ink = Color("FFE08A")
	elif not set_text.is_empty():
		text = "NEW · %s" % set_text
	var font: Font = Ui.display_font()
	var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 18.0
	var h: float = 20.0
	var rect := Rect2(0.0, cell.size.y * 0.5 - h * 0.5, minf(w, cell.size.x), h)
	var box := StyleBoxFlat.new()
	box.bg_color = back
	box.border_color = ink.darkened(0.35)
	box.set_border_width_all(1)
	box.set_corner_radius_all(10)
	cell.draw_style_box(box, rect)
	cell.draw_string(font, Vector2(rect.position.x + 9.0, rect.position.y + 14.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, ink)


func _draw_dino(cell: Control) -> void:
	if stand_need <= 0:
		return
	var font: Font = Ui.display_font()
	cell.draw_string(font, Vector2(2.0, cell.size.y * 0.5 - 1.0), stand_title, HORIZONTAL_ALIGNMENT_LEFT, cell.size.x - 4.0, 12, Ui.MUTED)
	var bar := Rect2(2.0, cell.size.y * 0.5 + 5.0, cell.size.x - 46.0, 7.0)
	cell.draw_rect(bar, Color("2E241A"))
	var frac: float = clampf(float(stand_have) / float(maxi(stand_need, 1)), 0.0, 1.0)
	var done: bool = stand_have >= stand_need
	cell.draw_rect(Rect2(bar.position, Vector2(bar.size.x * frac, bar.size.y)), Color("A8E07A") if done else Ui.GOLD)
	cell.draw_rect(bar, Color("5A4632"), false, 1.0)
	cell.draw_string(font, Vector2(bar.end.x + 6.0, bar.end.y + 1.0), "%d/%d" % [stand_have, stand_need], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Ui.INK)
