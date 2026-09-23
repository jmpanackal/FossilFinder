extends Node2D

const Ui := preload("res://ui_style.gd")

const HALL := Vector2(2000, 1480)
const FLOOR := Color("3C2C20")
const FLOOR_DARK := Color("2E2218")
const FLOOR_PLANK := Color("443224")
const WALL := Color("2A1C14")
const WALL_TRIM := Color("4A3426")
const RUNNER := Color("5A2A22")
const RUNNER_EDGE := Color("3A1A16")
const PLATFORM := Color("3A2C20")
const PLATFORM_LIP := Color("2A1E16")
const EMPTY_FILL := Color(0.38, 0.30, 0.24, 0.20)
const EMPTY_LINE := Color(0.58, 0.46, 0.36, 0.62)
const STAND_LAYOUT := {
	"t_rex": {"title": "T. rex", "x": 760.0, "y": 236.0, "w": 480.0, "h": 250.0},
	"triceratops": {"title": "Triceratops", "x": 70.0, "y": 500.0, "w": 460.0, "h": 260.0},
	"brachiosaurus": {"title": "Brachiosaurus", "x": 1470.0, "y": 480.0, "w": 460.0, "h": 280.0},
	"velociraptor": {"title": "Velociraptor", "x": 70.0, "y": 1100.0, "w": 400.0, "h": 230.0},
	"stegosaurus": {"title": "Stegosaurus", "x": 1470.0, "y": 1100.0, "w": 460.0, "h": 230.0},
}

var flash_stand_id: String = ""
var flash_t: float = 0.0
var pop_t: float = 0.0


func play_unveil_flash(stand_id: String) -> void:
	flash_stand_id = stand_id
	flash_t = 1.0
	queue_redraw()


func play_feature_pop() -> void:
	pop_t = 1.0
	queue_redraw()


func tick(delta: float) -> void:
	var dirty: bool = false
	if flash_t > 0.0:
		flash_t = maxf(0.0, flash_t - delta / 0.5)
		dirty = true
	if pop_t > 0.0:
		pop_t = maxf(0.0, pop_t - delta / 0.35)
		dirty = true
	if dirty:
		queue_redraw()


func stand_rect(stand_id: String) -> Rect2:
	if not STAND_LAYOUT.has(stand_id):
		return Rect2()
	var info: Dictionary = STAND_LAYOUT[stand_id]
	return Rect2(float(info["x"]), float(info["y"]), float(info["w"]), float(info["h"]))


func stand_id_at(hall_pos: Vector2) -> String:
	for stand_id in STAND_LAYOUT:
		if stand_rect(str(stand_id)).has_point(hall_pos):
			return str(stand_id)
	return ""


func _draw() -> void:
	_draw_hall()
	_draw_t_rex_bay()
	_draw_triceratops_bay()
	_draw_sauropod_bay()
	_draw_raptor_bay()
	_draw_stego_bay()


func _draw_hall() -> void:
	draw_rect(Rect2(0, 0, HALL.x, HALL.y), Color("1A1410"))
	draw_rect(Rect2(0, 0, HALL.x, 196), WALL)
	draw_rect(Rect2(0, 196, HALL.x, 22), WALL_TRIM)
	draw_rect(Rect2(0, 218, HALL.x, HALL.y - 218), FLOOR)
	var plank: int = 0
	var y: float = 232.0
	while y < HALL.y:
		var shade: Color = FLOOR_DARK if plank % 2 == 0 else FLOOR_PLANK
		draw_rect(Rect2(0, y, HALL.x, 3), shade)
		y += 30.0
		plank += 1
	draw_rect(Rect2(920, 218, 160, HALL.y - 218), RUNNER)
	draw_rect(Rect2(920, 218, 10, HALL.y - 218), RUNNER_EDGE)
	draw_rect(Rect2(1070, 218, 10, HALL.y - 218), RUNNER_EDGE)
	var stripe_y: float = 260.0
	while stripe_y < HALL.y:
		draw_rect(Rect2(928, stripe_y, 144, 3), Color(0.25, 0.10, 0.08, 0.35))
		stripe_y += 64.0
	_draw_wall_frame(Vector2(220, 86), Vector2(150, 70))
	_draw_wall_frame(Vector2(1630, 86), Vector2(150, 70))
	_draw_pillar(Vector2(896, 186))
	_draw_pillar(Vector2(1076, 186))
	_draw_bench(Vector2(250, 850))
	_draw_bench(Vector2(1650, 850))
	_draw_bench(Vector2(250, 1380))
	_draw_bench(Vector2(1650, 1380))
	_draw_warm_light(Vector2(1000, 118), 140.0)
	_draw_warm_light(Vector2(320, 430), 110.0)
	_draw_warm_light(Vector2(1680, 430), 110.0)
	_draw_warm_light(Vector2(320, 860), 100.0)
	_draw_warm_light(Vector2(1680, 860), 100.0)
	_draw_warm_light(Vector2(1000, 1080), 90.0)
	_draw_warm_light(Vector2(320, 1280), 80.0)
	_draw_warm_light(Vector2(1680, 1280), 80.0)
	_draw_banner(Vector2(1000, 118), "FOSSIL HALL")


func _draw_wall_frame(pos: Vector2, size: Vector2) -> void:
	var rect := Rect2(pos, size)
	draw_rect(rect, Color("241810"))
	draw_rect(rect, Ui.GOLD, false, 1.5)
	draw_rect(Rect2(pos + Vector2(10, 10), size - Vector2(20, 20)), Color("1C1410"))


func _draw_pillar(top: Vector2) -> void:
	var height: float = HALL.y - top.y - 12.0
	draw_rect(Rect2(top.x, top.y, 28, height), Color("2A2118"))
	draw_rect(Rect2(top.x - 8, top.y, 44, 18), Color("4A3A2A"))
	draw_rect(Rect2(top.x - 6, HALL.y - 20, 40, 16), Color("4A3A2A"))
	draw_rect(Rect2(top.x + 6, top.y + 20, 6, height - 30), Color(0.89, 0.72, 0.35, 0.08))


func _draw_bench(pos: Vector2) -> void:
	draw_rect(Rect2(pos.x, pos.y, 100, 12), Color("4A3426"))
	draw_rect(Rect2(pos.x + 8, pos.y + 12, 12, 16), Color("3A281C"))
	draw_rect(Rect2(pos.x + 80, pos.y + 12, 12, 16), Color("3A281C"))


func _draw_warm_light(center: Vector2, radius: float) -> void:
	draw_circle(center, radius, Color(0.89, 0.72, 0.35, 0.07))
	draw_circle(center, radius * 0.55, Color(0.96, 0.84, 0.50, 0.08))


func _draw_banner(center: Vector2, text: String) -> void:
	var size := Vector2(280, 36)
	var rect := Rect2(center - size * 0.5, size)
	draw_rect(rect, Color("3A2818"))
	draw_rect(rect, Ui.GOLD, false, 2.0)
	_draw_label(center + Vector2(0, 6), text, 18, Ui.GOLD)


func _draw_t_rex_bay() -> void:
	var stand: Rect2 = stand_rect("t_rex")
	var mount: Rect2 = _draw_stand(stand, "T. rex", "t_rex")
	var xf := _fit(mount, Vector2(-86, -110), Vector2(108, 0))
	_rect(xf, -8, -84, 70, 38, false, false)
	_rect(xf, 54, -72, 54, 14, false, false)
	_rect(xf, -6, -52, 22, 30, false, false)
	_rect(xf, -2, -26, 16, 26, false, false)
	_rect(xf, 28, -48, 18, 26, false, false)
	_rect(xf, 26, -24, 20, 24, false, false)
	_rect(xf, -4, -66, 18, 6, false, false)
	_rect(xf, -30, -100, 26, 26, false, false)
	_rect(xf, -78, -110, 52, 26, false, false)
	_rect(xf, -72, -86, 34, 8, false, false)
	_draw_stand_finish("t_rex", stand)


func _draw_triceratops_bay() -> void:
	var stand: Rect2 = stand_rect("triceratops")
	var mount: Rect2 = _draw_stand(stand, "Triceratops", "triceratops")
	var owned: bool = GameState.has_piece("triceratops_skull")
	var clean: bool = false
	if owned:
		var piece: Dictionary = GameState.pieces["triceratops_skull"]
		clean = bool(piece.get("clean", false))
	var xf := _fit(mount, Vector2(-98, -100), Vector2(104, 0))
	_rect(xf, -14, -68, 82, 36, false, false)
	_rect(xf, 60, -56, 44, 12, false, false)
	_rect(xf, -10, -34, 16, 34, false, false)
	_rect(xf, 16, -34, 16, 34, false, false)
	_rect(xf, 42, -34, 16, 34, false, false)
	_rect(xf, 66, -32, 16, 32, false, false)
	_rect(xf, -62, -92, 40, 46, owned, clean)
	_rect(xf, -86, -66, 38, 26, owned, clean)
	_rect(xf, -98, -56, 16, 12, owned, clean)
	_rect(xf, -48, -100, 8, 20, owned, clean)
	_rect(xf, -32, -98, 8, 18, owned, clean)
	_rect(xf, -78, -72, 8, 16, owned, clean)
	if owned:
		draw_circle(xf * Vector2(-62, -52), 5.0 * xf.x.length(), Color("2B2118"))
	_draw_stand_finish("triceratops", stand)


func _draw_sauropod_bay() -> void:
	var stand: Rect2 = stand_rect("brachiosaurus")
	var mount: Rect2 = _draw_stand(stand, "Brachiosaurus", "brachiosaurus")
	var xf := _fit(mount, Vector2(-70, -132), Vector2(90, 0))
	_rect(xf, -18, -70, 74, 36, false, false)
	_rect(xf, 48, -56, 42, 12, false, false)
	_rect(xf, -16, -40, 16, 40, false, false)
	_rect(xf, 6, -36, 16, 36, false, false)
	_rect(xf, 28, -36, 16, 36, false, false)
	_rect(xf, 48, -34, 16, 34, false, false)
	_rect(xf, -28, -102, 22, 36, false, false)
	_rect(xf, -42, -124, 20, 28, false, false)
	_rect(xf, -70, -132, 32, 16, false, false)
	_draw_stand_finish("brachiosaurus", stand)


func _draw_raptor_bay() -> void:
	var stand: Rect2 = stand_rect("velociraptor")
	var mount: Rect2 = _draw_stand(stand, "Velociraptor", "velociraptor")
	var xf := _fit(mount, Vector2(-54, -74), Vector2(96, 0))
	_rect(xf, -14, -50, 52, 22, false, false)
	_rect(xf, 32, -46, 64, 8, false, false)
	_rect(xf, 2, -34, 14, 34, false, false)
	_rect(xf, 14, -16, 16, 6, false, false)
	_rect(xf, -8, -30, 10, 18, false, false)
	_rect(xf, -28, -64, 16, 18, false, false)
	_rect(xf, -54, -72, 28, 16, false, false)
	_rect(xf, -50, -58, 14, 6, false, false)
	_draw_stand_finish("velociraptor", stand)


func _draw_stego_bay() -> void:
	var stand: Rect2 = stand_rect("stegosaurus")
	var mount: Rect2 = _draw_stand(stand, "Stegosaurus", "stegosaurus")
	var xf := _fit(mount, Vector2(-52, -88), Vector2(108, 0))
	_rect(xf, -18, -54, 82, 28, false, false)
	_rect(xf, 56, -46, 40, 10, false, false)
	_rect(xf, -12, -28, 14, 28, false, false)
	_rect(xf, 12, -28, 14, 28, false, false)
	_rect(xf, 36, -28, 14, 28, false, false)
	_rect(xf, 58, -26, 14, 26, false, false)
	_rect(xf, -44, -48, 28, 14, false, false)
	_poly(xf, PackedVector2Array([
		Vector2(-4, -54), Vector2(8, -84), Vector2(20, -54)
	]), false, false)
	_poly(xf, PackedVector2Array([
		Vector2(22, -54), Vector2(36, -88), Vector2(50, -54)
	]), false, false)
	_poly(xf, PackedVector2Array([
		Vector2(48, -54), Vector2(60, -80), Vector2(72, -54)
	]), false, false)
	_rect(xf, 90, -54, 6, 16, false, false)
	_rect(xf, 100, -50, 6, 14, false, false)
	_draw_stand_finish("stegosaurus", stand)


func _draw_stand(stand: Rect2, title: String, stand_id: String) -> Rect2:
	var featured: bool = GameState.featured_stand_id == stand_id and GameState.stand_is_filled(stand_id)
	if featured:
		_draw_spotlight(stand)
	_draw_platform(stand, featured)
	var plaque_title: String = title
	if featured:
		plaque_title = "%s  ·  2x" % title
	_draw_plaque(Vector2(stand.get_center().x, stand.end.y - 12.0), plaque_title, featured)
	return Rect2(
		stand.position.x + 22.0,
		stand.position.y + 16.0,
		stand.size.x - 44.0,
		stand.size.y - 54.0
	)


func _draw_stand_finish(stand_id: String, stand: Rect2) -> void:
	if GameState.stand_has_pending_unveil(stand_id):
		_draw_ribbon(stand)
	if flash_t > 0.0 and flash_stand_id == stand_id:
		draw_rect(stand, Color(1.0, 0.86, 0.40, 0.55 * flash_t))
		draw_rect(stand.grow(10.0), Color(1.0, 0.92, 0.55, 0.28 * flash_t), false, 6.0)


func _draw_spotlight(stand: Rect2) -> void:
	var apex: Vector2 = Vector2(stand.get_center().x, stand.position.y - 90.0)
	var left: Vector2 = Vector2(stand.position.x + 8.0, stand.end.y - 8.0)
	var right: Vector2 = Vector2(stand.end.x - 8.0, stand.end.y - 8.0)
	draw_colored_polygon(PackedVector2Array([apex, left, right]), Color(1.0, 0.86, 0.45, 0.18))
	draw_circle(Vector2(stand.get_center().x, stand.position.y + 18.0), 78.0, Color(1.0, 0.90, 0.55, 0.12))
	draw_circle(stand.get_center(), minf(stand.size.x, stand.size.y) * 0.42, Color(1.0, 0.84, 0.40, 0.10))


func _draw_ribbon(stand: Rect2) -> void:
	draw_rect(stand, Color(0.10, 0.07, 0.05, 0.78))
	var gold: Color = Color("E4B75A")
	var band_h: float = 22.0
	var hy: float = stand.get_center().y - band_h * 0.5
	draw_rect(Rect2(stand.position.x, hy, stand.size.x, band_h), gold)
	draw_rect(Rect2(stand.position.x, hy, stand.size.x, band_h), Color("8A6A28"), false, 2.0)
	var vx: float = stand.get_center().x - band_h * 0.5
	draw_rect(Rect2(vx, stand.position.y, band_h, stand.size.y), gold)
	draw_rect(Rect2(vx, stand.position.y, band_h, stand.size.y), Color("8A6A28"), false, 2.0)
	var c: Vector2 = stand.get_center()
	draw_circle(c, 18.0, Color("F6E08A"))
	draw_circle(c, 18.0, gold, false, 2.0)
	_draw_label(c + Vector2(0.0, stand.size.y * 0.5 - 38.0), "Click to unveil", 14, gold)


func _draw_platform(rect: Rect2, featured: bool = false) -> void:
	draw_rect(Rect2(rect.position + Vector2(6, 10), rect.size), Color(0, 0, 0, 0.28))
	draw_rect(rect, PLATFORM)
	draw_rect(Rect2(rect.position.x, rect.end.y - 16, rect.size.x, 16), PLATFORM_LIP)
	var border: Color = Color("F0D070") if featured else Ui.LINE
	draw_rect(rect, border, false, 3.0 if featured else 2.0)
	var glow: float = 0.12 if featured else 0.06
	draw_circle(rect.get_center() + Vector2(0, -18), minf(rect.size.x, rect.size.y) * 0.36, Color(0.89, 0.72, 0.35, glow))


func _draw_plaque(center: Vector2, title: String, featured: bool = false) -> void:
	var font: Font = ThemeDB.fallback_font
	var font_size: int = 16 if featured else 14
	var text_w: float = font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var pop: float = 1.0
	if featured:
		pop += 0.16 * pop_t
	var size: Vector2 = Vector2(maxf(158.0, text_w + 36.0), 26.0 if featured else 24.0) * pop
	var rect: Rect2 = Rect2(center - size * 0.5, size)
	draw_rect(rect, Color("3A2A14") if featured else Color("2C2118"))
	draw_rect(rect, Color("F0D070") if featured else Ui.GOLD, false, 2.2 if featured else 1.5)
	_draw_label(center + Vector2(0, 5), title, font_size, Color("FFE08A") if featured else Ui.GOLD)


func _fit(mount: Rect2, local_min: Vector2, local_max: Vector2) -> Transform2D:
	var size := local_max - local_min
	var inner := Rect2(mount.position + Vector2(6, 6), mount.size - Vector2(12, 12))
	var s: float = minf(inner.size.x / maxf(size.x, 1.0), inner.size.y / maxf(size.y, 1.0))
	var origin := Vector2(
		inner.get_center().x - (local_min.x + local_max.x) * 0.5 * s,
		inner.end.y - local_max.y * s
	)
	return Transform2D(0.0, Vector2(s, s), 0.0, origin)


func _rect(xf: Transform2D, x: float, y: float, w: float, h: float, owned: bool, clean: bool) -> void:
	var a := xf * Vector2(x, y)
	var b := xf * Vector2(x + w, y + h)
	_draw_bone_rect(Rect2(a, b - a), owned, clean)


func _poly(xf: Transform2D, locals: PackedVector2Array, owned: bool, clean: bool) -> void:
	var pts := PackedVector2Array()
	for p in locals:
		pts.append(xf * p)
	_draw_bone_poly(pts, owned, clean)


func _draw_bone_rect(rect: Rect2, owned: bool, clean: bool) -> void:
	if owned:
		var color := Color("F7E9C6") if clean else Color("8A6A3E")
		draw_rect(rect, color)
		draw_rect(rect, color.darkened(0.18), false, 1.2)
	else:
		draw_rect(rect, EMPTY_FILL)
		draw_rect(rect, EMPTY_LINE, false, 2.0)


func _draw_bone_poly(points: PackedVector2Array, owned: bool, clean: bool) -> void:
	if points.size() < 3:
		return
	var fill := Color("F7E9C6") if owned and clean else Color("8A6A3E")
	if not owned:
		fill = EMPTY_FILL
	var line := fill.darkened(0.18) if owned else EMPTY_LINE
	draw_colored_polygon(points, fill)
	for i in points.size():
		draw_line(points[i], points[(i + 1) % points.size()], line, 2.0, true)


func _draw_label(center: Vector2, text: String, font_size: int, color: Color) -> void:
	var font := ThemeDB.fallback_font
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, center + Vector2(-width * 0.5, 0.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
