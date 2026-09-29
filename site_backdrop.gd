class_name SiteBackdrop
extends Node2D

## Top-down field camp around the fixed pit. Draw-only — never steals dig clicks.

const GROUND := Color("C4A36A")
const GROUND_SHADE := Color("B08A52")
const GROUND_DEEP := Color("9A7544")
const PACKED := Color("B89458")
const LIP_LINE := Color("241C16")
const RIM_SHADOW := Color(0.16, 0.11, 0.07, 0.22)
const RIM_W := 3.0
const HEADER_ROW_H := 36.0
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
	return GROUND


static func clear_color() -> Color:
	return CLEAR


static func hole_fill_color() -> Color:
	return GROUND


static func pit_cutout() -> Rect2:
	var pad: float = Tuning.chunk_pad
	var cut_top: float = minf(Tuning.grid_origin.y - pad, north_lip_y())
	var north: float = Tuning.grid_origin.y - cut_top
	return Rect2(
		Tuning.grid_origin.x - pad,
		cut_top,
		float(Tuning.grid_w) * Tuning.cell_w + pad * 2.0,
		float(Tuning.grid_h) * Tuning.cell_h + north
	)


static func header_row_bottom() -> float:
	return (Tuning.hud_h - HEADER_ROW_H) * 0.5 + HEADER_ROW_H


static func north_lip_y() -> float:
	return Tuning.hud_h


static func north_pad_rect() -> Rect2:
	var cut: Rect2 = pit_cutout()
	return Rect2(cut.position.x, cut.position.y, cut.size.x, Tuning.grid_origin.y - cut.position.y)


static func shaft_back_color() -> Color:
	return Tuning.shaft_interior_color(0)


static func horizon_y() -> float:
	return 0.0


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


static func north_rim_h() -> float:
	return 2.0


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
	_draw_ground(view)
	_draw_pit_lips()
	_draw_survey()
	_draw_props()


func _draw_ground(view: Vector2) -> void:
	var wash: float = horizon_y()
	var hole: Rect2 = chunk_hole()
	var ground_h: float = view.y - wash
	if ground_h <= 0.0:
		return
	_fill_around(Rect2(0.0, wash, view.x, ground_h), hole, GROUND)
	_mottle_ground(view, hole, wash)
	_draw_ground_light(view)
	_draw_pit_shadow(Rect2(hole.position, hole.size + Vector2(0.0, Tuning.pit_front_h())))
	if _cover_hole:
		draw_rect(hole, hole_fill_color())
	else:
		draw_rect(hole, shaft_back_color())


## The ground is not one flat colour: lighter overhead, darker toward the bottom
## and at the edges, so the pit reads as the bright centre of the scene.
func _draw_ground_light(view: Vector2) -> void:
	draw_polygon(
		PackedVector2Array([Vector2(0, 0), Vector2(view.x, 0), Vector2(view.x, view.y), Vector2(0, view.y)]),
		PackedColorArray([Color(1.0, 0.95, 0.8, 0.10), Color(1.0, 0.95, 0.8, 0.10), Color(0.25, 0.14, 0.05, 0.11), Color(0.25, 0.14, 0.05, 0.11)])
	)
	var edge: float = 230.0
	var dark := Color(0.16, 0.09, 0.03, 0.20)
	var clear := Color(0.16, 0.09, 0.03, 0.0)
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(edge, 0), Vector2(edge, view.y), Vector2(0, view.y)]), PackedColorArray([dark, clear, clear, dark]))
	draw_polygon(PackedVector2Array([Vector2(view.x - edge, 0), Vector2(view.x, 0), Vector2(view.x, view.y), Vector2(view.x - edge, view.y)]), PackedColorArray([clear, dark, dark, clear]))
	var foot: float = 170.0
	draw_polygon(PackedVector2Array([Vector2(0, view.y - foot), Vector2(view.x, view.y - foot), Vector2(view.x, view.y), Vector2(0, view.y)]), PackedColorArray([clear, clear, dark, dark]))


## A soft shadow around the pit, so it sits in the ground instead of on it.
func _draw_pit_shadow(hole: Rect2) -> void:
	for i in 16:
		var grow: float = 3.0 + float(i) * 2.2
		var area := Rect2(hole.position.x - grow, hole.position.y - grow + 3.0, hole.size.x + grow * 2.0, hole.size.y + grow * 2.0)
		_fill_around(area, hole, Color(0.13, 0.07, 0.02, 0.04))


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
	var lip_h: float = north_rim_h()
	var north_lip := Rect2(cut.position.x - 3.0, cut.position.y - lip_h, cut.size.x + 6.0, lip_h)
	draw_rect(north_lip, GROUND.lightened(0.14))
	draw_line(Vector2(cut.position.x, cut.position.y), Vector2(cut.end.x, cut.position.y), LIP_LINE, 2.0)
	draw_rect(Rect2(cut.position.x - 1.0, cut.position.y, 1.0, cut.size.y), shade)
	draw_rect(Rect2(cut.end.x, cut.position.y, 1.0, cut.size.y), shade)
	var pit := Rect2(cut.position, cut.size + Vector2(0.0, Tuning.pit_front_h()))
	_draw_pit_frame(pit)
	_draw_grid_tape(cut)


## A timber frame around the pit: dark outline, warm wood, a lit top edge and
## brass rivets. It stays outside the cutout, so it never covers the dig.
func _draw_pit_frame(cut: Rect2) -> void:
	var w: float = 5.0
	var outer: Rect2 = cut.grow(w)
	_fill_around(outer, cut, Color("4E3927"))
	var lit := Color("8A6A44")
	draw_line(Vector2(outer.position.x, outer.position.y + 1.0), Vector2(outer.end.x, outer.position.y + 1.0), lit, 2.0)
	draw_line(Vector2(outer.position.x + 1.0, outer.position.y), Vector2(outer.position.x + 1.0, outer.end.y), Color(lit, 0.6), 1.5)
	draw_line(Vector2(outer.position.x, outer.end.y - 1.0), Vector2(outer.end.x, outer.end.y - 1.0), Color("2A1C10"), 2.0)
	draw_rect(outer, Color("1B120B"), false, 2.0)
	draw_rect(cut.grow(0.5), Color("1B120B"), false, 1.5)
	var rivets: Array[Vector2] = [
		Vector2(outer.position.x + w * 0.5, outer.position.y + w * 0.5),
		Vector2(outer.end.x - w * 0.5, outer.position.y + w * 0.5),
		Vector2(outer.position.x + w * 0.5, outer.end.y - w * 0.5),
		Vector2(outer.end.x - w * 0.5, outer.end.y - w * 0.5),
		Vector2(outer.get_center().x, outer.position.y + w * 0.5),
		Vector2(outer.get_center().x, outer.end.y - w * 0.5),
	]
	for at in rivets:
		draw_circle(at, 2.0, Color("1B120B"))
		draw_circle(at, 1.4, Color("C9A056"))
		draw_circle(at + Vector2(-0.4, -0.4), 0.6, Color("F2DFA0"))


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
	_draw_spoil(props["spoil"])


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
