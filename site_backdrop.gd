class_name SiteBackdrop
extends Node2D

## Top-down field camp around the fixed pit. Draw-only — never steals dig clicks.

const SKY_TOP := Color("C5D0D6")
const SKY_WASH := Color("D7C9B0")
const GROUND := Color("C4A36A")
const GROUND_SHADE := Color("B08A52")
const GROUND_DEEP := Color("9A7544")
const PACKED := Color("B89458")
const LIP_LINE := Color("241C16")
const RIM_SHADOW := Color(0.16, 0.11, 0.07, 0.22)
const RIM_W := 3.0
const STRING := Color("E4B75A")
const WOOD := Color("5C4030")
const CANVAS := Color("D8C08A")
const CANVAS_DARK := Color("B89A68")
const CRATE := Color("8A6A38")
const CRATE_DARK := Color("6E5328")
const JUG := Color("7A9AAA")
const JUG_DARK := Color("5E7A88")
const CLEAR := Color("D7C9B0")

var _cover_hole: bool = false


func _ready() -> void:
	z_index = -1
	z_as_relative = false


func covers_chunk_hole() -> bool:
	return _cover_hole


func set_covers_chunk_hole(on: bool) -> void:
	_cover_hole = on
	queue_redraw()


static func ground_color() -> Color:
	return GROUND


static func sky_color() -> Color:
	return SKY_TOP


static func clear_color() -> Color:
	return CLEAR


static func hole_fill_color() -> Color:
	return GROUND


static func pit_cutout() -> Rect2:
	var pad: float = Tuning.chunk_pad
	return Rect2(
		Tuning.grid_origin.x - pad,
		Tuning.grid_origin.y - pad,
		float(Tuning.grid_w) * Tuning.cell_w + pad * 2.0,
		float(Tuning.grid_h) * Tuning.cell_h + pad
	)


static func horizon_y() -> float:
	return 32.0


static func chunk_hole() -> Rect2:
	return pit_cutout()


static func rim_width() -> float:
	return RIM_W


static func rim_shadow_color() -> Color:
	return RIM_SHADOW


static func rim_rect() -> Rect2:
	return Rect2(
		Tuning.grid_origin,
		Vector2(float(Tuning.grid_w) * Tuning.cell_w, float(Tuning.grid_h) * Tuning.cell_h)
	)


static func prop_rects() -> Dictionary:
	var cut: Rect2 = pit_cutout()
	var survey: Rect2 = cut
	return {
		"spoil": Rect2(cut.position.x - 96.0, cut.position.y + cut.size.y * 0.28, 80, 56),
		"crate": Rect2(cut.end.x + 28.0, cut.position.y + cut.size.y * 0.52, 44, 36),
		"jug": Rect2(cut.end.x + 80.0, cut.position.y + cut.size.y * 0.58, 22, 22),
		"tent": Rect2(cut.end.x + 26.0, cut.position.y + 8.0, 90, 70),
		"stakes": Rect2(survey.position.x - 12.0, survey.position.y - 12.0, 24, 24),
	}


func _draw() -> void:
	var view := Vector2(Tuning.view_w, Tuning.view_h)
	if view.x <= 0.0 or view.y <= 0.0:
		return
	_draw_sky(view)
	_draw_ground(view)
	_draw_pit_lips()
	_draw_survey()
	_draw_props()


func _draw_sky(view: Vector2) -> void:
	var wash: float = horizon_y()
	var bands: int = 4
	for i in bands:
		var t: float = float(i) / float(maxi(bands - 1, 1))
		var y: float = wash * float(i) / float(bands)
		var h: float = wash / float(bands) + 1.0
		draw_rect(Rect2(0.0, y, view.x, h), SKY_TOP.lerp(SKY_WASH, t))


func _draw_ground(view: Vector2) -> void:
	var wash: float = horizon_y()
	var hole: Rect2 = chunk_hole()
	var ground_h: float = view.y - wash
	if ground_h <= 0.0:
		return
	_fill_around(Rect2(0.0, wash, view.x, ground_h), hole, GROUND)
	_mottle_ground(view, hole, wash)
	var packed := Rect2(hole.position.x - 22.0, hole.position.y - 16.0, hole.size.x + 44.0, hole.size.y + 28.0)
	_fill_around(packed, hole, PACKED.lerp(GROUND, 0.35))
	if _cover_hole:
		draw_rect(hole, hole_fill_color())


func _fill_around(area: Rect2, hole: Rect2, color: Color) -> void:
	var clip: Rect2 = hole.intersection(area)
	if clip.size.x <= 0.0 or clip.size.y <= 0.0:
		draw_rect(area, color)
		return
	if clip.position.x > area.position.x:
		draw_rect(Rect2(area.position.x, area.position.y, clip.position.x - area.position.x, area.size.y), color)
	if clip.end.x < area.end.x:
		draw_rect(Rect2(clip.end.x, area.position.y, area.end.x - clip.end.x, area.size.y), color)
	if clip.position.y > area.position.y:
		draw_rect(Rect2(clip.position.x, area.position.y, clip.size.x, clip.position.y - area.position.y), color)
	if clip.end.y < area.end.y:
		draw_rect(Rect2(clip.position.x, clip.end.y, clip.size.x, area.end.y - clip.end.y), color)


func _mottle_ground(view: Vector2, hole: Rect2, wash: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1042
	for _i in 22:
		var pos := Vector2(rng.randf() * view.x, wash + 8.0 + rng.randf() * maxf(40.0, view.y - wash - 16.0))
		if hole.grow(6.0).has_point(pos):
			continue
		draw_circle(pos, 5.0 + rng.randf() * 11.0, Color(GROUND_SHADE, 0.22))


func _draw_pit_lips() -> void:
	var cut: Rect2 = pit_cutout()
	var shade := Color(0.16, 0.11, 0.07, 0.20)
	draw_rect(Rect2(cut.position.x - 4.0, cut.position.y - 3.0, cut.size.x + 8.0, 3.0), shade)
	draw_rect(Rect2(cut.position.x - 4.0, cut.position.y, 4.0, cut.size.y), shade)
	draw_rect(Rect2(cut.end.x, cut.position.y, 4.0, cut.size.y), shade)
	var near := Rect2(cut.position.x - 3.0, cut.end.y, cut.size.x + 6.0, 6.0)
	draw_rect(near, GROUND_DEEP.lerp(GROUND, 0.28))
	draw_line(Vector2(cut.position.x, cut.end.y), Vector2(cut.end.x, cut.end.y), LIP_LINE, 1.5)
	_draw_grid_tape(cut)


func _draw_grid_tape(cut: Rect2) -> void:
	var y: float = cut.end.y + 3.0
	var x0: float = cut.position.x
	var x1: float = cut.end.x
	draw_line(Vector2(x0, y), Vector2(x1, y), Color("EFE3C4"), 2.0)
	var step: float = maxf(Tuning.cell_w, 24.0)
	var x: float = x0
	var tick: int = 0
	while x <= x1 + 0.5:
		var h: float = 7.0 if tick % 5 == 0 else 4.0
		draw_line(Vector2(x, y - 1.0), Vector2(x, y + h), LIP_LINE, 1.5)
		tick += 1
		x += step


func _draw_survey() -> void:
	var cut: Rect2 = pit_cutout()
	var corners: Array[Vector2] = [
		cut.position,
		Vector2(cut.end.x, cut.position.y),
		cut.end,
		Vector2(cut.position.x, cut.end.y),
	]
	for i in corners.size():
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i + 1) % corners.size()]
		draw_line(a, b, STRING, 1.6)
		_stake(a)


func _stake(pos: Vector2) -> void:
	draw_circle(pos, 4.2, WOOD)
	draw_circle(pos, 2.2, STRING)


func _draw_props() -> void:
	var props: Dictionary = prop_rects()
	_draw_tent_footprint(props["tent"])
	_draw_spoil(props["spoil"])
	_draw_crate(props["crate"])
	_draw_jug(props["jug"])


func _draw_tent_footprint(rect: Rect2) -> void:
	var pad := Vector2(6, 6)
	var body := Rect2(rect.position + pad, rect.size - pad * 2.0)
	var nw := body.position
	var ne := Vector2(body.end.x, body.position.y)
	var se := body.end
	var sw := Vector2(body.position.x, body.end.y)
	var ridge_a := Vector2(body.get_center().x, body.position.y + 4.0)
	var ridge_b := Vector2(body.get_center().x, body.end.y - 4.0)
	draw_colored_polygon(PackedVector2Array([nw, ne, se, sw]), CANVAS)
	draw_colored_polygon(PackedVector2Array([ridge_a, ne, se, ridge_b]), CANVAS_DARK)
	draw_line(ridge_a, ridge_b, WOOD, 2.0)
	draw_rect(body, LIP_LINE, false, 1.5)
	for peg in [nw, ne, se, sw]:
		draw_circle(peg, 2.6, WOOD)


func _draw_spoil(rect: Rect2) -> void:
	var c: Vector2 = rect.get_center() + Vector2(0, 4)
	draw_circle(c + Vector2(-16, 4), 20.0, GROUND_DEEP)
	draw_circle(c + Vector2(14, 6), 16.0, GROUND_SHADE)
	draw_circle(c + Vector2(-2, -4), 18.0, GROUND.darkened(0.08))
	draw_circle(c + Vector2(8, -2), 8.0, GROUND_SHADE.lightened(0.08))


func _draw_crate(rect: Rect2) -> void:
	draw_rect(rect, CRATE)
	draw_rect(rect, LIP_LINE, false, 2.0)
	draw_line(rect.position + Vector2(8, 0), Vector2(rect.position.x + 8.0, rect.end.y), LIP_LINE, 1.5)
	draw_line(Vector2(rect.end.x - 8.0, rect.position.y), Vector2(rect.end.x - 8.0, rect.end.y), LIP_LINE, 1.5)
	draw_line(rect.position + Vector2(0, rect.size.y * 0.5), Vector2(rect.end.x, rect.position.y + rect.size.y * 0.5), LIP_LINE, 1.5)


func _draw_jug(rect: Rect2) -> void:
	var c: Vector2 = rect.get_center()
	draw_circle(c, minf(rect.size.x, rect.size.y) * 0.42, JUG)
	draw_circle(c, minf(rect.size.x, rect.size.y) * 0.42, LIP_LINE, false, 1.5)
	draw_circle(c + Vector2(0, -2), 3.0, JUG_DARK)
