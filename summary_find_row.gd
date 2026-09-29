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
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
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
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		Ui.apply_label(label, 11, Ui.MUTED)
		head.add_child(label)
	return head


## Left edge that centres something `content_w` wide in a column `cell_w` wide.
static func centered_x(cell_w: float, content_w: float) -> float:
	return maxf((cell_w - content_w) * 0.5, 0.0)


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
	## Stars, and the condition word centred under them; the pair is centred in
	## the column both ways.
	var font: Font = Ui.display_font()
	var r: float = 7.0
	var step: float = 17.0
	var stars_w: float = step * 4.0 + r * 2.0
	var word: String = Tuning.condition_name(condition) if condition > 0 else ""
	var word_size: int = 11
	var gap: float = 3.0 if not word.is_empty() else 0.0
	var word_h: float = font.get_height(word_size) if not word.is_empty() else 0.0
	var block_h: float = r * 2.0 + gap + word_h
	var y0: float = maxf((cell.size.y - block_h) * 0.5, 0.0)
	var x0: float = centered_x(cell.size.x, stars_w) + r
	for i in 5:
		var pts: PackedVector2Array = _star_points(Vector2(x0 + step * float(i), y0 + r), r)
		if i < condition:
			cell.draw_colored_polygon(pts, Ui.GOLD)
		else:
			var closed: PackedVector2Array = pts.duplicate()
			closed.append(pts[0])
			cell.draw_polyline(closed, Color("6A523C"), 1.3)
	if not word.is_empty():
		var tw: float = font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, word_size).x
		cell.draw_string(font, Vector2(centered_x(cell.size.x, tw), y0 + r * 2.0 + gap + font.get_ascent(word_size)), word, HORIZONTAL_ALIGNMENT_LEFT, -1, word_size, Ui.MUTED)


func _draw_dirt(cell: Control) -> void:
	## The four-step meter with its word centred under it, centred in the column.
	var font: Font = Ui.display_font()
	var level: int = dirt_level(cleanliness)
	var tint: Color = StarTipScript.dirt_color(cleanliness)
	var seg_w: float = 15.0
	var seg_h: float = 9.0
	var gap: float = 3.0
	var meter_w: float = seg_w * 4.0 + gap * 3.0
	var word: String = StarTipScript.dirt_word(cleanliness)
	var word_size: int = 12
	var word_h: float = font.get_height(word_size)
	var block_h: float = seg_h + 4.0 + word_h
	var y0: float = maxf((cell.size.y - block_h) * 0.5, 0.0)
	var x0: float = centered_x(cell.size.x, meter_w)
	for i in 4:
		var rect := Rect2(x0 + (seg_w + gap) * float(i), y0, seg_w, seg_h)
		if i <= level:
			cell.draw_rect(rect, tint)
		else:
			cell.draw_rect(rect, Color("2E241A"))
			cell.draw_rect(rect, Color("5A4632"), false, 1.0)
	var tw: float = font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, word_size).x
	cell.draw_string(font, Vector2(centered_x(cell.size.x, tw), y0 + seg_h + 4.0 + font.get_ascent(word_size)), word, HORIZONTAL_ALIGNMENT_LEFT, -1, word_size, tint)


func _draw_status(cell: Control) -> void:
	## NEW / DUPLICATE / UPGRADE, centred in the column. Only the Dinosaur column
	## shows a count, so a row never has two different denominators.
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
	var font: Font = Ui.display_font()
	var text_size: int = 12
	var tw: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size).x
	var w: float = minf(tw + 20.0, cell.size.x)
	var h: float = 20.0
	var rect := Rect2(centered_x(cell.size.x, w), maxf((cell.size.y - h) * 0.5, 0.0), w, h)
	var box := StyleBoxFlat.new()
	box.bg_color = back
	box.border_color = ink.darkened(0.35)
	box.set_border_width_all(1)
	box.set_corner_radius_all(10)
	cell.draw_style_box(box, rect)
	var baseline: float = rect.position.y + (h - font.get_height(text_size)) * 0.5 + font.get_ascent(text_size)
	cell.draw_string(font, Vector2(rect.position.x + (w - tw) * 0.5, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size, ink)


func _draw_dino(cell: Control) -> void:
	## Like the other columns: the visual on top, the label centred under it. The
	## bar itself is centred in the column (so the heading, the bar and the name
	## share one centre); its count hangs off the right of the bar.
	if stand_need <= 0:
		return
	var font: Font = Ui.display_font()
	var size: int = 12
	var line_h: float = font.get_height(size)
	var gap: float = 3.0
	var block_h: float = line_h + gap + line_h
	var y0: float = maxf((cell.size.y - block_h) * 0.5, 0.0)
	var count: String = "%d/%d" % [stand_have, stand_need]
	var bar_w: float = 76.0
	var bar_h: float = 7.0
	var bar := Rect2(centered_x(cell.size.x, bar_w), y0 + (line_h - bar_h) * 0.5, bar_w, bar_h)
	cell.draw_rect(bar, Color("2E241A"))
	var frac: float = clampf(float(stand_have) / float(maxi(stand_need, 1)), 0.0, 1.0)
	var done: bool = stand_have >= stand_need
	cell.draw_rect(Rect2(bar.position, Vector2(bar.size.x * frac, bar.size.y)), Color("A8E07A") if done else Ui.GOLD)
	cell.draw_rect(bar, Color("5A4632"), false, 1.0)
	cell.draw_string(font, Vector2(bar.end.x + 6.0, y0 + font.get_ascent(size)), count, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Ui.INK)
	## The name sits under the bar, centred on the column (and so on the bar).
	## "3/11" alone reads like the status column's "3/4" (copies of this one bone), so the label says what is counted.
	var caption: String = "%s bones" % stand_title
	var name_w: float = font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var name_x: float = centered_x(cell.size.x, name_w)
	cell.draw_string(font, Vector2(name_x, y0 + line_h + gap + font.get_ascent(size)), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Ui.MUTED)
