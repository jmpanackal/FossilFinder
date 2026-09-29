class_name StarTip
extends Control

## Hover card for a museum stand's stars, built to be read in a second:
##   ★★★★☆  Great
##   Average of 3 found bones: 4.3 → 4 stars
##   Skull  ★★★★★
##   Claw   ★★★★☆
##   Tail   ★★★★☆
##   Leg    ☆☆☆☆☆   (greyed: not found yet, not counted)
##   Masterpiece: every bone at 5 stars (3 to go)

const Ui := preload("res://ui_style.gd")
const PAD := Vector2(14, 10)
const HEAD_H := 30.0
const LINE_H := 20.0
const ROW_H := 18.0
const ROW_FS := 13
const LINE_FS := 13
const MINI_R := 5.5
const COL_GAP := 22.0
const MISSING_INK := Color("8A7A66")

var info: Dictionary = {}
var _bones: Array = []
var _cols: int = 1
var _name_w: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_info(data: Dictionary) -> void:
	info = data
	_bones = info.get("bones", [])
	_cols = 2 if _bones.size() > 6 else 1
	var font: Font = Ui.display_font()
	_name_w = 0.0
	for b in _bones:
		_name_w = maxf(_name_w, font.get_string_size(str(b["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, ROW_FS).x)
	## Width hugs the content: the widest of header, text lines and bone columns.
	var head_w: float = _stars_w(10.0) + 8.0 + font.get_string_size(str(info.get("word", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	var w: float = maxf(head_w, _col_w() * float(_cols) + COL_GAP * float(_cols - 1))
	for line in [_avg_line(), _master_line()]:
		w = maxf(w, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, LINE_FS).x)
	size = Vector2(ceilf(w + PAD.x * 2.0), _height())
	queue_redraw()


func _stars_w(r: float) -> float:
	return r * 2.3 * 5.0


func _col_w() -> float:
	return _name_w + 10.0 + _stars_w(MINI_R)


func _rows() -> int:
	return int(ceil(float(_bones.size()) / float(_cols)))


func _height() -> float:
	return PAD.y * 2.0 + HEAD_H + LINE_H + 6.0 + float(_rows()) * ROW_H + 8.0 + LINE_H + 2.0


func _avg_line() -> String:
	var total: int = int(info.get("total", 0))
	var avg: float = float(info.get("avg", 0.0))
	var stars: int = int(info.get("stars", 0))
	var tail: String = " (rounded down)" if absf(avg - float(stars)) > 0.05 else ""
	return "Average of %d found bone%s: %.1f → %d stars%s" % [total, "" if total == 1 else "s", avg, stars, tail]


func _master_line() -> String:
	var need: int = int(info.get("master_stars", 5))
	if bool(info.get("master", false)):
		return "Masterpiece! Every bone has %d stars" % need
	var to_go: int = 0
	for b in _bones:
		if int(b["cond"]) < need:
			to_go += 1
	return "Masterpiece: all %d bones at %d stars (%d to go)" % [_bones.size(), need, to_go]


func _star(center: Vector2, r: float, on: bool, color: Color = Ui.GOLD) -> void:
	var pts := PackedVector2Array()
	for k in 10:
		var ang: float = -PI * 0.5 + float(k) * PI / 5.0
		var rad: float = r if k % 2 == 0 else r * 0.45
		pts.append(center + Vector2(cos(ang), sin(ang)) * rad)
	if on:
		draw_colored_polygon(pts, color)
	pts.append(pts[0])
	draw_polyline(pts, color if on else Color(color, 0.45), 1.2)


func _stars_row(pos: Vector2, filled: int, r: float, color: Color = Ui.GOLD) -> void:
	var gap: float = r * 2.3
	for i in 5:
		_star(pos + Vector2(r + float(i) * gap, 0.0), r, i < filled, color)


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, Color("2A1D12", 0.97))
	draw_rect(rect, Ui.GOLD, false, 2.0)
	var font: Font = Ui.display_font()
	var need: int = int(info.get("master_stars", 5))
	var y: float = PAD.y + 14.0
	_stars_row(Vector2(PAD.x, y), int(info.get("stars", 0)), 10.0)
	draw_string(font, Vector2(PAD.x + _stars_w(10.0) + 8.0, y + 7.0), str(info.get("word", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Ui.GOLD)
	y += HEAD_H
	draw_string(font, Vector2(PAD.x, y + 4.0), _avg_line(), HORIZONTAL_ALIGNMENT_LEFT, -1, LINE_FS, Ui.INK)
	y += LINE_H - 2.0
	draw_line(Vector2(PAD.x, y), Vector2(size.x - PAD.x, y), Color(Ui.GOLD, 0.25), 1.0)
	y += 8.0
	## One row per bone. Missing bones are greyed with empty stars: they
	## don't count toward the average, but a Masterpiece needs them.
	var rows: int = maxi(_rows(), 1)
	var col_w: float = _col_w()
	for i in _bones.size():
		var b: Dictionary = _bones[i]
		var bx: float = PAD.x + float(i / rows) * (col_w + COL_GAP)
		var by: float = y + float(i % rows) * ROW_H + ROW_H * 0.5
		var cond: int = int(b["cond"])
		var found: bool = cond > 0
		draw_string(font, Vector2(bx, by + 5.0), str(b["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, ROW_FS, Ui.INK if found else MISSING_INK)
		var star_col: Color = (Color("FFD66B") if cond >= need else Ui.GOLD) if found else MISSING_INK
		_stars_row(Vector2(bx + _name_w + 10.0, by), cond, MINI_R, star_col)
	y += float(_rows()) * ROW_H + 8.0
	draw_string(font, Vector2(PAD.x, y + 8.0), _master_line(), HORIZONTAL_ALIGNMENT_LEFT, -1, LINE_FS, Color("FFD66B"))
