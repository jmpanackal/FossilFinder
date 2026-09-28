class_name RewardRibbon
extends Control

## A brass ribbon that pops out of the top edge of the Finds tray to celebrate
## a find: its condition, an exhibit upgrade, a finished skeleton. It sits on
## the tray border (below the pit), never blocks clicks, and queues if busy.

const Ui := preload("res://ui_style.gd")

const TIER_QUIET := 0
const TIER_GOOD := 1
const TIER_GREAT := 2
const TIER_BEST := 3

const TITLE_SIZE := 22
const SUB_SIZE := 13
const STAR_R := 9.0
const STAR_GAP := 22.0
const PAD := Vector2(22, 8)
const STAR_STEP := 0.11

var title: String = ""
var subtitle: String = ""
var stars: int = 0
var tier: int = TIER_GOOD
var _anchor := Vector2.ZERO
var _life: float = 0.0
var _age: float = 0.0
var _shown_stars: int = 0
var _queue: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func is_showing() -> bool:
	return visible and _life > 0.0


## anchor = where the ribbon's bottom-center should sit (the tray's top edge).
func show_reward(new_title: String, new_subtitle: String, new_stars: int, new_tier: int, anchor: Vector2) -> void:
	var entry := {"title": new_title, "subtitle": new_subtitle, "stars": new_stars, "tier": new_tier, "anchor": anchor}
	if is_showing():
		## Let the current one finish quickly, then show this one.
		_life = minf(_life, 0.6)
		_queue.append(entry)
		return
	_start(entry)


func _start(entry: Dictionary) -> void:
	title = str(entry["title"])
	subtitle = str(entry["subtitle"])
	stars = clampi(int(entry["stars"]), 0, 5)
	tier = int(entry["tier"])
	_anchor = entry["anchor"]
	_age = 0.0
	_shown_stars = 0
	_life = 2.6 + (1.8 if not subtitle.is_empty() else 0.0) + (0.6 if tier >= TIER_BEST else 0.0)
	_layout()
	visible = true
	modulate.a = 1.0
	pivot_offset = size * 0.5
	scale = Vector2(0.55, 0.55)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.08, 1.08), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector2.ONE, 0.12)
	if tier >= TIER_GREAT:
		Sfx.play("unlock" if tier >= TIER_BEST else "buy")
	queue_redraw()


func _layout() -> void:
	var font: Font = Ui.display_font()
	var w: float = font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_SIZE).x
	if not subtitle.is_empty():
		w = maxf(w, font.get_string_size(subtitle, HORIZONTAL_ALIGNMENT_LEFT, -1, SUB_SIZE).x)
	if stars > 0:
		w = maxf(w, STAR_GAP * 5.0)
	var h: float = float(TITLE_SIZE) + 6.0
	if stars > 0:
		h += STAR_R * 2.0 + 6.0
	if not subtitle.is_empty():
		h += float(SUB_SIZE) + 6.0
	size = Vector2(w, h) + PAD * 2.0
	var x: float = _anchor.x - size.x * 0.5
	var view_w: float = Tuning.view_w
	x = clampf(x, 8.0, maxf(8.0, view_w - size.x - 8.0))
	## Straddle the tray's top edge, but never cover the dig cells above it.
	var y: float = maxf(_anchor.y - size.y * 0.55, Tuning.pit_face_bottom() + 6.0)
	position = Vector2(x, y)


func _process(delta: float) -> void:
	if not visible:
		return
	_age += delta
	var want: int = mini(stars, int(_age / STAR_STEP))
	while _shown_stars < want:
		_shown_stars += 1
		if tier >= TIER_GOOD:
			Sfx.play("ui", 0.9 + 0.12 * float(_shown_stars))
	_life -= delta
	if _life <= 0.0:
		modulate.a = maxf(0.0, modulate.a - delta * 3.0)
		if modulate.a <= 0.0:
			visible = false
			if not _queue.is_empty():
				_start(_queue.pop_front())
	queue_redraw()


func _accent() -> Color:
	match tier:
		TIER_QUIET:
			return Color("B8A48C")
		TIER_GOOD:
			return Color("E4B75A")
		TIER_GREAT:
			return Color("FFD66B")
		_:
			return Color("FFE9A0")


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var accent: Color = _accent()
	if tier >= TIER_GREAT:
		## Soft pulsing halo so great finds catch the eye without covering the pit.
		var pulse: float = 0.5 + 0.5 * sin(_age * 7.0)
		for k in 3:
			var grow: float = 3.0 + float(k) * 3.0 + pulse * 2.0
			draw_rect(rect.grow(grow), Color(accent, 0.10 - float(k) * 0.03), false, 3.0)
	draw_rect(rect, Color("2A1D12"))
	draw_rect(rect.grow(-3.0), Color("3A2816"))
	draw_rect(rect, accent, false, 3.0 if tier >= TIER_GREAT else 2.0)
	## Ribbon tails on both ends read as a banner, not a dialog.
	var tail: float = size.y * 0.5
	for side in [-1.0, 1.0]:
		var x0: float = 0.0 if side < 0.0 else size.x
		var pts := PackedVector2Array([
			Vector2(x0, size.y * 0.2),
			Vector2(x0 + side * tail, size.y * 0.2),
			Vector2(x0 + side * tail * 0.6, size.y * 0.55),
			Vector2(x0 + side * tail, size.y * 0.9),
			Vector2(x0, size.y * 0.9),
		])
		draw_colored_polygon(pts, Color("5A3A1C"))
		pts.append(pts[0])
		draw_polyline(pts, accent, 1.5)
	if tier >= TIER_GREAT:
		## A shine sweeps across once as it lands.
		var t: float = clampf(_age / 0.7, 0.0, 1.0)
		if t < 1.0:
			var sx: float = lerpf(-30.0, size.x + 30.0, t)
			draw_colored_polygon(PackedVector2Array([
				Vector2(sx, 0), Vector2(sx + 18.0, 0), Vector2(sx - 2.0, size.y), Vector2(sx - 20.0, size.y),
			]), Color(1, 1, 1, 0.18))
	var font: Font = Ui.display_font()
	var y: float = PAD.y + float(TITLE_SIZE)
	var tw: float = font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_SIZE).x
	draw_string_outline(font, Vector2((size.x - tw) * 0.5, y), title, HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_SIZE, 4, Color(0.08, 0.05, 0.03, 0.9))
	draw_string(font, Vector2((size.x - tw) * 0.5, y), title, HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_SIZE, accent)
	y += 6.0
	if stars > 0:
		var row_w: float = STAR_GAP * 4.0
		var x0: float = (size.x - row_w) * 0.5
		for i in 5:
			var on: bool = i < _shown_stars
			var pop: float = 1.0
			if on and i == _shown_stars - 1:
				pop = 1.0 + 0.35 * clampf(1.0 - fmod(_age, STAR_STEP) / STAR_STEP, 0.0, 1.0)
			_draw_star(Vector2(x0 + STAR_GAP * float(i), y + STAR_R), STAR_R * pop, on, accent)
		y += STAR_R * 2.0 + 6.0
	if not subtitle.is_empty():
		var sw: float = font.get_string_size(subtitle, HORIZONTAL_ALIGNMENT_LEFT, -1, SUB_SIZE).x
		draw_string(font, Vector2((size.x - sw) * 0.5, y + float(SUB_SIZE)), subtitle, HORIZONTAL_ALIGNMENT_LEFT, -1, SUB_SIZE, Ui.INK)


func _draw_star(center: Vector2, r: float, on: bool, accent: Color) -> void:
	var pts := PackedVector2Array()
	for k in 10:
		var ang: float = -PI * 0.5 + float(k) * PI / 5.0
		var rad: float = r if k % 2 == 0 else r * 0.45
		pts.append(center + Vector2(cos(ang), sin(ang)) * rad)
	if on:
		draw_colored_polygon(pts, accent)
	pts.append(pts[0])
	draw_polyline(pts, accent if on else Color(accent, 0.45), 1.5)
