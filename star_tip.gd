class_name StarTip
extends Control

## Hover card for a museum stand's stars, built to be read in a second:
##   ★★★★☆  Great
##   Average of 4 bones: 4.3 → 4 stars
##   Skull ★★★★★   Claw ★★★★☆
##   Tail  ★★★★☆   Leg  not found
##   Masterpiece: every bone ★★★★★  (2 to go)

const Ui := preload("res://ui_style.gd")
const PAD := Vector2(14, 10)
const HEAD_H := 30.0
const LINE_H := 20.0
const ROW_H := 18.0
const ROW_FS := 13
const MINI_R := 5.5
const COL_GAP := 18.0

var info: Dictionary = {}
var _cols: int = 1
var _name_w: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_info(data: Dictionary) -> void:
	info = data
	var bones: Array = info.get("bones", [])
	_cols = 2 if bones.size() > 5 else 1
	var font: Font = Ui.display_font()
	_name_w = 0.0
	for b in bones:
		_name_w = maxf(_name_w, font.get_string_size(str(b["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, ROW_FS).x)
	var col_w: float = _col_w()
	var w: float = maxf(300.0, PAD.x * 2.0 + col_w * float(_cols) + COL_GAP * float(_cols - 1))
	for line in [_avg_line(), _master_line(), _raise_line()]:
		w = maxf(w, PAD.x * 2.0 + font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 70.0)
	size = Vector2(w, _height())
	queue_redraw()


func _col_w() -> float:
	## name, gap, five mini stars (or "not found").
	return _name_w + 10.0 + MINI_R * 2.3 * 5.0


func _rows() -> int:
	var n: int = (info.get("bones", []) as Array).size()
	return int(ceil(float(n) / float(_cols)))


func _height() -> float:
	var h: float = PAD.y * 2.0 + HEAD_H + LINE_H + 4.0
	h += float(_rows()) * ROW_H + 18.0
	h += LINE_H
	if not bool(info.get("master", false)) and int(info.get("below", 0)) > 0:
		h += LINE_H
	return h


func _avg_line() -> String:
	var total: int = int(info.get("total", 0))
	return "Average of %d bone%s: %.1f → %d stars" % [total, "" if total == 1 else "s", float(info.get("avg", 0.0)), int(info.get("stars", 0))]


func _master_line() -> String:
	var need: int = int(info.get("master_stars", 5))
	if bool(info.get("master", false)):
		return "Masterpiece! Every bone has %d stars" % need
	var bones: Array = info.get("bones", [])
	var to_go: int = 0
	for b in bones:
		if int(b["cond"]) < need:
			to_go += 1
	return "Masterpiece: every bone at %d stars (%d to go)" % [need, to_go]


func _raise_line() -> String:
	return "Raise: better copies from digs · Repair Workshop (up to 4)"


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


func _stars_row(pos: Vector2, count: int, filled: int, r: float, color: Color = Ui.GOLD) -> float:
	var gap: float = r * 2.3
	for i in count:
		_star(pos + Vector2(r + float(i) * gap, 0.0), r, i < filled, color)
	return float(count) * gap


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, Color("2A1D12", 0.97))
	draw_rect(rect, Ui.GOLD, false, 2.0)
	var font: Font = Ui.display_font()
	var stars: int = int(info.get("stars", 0))
	var need: int = int(info.get("master_stars", 5))
	var y: float = PAD.y + 14.0
	var x: float = PAD.x
	x += _stars_row(Vector2(x, y), 5, stars, 10.0) + 8.0
	draw_string(font, Vector2(x, y + 7.0), str(info.get("word", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Ui.GOLD)
	y += HEAD_H
	draw_string(font, Vector2(PAD.x, y + 4.0), _avg_line(), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Ui.INK)
	y += LINE_H - 2.0
	draw_line(Vector2(PAD.x, y), Vector2(size.x - PAD.x, y), Color(Ui.GOLD, 0.25), 1.0)
	y += 6.0
	## One row per bone: its own stars; missing bones say so and don't count.
	var bones: Array = info.get("bones", [])
	var rows: int = _rows()
	var col_w: float = _col_w()
	for i in bones.size():
		var b: Dictionary = bones[i]
		var col: int = i / rows
		var row: int = i % rows
		var bx: float = PAD.x + float(col) * (col_w + COL_GAP)
		var by: float = y + float(row) * ROW_H + ROW_H * 0.5
		var cond: int = int(b["cond"])
		var name_col: Color = Ui.INK if cond > 0 else Ui.MUTED
		draw_string(font, Vector2(bx, by + 5.0), str(b["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, ROW_FS, name_col)
		var sx: float = bx + _name_w + 10.0
		if cond <= 0:
			draw_string(font, Vector2(sx, by + 4.0), "not found", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Ui.MUTED)
		else:
			## Bones holding back a Masterpiece show in a softer tone.
			var c: Color = Color("FFD66B") if cond >= need else Ui.GOLD
			_stars_row(Vector2(sx, by), 5, cond, MINI_R, c)
	y += float(rows) * ROW_H + 14.0
	var master_col := Color("FFD66B")
	draw_string(font, Vector2(PAD.x, y + 4.0), _master_line(), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, master_col)
	if not bool(info.get("master", false)) and int(info.get("below", 0)) > 0:
		y += LINE_H
		draw_string(font, Vector2(PAD.x, y + 4.0), _raise_line(), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Ui.MUTED)
