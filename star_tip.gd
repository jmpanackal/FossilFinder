class_name StarTip
extends Control

## Hover card for a museum stand's stars, built to be read in a second:
##   ★★★☆☆  Good
##   5 of 7 bones under ★★★★
##   Raise them: better copies · Repair Workshop
##   All ★★★★+ → Masterpiece

const Ui := preload("res://ui_style.gd")
const PAD := Vector2(14, 10)

var info: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_info(data: Dictionary) -> void:
	info = data
	size = Vector2(300, _height())
	queue_redraw()


func _height() -> float:
	var h: float = PAD.y * 2.0 + 30.0
	if bool(info.get("master", false)):
		return h + 22.0
	if int(info.get("below", 0)) > 0:
		h += 22.0 + 20.0
		if bool(info.get("complete", false)):
			h += 20.0
	return h


func _star(center: Vector2, r: float, on: bool) -> void:
	var pts := PackedVector2Array()
	for k in 10:
		var ang: float = -PI * 0.5 + float(k) * PI / 5.0
		var rad: float = r if k % 2 == 0 else r * 0.45
		pts.append(center + Vector2(cos(ang), sin(ang)) * rad)
	if on:
		draw_colored_polygon(pts, Ui.GOLD)
	pts.append(pts[0])
	draw_polyline(pts, Ui.GOLD if on else Color(Ui.GOLD, 0.45), 1.3)


func _stars_row(pos: Vector2, count: int, filled: int, r: float) -> float:
	var gap: float = r * 2.3
	for i in count:
		_star(pos + Vector2(r + float(i) * gap, 0.0), r, i < filled)
	return float(count) * gap


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, Color("2A1D12", 0.97))
	draw_rect(rect, Ui.GOLD, false, 2.0)
	var font: Font = Ui.display_font()
	var stars: int = int(info.get("stars", 0))
	var y: float = PAD.y + 14.0
	var x: float = PAD.x
	x += _stars_row(Vector2(x, y), 5, stars, 10.0) + 8.0
	draw_string(font, Vector2(x, y + 7.0), str(info.get("word", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Ui.GOLD)
	y += 30.0
	if bool(info.get("master", false)):
		draw_string(font, Vector2(PAD.x, y + 4.0), "Masterpiece! Every bone has 4+ stars.", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("FFD66B"))
		return
	var below: int = int(info.get("below", 0))
	if below <= 0:
		return
	var lead: String = "%d of %d bones under " % [below, int(info.get("total", 0))]
	draw_string(font, Vector2(PAD.x, y + 4.0), lead, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Ui.INK)
	var lw: float = font.get_string_size(lead, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	_stars_row(Vector2(PAD.x + lw, y), 4, 4, 6.0)
	y += 22.0
	draw_string(font, Vector2(PAD.x, y + 2.0), "Raise: better copies · Repair Workshop", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Ui.MUTED)
	if bool(info.get("complete", false)):
		y += 20.0
		draw_string(font, Vector2(PAD.x, y + 2.0), "All 4+ stars = Masterpiece", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("FFD66B"))
