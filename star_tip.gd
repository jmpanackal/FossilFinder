class_name StarTip
extends Control

## One hover card for a museum stand (opened from its stars OR its $/sec),
## since both stars and dirt decide what each bone earns:
##   ★★★★☆  Great                         $6.60 / sec
##   Average of 3 found bones: 4.3 → 4 stars
##   Bone        Stars      Dirt       $/sec
##   Skull       ★★★★★      Clean      $2.40
##   Claw        ★★★★☆      Dusty      $1.10
##   Leg         ☆☆☆☆☆      —          —        (greyed: not found yet)
##   Masterpiece: all 4 bones Perfect and clean (2 to go)
##   Complete x2 · Featured x4

const Ui := preload("res://ui_style.gd")
const PAD := Vector2(14, 10)
const HEAD_H := 30.0
const LINE_H := 20.0
const ROW_H := 18.0
const ROW_FS := 13
const LINE_FS := 13
const MINI_R := 5.5
const GAP := 14.0
const MISSING_INK := Color("8A7A66")

var info: Dictionary = {}
var _bones: Array = []
var _name_w: float = 0.0
var _dirt_w: float = 0.0
var _rate_w: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_info(data: Dictionary) -> void:
	info = data
	_bones = info.get("bones", [])
	var font: Font = Ui.display_font()
	_name_w = font.get_string_size("Bone", HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	_dirt_w = font.get_string_size("Caked", HORIZONTAL_ALIGNMENT_LEFT, -1, ROW_FS).x
	_rate_w = font.get_string_size("$/sec", HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	for b in _bones:
		_name_w = maxf(_name_w, font.get_string_size(str(b["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, ROW_FS).x)
		_rate_w = maxf(_rate_w, font.get_string_size(_rate_text(b), HORIZONTAL_ALIGNMENT_LEFT, -1, ROW_FS).x)
	## Width hugs the content: the widest of header, text lines and bone rows.
	var head_w: float = _stars_w(10.0) + 8.0 + font.get_string_size(str(info.get("word", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x + 24.0 + font.get_string_size(_income_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	var w: float = maxf(head_w, _row_w())
	for line in [_avg_line(), _master_line(), str(info.get("boosts", ""))]:
		w = maxf(w, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, LINE_FS).x)
	size = Vector2(ceilf(w + PAD.x * 2.0), _height())
	queue_redraw()


func _stars_w(r: float) -> float:
	return r * 2.3 * 5.0


func _row_w() -> float:
	return _name_w + GAP + _stars_w(MINI_R) + GAP + _dirt_w + GAP + _rate_w


func _height() -> float:
	var h: float = PAD.y * 2.0 + HEAD_H + LINE_H + 6.0 + ROW_H + float(_bones.size()) * ROW_H + 8.0 + LINE_H
	if not str(info.get("boosts", "")).is_empty():
		h += LINE_H - 2.0
	return h


func _income_text() -> String:
	return "%s / sec" % Ui.money_text_cents(float(info.get("income", 0.0)))


func _rate_text(b: Dictionary) -> String:
	if int(b["cond"]) <= 0:
		return "—"
	return Ui.money_text_cents(float(b.get("rate", 0.0)))


## How dirty a bone is, in one word (income slides with it).
static func dirt_word(clean_pct: float) -> String:
	if clean_pct >= 0.96:
		return "Clean"
	if clean_pct >= 0.6:
		return "Dusty"
	if clean_pct >= 0.25:
		return "Dirty"
	return "Caked"


static func dirt_color(clean_pct: float) -> Color:
	if clean_pct >= 0.96:
		return Color("A8E07A")
	if clean_pct >= 0.6:
		return Color("E0C48A")
	if clean_pct >= 0.25:
		return Color("C08A5A")
	return Color("9A6A48")


func _avg_line() -> String:
	var total: int = int(info.get("total", 0))
	var avg: float = float(info.get("avg", 0.0))
	var stars: int = int(info.get("stars", 0))
	var tail: String = " (rounded down)" if absf(avg - float(stars)) > 0.05 else ""
	return "Average of %d found bone%s: %.1f → %d stars%s" % [total, "" if total == 1 else "s", avg, stars, tail]


func _master_line() -> String:
	var need: int = int(info.get("master_stars", 5))
	if bool(info.get("master", false)):
		return "Masterpiece! Every bone Perfect and clean"
	var to_go: int = 0
	for b in _bones:
		if int(b["cond"]) < need or float(b.get("clean_pct", 0.0)) < 0.96:
			to_go += 1
	return "Masterpiece: all %d bones Perfect and clean (%d to go)" % [_bones.size(), to_go]


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
	var inc: String = _income_text()
	var inc_w: float = font.get_string_size(inc, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	draw_string(font, Vector2(size.x - PAD.x - inc_w, y + 6.0), inc, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Ui.GOLD)
	y += HEAD_H
	draw_string(font, Vector2(PAD.x, y + 4.0), _avg_line(), HORIZONTAL_ALIGNMENT_LEFT, -1, LINE_FS, Ui.INK)
	y += LINE_H - 2.0
	draw_line(Vector2(PAD.x, y), Vector2(size.x - PAD.x, y), Color(Ui.GOLD, 0.25), 1.0)
	y += 6.0
	var x_stars: float = PAD.x + _name_w + GAP
	var x_dirt: float = x_stars + _stars_w(MINI_R) + GAP
	var x_rate_end: float = size.x - PAD.x
	## Column heads.
	var head_y: float = y + ROW_H * 0.5 + 4.0
	draw_string(font, Vector2(PAD.x, head_y), "Bone", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Ui.MUTED)
	draw_string(font, Vector2(x_stars, head_y), "Stars", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Ui.MUTED)
	draw_string(font, Vector2(x_dirt, head_y), "Dirt", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Ui.MUTED)
	var rh_w: float = font.get_string_size("$/sec", HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	draw_string(font, Vector2(x_rate_end - rh_w, head_y), "$/sec", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Ui.MUTED)
	y += ROW_H
	## One row per bone: stars and dirt both set what it earns. Missing bones
	## are greyed: not counted, but a Masterpiece needs them.
	for i in _bones.size():
		var b: Dictionary = _bones[i]
		var by: float = y + float(i) * ROW_H + ROW_H * 0.5
		var cond: int = int(b["cond"])
		var found: bool = cond > 0
		draw_string(font, Vector2(PAD.x, by + 5.0), str(b["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, ROW_FS, Ui.INK if found else MISSING_INK)
		var star_col: Color = (Color("FFD66B") if cond >= need else Ui.GOLD) if found else MISSING_INK
		_stars_row(Vector2(x_stars, by), cond, MINI_R, star_col)
		var pct: float = float(b.get("clean_pct", 0.0))
		var dirt: String = dirt_word(pct) if found else "—"
		draw_string(font, Vector2(x_dirt, by + 5.0), dirt, HORIZONTAL_ALIGNMENT_LEFT, -1, ROW_FS, dirt_color(pct) if found else MISSING_INK)
		var rate: String = _rate_text(b)
		var rw: float = font.get_string_size(rate, HORIZONTAL_ALIGNMENT_LEFT, -1, ROW_FS).x
		draw_string(font, Vector2(x_rate_end - rw, by + 5.0), rate, HORIZONTAL_ALIGNMENT_LEFT, -1, ROW_FS, Ui.INK if found else MISSING_INK)
	y += float(_bones.size()) * ROW_H + 8.0
	draw_string(font, Vector2(PAD.x, y + 8.0), _master_line(), HORIZONTAL_ALIGNMENT_LEFT, -1, LINE_FS, Color("FFD66B"))
	var boosts: String = str(info.get("boosts", ""))
	if not boosts.is_empty():
		y += LINE_H - 2.0
		draw_string(font, Vector2(PAD.x, y + 8.0), boosts, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Ui.MUTED)
