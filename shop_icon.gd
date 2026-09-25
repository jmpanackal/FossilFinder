extends Control

## Drawn shop glyphs. Tool shapes match tool_icon.gd; extras cover site, exhibit, ranks, and locked chests.

var glyph: String = "shovel"
var accent := Color("E4B75A")
var muted: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup(kind: String, color: Color, dim: bool = false) -> void:
	glyph = kind
	accent = color
	muted = dim
	queue_redraw()


static func glyph_for(id: String) -> String:
	match id:
		"hands_click":
			return "click"
		"hands_hold":
			return "hold"
		"shovel_click":
			return "shovel"
		"shovel_hold":
			return "hold"
		"shovel_radius":
			return "scoop"
		"shovel_super":
			return "super_shovel"
		"shovel_soft":
			return "soft"
		"pick_click":
			return "pick"
		"pick_hold":
			return "hold"
		"pick_super":
			return "super_pick"
		"pick_soft":
			return "soft"
		"brush_speed":
			return "brush"
		"brush_master":
			return "super_brush"
		"round_time":
			return "shift"
		"dirt_pay":
			return "soil"
		"site_size":
			return "claim"
		"scrap_bed":
			return "scrap"
		"rich_bed":
			return "rich"
		"site_expand":
			return "claim"
		"rock_pay":
			return "stone"
		"money_mult":
			return "keen"
		"fossil_value":
			return "fossil"
		"passive_miner":
			return "hired"
		"lighting":
			return "lighting"
		"benches":
			return "bench"
		"glass_case":
			return "case"
		"labels":
			return "labels"
		"gift_shop":
			return "gift"
		"crowds":
			return "crowds"
		"restoration":
			return "restore"
		_:
			return "click"


static func glyph_for_cat(cat: String) -> String:
	match cat:
		"Hands":
			return "hands"
		"Shovel":
			return "shovel"
		"Pickaxe":
			return "pick"
		"Brush":
			return "brush"
		"Site":
			return "site"
		"Exhibit":
			return "exhibit"
		_:
			return "hands"


func _draw() -> void:
	if size.x < 2.0 or size.y < 2.0:
		return
	var ink: Color = accent.darkened(0.18) if muted else accent
	var c: Vector2 = size * 0.5
	var k: float = minf(size.x, size.y) / 36.0
	match glyph:
		"hands":
			_draw_hands(c, k, ink)
		"shovel", "super_shovel":
			_draw_shovel(c, k, ink)
			if glyph == "super_shovel":
				_draw_star(c + Vector2(-10, -11) * k, k * 0.72, ink.lightened(0.2))
		"pick", "super_pick":
			_draw_pick(c, k, ink)
			if glyph == "super_pick":
				_draw_star(c + Vector2(-11, -11) * k, k * 0.72, ink.lightened(0.2))
		"brush", "super_brush":
			_draw_brush(c, k, ink)
			if glyph == "super_brush":
				_draw_star(c + Vector2(-11, -11) * k, k * 0.72, ink.lightened(0.2))
		"site":
			_draw_site(c, k, ink)
		"exhibit":
			_draw_exhibit(c, k, ink)
		"chest":
			_draw_chest(c, k, ink)
		"click":
			_draw_click(c, k, ink)
		"hold":
			_draw_hold(c, k, ink)
		"scoop":
			_draw_scoop(c, k, ink)
		"soft":
			_draw_soft(c, k, ink)
		"shift":
			_draw_shift(c, k, ink)
		"soil":
			_draw_soil(c, k, ink)
		"claim":
			_draw_claim(c, k, ink)
		"scrap":
			_draw_bone(c, k, ink, 0.72)
		"rich":
			_draw_bone(c, k, ink, 1.12)
		"stone":
			_draw_stone(c, k, ink)
		"keen":
			_draw_keen(c, k, ink)
		"fossil":
			_draw_fossil(c, k, ink)
		"hired":
			_draw_hired(c, k, ink)
		"lighting":
			_draw_lighting(c, k, ink)
		"bench":
			_draw_bench(c, k, ink)
		"case":
			_draw_case(c, k, ink)
		"labels":
			_draw_labels(c, k, ink)
		"gift":
			_draw_gift(c, k, ink)
		"crowds":
			_draw_crowds(c, k, ink)
		"restore":
			_draw_restore(c, k, ink)
		_:
			_draw_hands(c, k, ink)


func _draw_hands(c: Vector2, k: float, ink: Color) -> void:
	draw_circle(c + Vector2(0, 4) * k, 8.5 * k, ink)
	draw_line(c + Vector2(-8, 2) * k, c + Vector2(-8, -11) * k, ink, 2.6 * k)
	draw_line(c + Vector2(-3, 0) * k, c + Vector2(-3, -14) * k, ink, 2.6 * k)
	draw_line(c + Vector2(2, 0) * k, c + Vector2(2, -13) * k, ink, 2.6 * k)
	draw_line(c + Vector2(7, 2) * k, c + Vector2(7, -10) * k, ink, 2.6 * k)


func _draw_shovel(c: Vector2, k: float, ink: Color) -> void:
	draw_line(c + Vector2(-10, 14) * k, c + Vector2(8, -10) * k, ink, 4.0 * k)
	var scoop := PackedVector2Array([
		c + Vector2(4, -16) * k,
		c + Vector2(16, -8) * k,
		c + Vector2(12, 4) * k,
		c + Vector2(0, -4) * k,
	])
	draw_colored_polygon(scoop, ink)


func _draw_pick(c: Vector2, k: float, ink: Color) -> void:
	draw_line(c + Vector2(-4, 14) * k, c + Vector2(6, -6) * k, ink, 4.0 * k)
	draw_line(c + Vector2(-14, -8) * k, c + Vector2(16, 2) * k, ink, 5.0 * k)
	draw_circle(c + Vector2(6, -6) * k, 3.0 * k, ink)


func _draw_brush(c: Vector2, k: float, ink: Color) -> void:
	draw_line(c + Vector2(-8, 14) * k, c + Vector2(4, -2) * k, ink, 4.0 * k)
	draw_line(c + Vector2(4, -2) * k, c + Vector2(-2, -12) * k, ink.lightened(0.15), 2.2 * k)
	draw_line(c + Vector2(4, -2) * k, c + Vector2(6, -14) * k, ink.lightened(0.15), 2.2 * k)
	draw_line(c + Vector2(4, -2) * k, c + Vector2(12, -10) * k, ink.lightened(0.15), 2.2 * k)
	draw_circle(c + Vector2(4, -2) * k, 3.2 * k, ink)


func _draw_site(c: Vector2, k: float, ink: Color) -> void:
	var cell := 8.0 * k
	var gap := 2.0 * k
	var origin: Vector2 = c - Vector2(cell + gap * 0.5, cell + gap * 0.5)
	for x in 2:
		for y in 2:
			var box := Rect2(origin + Vector2(float(x) * (cell + gap), float(y) * (cell + gap)), Vector2(cell, cell))
			draw_rect(box, ink.darkened(0.12 if (x + y) % 2 == 0 else 0.28))
			draw_rect(box, ink, false, 1.2 * k)


func _draw_exhibit(c: Vector2, k: float, ink: Color) -> void:
	draw_rect(Rect2(c + Vector2(-11, 6) * k, Vector2(22, 5) * k), ink)
	draw_rect(Rect2(c + Vector2(-7, 1) * k, Vector2(14, 5) * k), ink.darkened(0.15))
	draw_circle(c + Vector2(0, -6) * k, 5.5 * k, ink.lightened(0.08))
	draw_line(c + Vector2(-6, -5) * k, c + Vector2(6, -7) * k, ink.darkened(0.25), 2.0 * k)


func _draw_chest(c: Vector2, k: float, ink: Color) -> void:
	var body := Rect2(c + Vector2(-12, -2) * k, Vector2(24, 14) * k)
	var lid := Rect2(c + Vector2(-13, -12) * k, Vector2(26, 11) * k)
	draw_rect(lid, ink.darkened(0.08))
	draw_rect(lid, ink.darkened(0.35), false, 1.4 * k)
	draw_rect(body, ink)
	draw_rect(body, ink.darkened(0.35), false, 1.4 * k)
	draw_rect(Rect2(c + Vector2(-12, -2) * k, Vector2(24, 2.4) * k), ink.lightened(0.12))
	draw_circle(c + Vector2(0, 4) * k, 2.4 * k, Color("2A2118"))
	draw_circle(c + Vector2(0, 4) * k, 1.3 * k, ink.lightened(0.25))


func _draw_click(c: Vector2, k: float, ink: Color) -> void:
	_draw_hands(c + Vector2(-2, 2) * k, k * 0.82, ink)
	draw_line(c + Vector2(8, -12) * k, c + Vector2(8, -2) * k, ink.lightened(0.15), 2.4 * k)
	var head := PackedVector2Array([
		c + Vector2(8, 2) * k,
		c + Vector2(4, -3) * k,
		c + Vector2(12, -3) * k,
	])
	draw_colored_polygon(head, ink.lightened(0.15))


func _draw_hold(c: Vector2, k: float, ink: Color) -> void:
	for i in 3:
		var y: float = -10.0 + float(i) * 8.0
		draw_rect(Rect2(c + Vector2(-11, y) * k, Vector2(22, 5) * k), ink.darkened(0.05 * float(i)))


func _draw_scoop(c: Vector2, k: float, ink: Color) -> void:
	draw_line(c + Vector2(-4, 12) * k, c + Vector2(-4, -2) * k, ink, 3.4 * k)
	var scoop := PackedVector2Array([
		c + Vector2(-14, -2) * k,
		c + Vector2(14, -2) * k,
		c + Vector2(10, 8) * k,
		c + Vector2(-10, 8) * k,
	])
	draw_colored_polygon(scoop, ink)


func _draw_soft(c: Vector2, k: float, ink: Color) -> void:
	draw_arc(c + Vector2(0, 4) * k, 11.0 * k, PI, TAU, 12, ink, 3.2 * k)
	draw_circle(c + Vector2(-6, 2) * k, 3.2 * k, ink)
	draw_circle(c + Vector2(0, 0) * k, 3.2 * k, ink)
	draw_circle(c + Vector2(6, 2) * k, 3.2 * k, ink)


func _draw_shift(c: Vector2, k: float, ink: Color) -> void:
	draw_arc(c, 12.0 * k, 0.0, TAU, 24, ink, 2.4 * k)
	draw_line(c, c + Vector2(0, -7) * k, ink, 2.2 * k)
	draw_line(c, c + Vector2(6, 3) * k, ink, 2.0 * k)


func _draw_soil(c: Vector2, k: float, ink: Color) -> void:
	draw_circle(c + Vector2(0, 2) * k, 9.0 * k, ink)
	draw_circle(c + Vector2(-2, 0) * k, 2.2 * k, Color("2A2118"))
	draw_line(c + Vector2(-6, 8) * k, c + Vector2(8, 8) * k, ink.darkened(0.25), 2.0 * k)


func _draw_claim(c: Vector2, k: float, ink: Color) -> void:
	draw_rect(Rect2(c + Vector2(-11, -7) * k, Vector2(16, 11) * k), ink, false, 1.8 * k)
	draw_rect(Rect2(c + Vector2(-5, -3) * k, Vector2(16, 11) * k), ink.lightened(0.12), false, 2.0 * k)


func _draw_bone(c: Vector2, k: float, ink: Color, scale_mul: float) -> void:
	var s: float = k * scale_mul
	draw_circle(c + Vector2(-8, -3) * s, 3.4 * s, ink)
	draw_circle(c + Vector2(-8, 3) * s, 3.4 * s, ink)
	draw_circle(c + Vector2(8, -3) * s, 3.4 * s, ink)
	draw_circle(c + Vector2(8, 3) * s, 3.4 * s, ink)
	draw_line(c + Vector2(-7, 0) * s, c + Vector2(7, 0) * s, ink, 4.2 * s)


func _draw_stone(c: Vector2, k: float, ink: Color) -> void:
	var rock := PackedVector2Array([
		c + Vector2(-10, 6) * k,
		c + Vector2(-8, -8) * k,
		c + Vector2(4, -11) * k,
		c + Vector2(12, -2) * k,
		c + Vector2(8, 8) * k,
		c + Vector2(-4, 10) * k,
	])
	draw_colored_polygon(rock, ink)


func _draw_keen(c: Vector2, k: float, ink: Color) -> void:
	var eye := PackedVector2Array([
		c + Vector2(-12, 0) * k,
		c + Vector2(0, -7) * k,
		c + Vector2(12, 0) * k,
		c + Vector2(0, 7) * k,
	])
	draw_colored_polygon(eye, ink)
	draw_circle(c, 3.2 * k, Color("2A2118"))


func _draw_fossil(c: Vector2, k: float, ink: Color) -> void:
	_draw_bone(c + Vector2(0, 2) * k, k, ink, 0.86)
	draw_line(c + Vector2(-2, -12) * k, c + Vector2(0, -6) * k, ink.lightened(0.15), 2.0 * k)
	draw_line(c + Vector2(3, -11) * k, c + Vector2(1, -6) * k, ink.lightened(0.15), 2.0 * k)


func _draw_hired(c: Vector2, k: float, ink: Color) -> void:
	draw_circle(c + Vector2(0, -8) * k, 5.0 * k, ink)
	draw_rect(Rect2(c + Vector2(-7, -3) * k, Vector2(14, 12) * k), ink)
	draw_rect(Rect2(c + Vector2(-9, -5) * k, Vector2(18, 3) * k), ink.lightened(0.1))


func _draw_lighting(c: Vector2, k: float, ink: Color) -> void:
	draw_circle(c + Vector2(0, -3) * k, 8.0 * k, ink)
	draw_rect(Rect2(c + Vector2(-4, 5) * k, Vector2(8, 5) * k), ink.darkened(0.1))
	draw_line(c + Vector2(-3, 11) * k, c + Vector2(3, 11) * k, ink, 2.0 * k)


func _draw_bench(c: Vector2, k: float, ink: Color) -> void:
	draw_rect(Rect2(c + Vector2(-13, -2) * k, Vector2(26, 4) * k), ink)
	draw_rect(Rect2(c + Vector2(-11, 2) * k, Vector2(3, 10) * k), ink.darkened(0.1))
	draw_rect(Rect2(c + Vector2(8, 2) * k, Vector2(3, 10) * k), ink.darkened(0.1))
	draw_rect(Rect2(c + Vector2(-13, -8) * k, Vector2(4, 6) * k), ink)


func _draw_case(c: Vector2, k: float, ink: Color) -> void:
	draw_rect(Rect2(c + Vector2(-10, -10) * k, Vector2(20, 16) * k), ink, false, 2.0 * k)
	draw_rect(Rect2(c + Vector2(-12, 6) * k, Vector2(24, 5) * k), ink)
	draw_line(c + Vector2(-6, -4) * k, c + Vector2(6, -6) * k, ink.lightened(0.2), 2.0 * k)


func _draw_labels(c: Vector2, k: float, ink: Color) -> void:
	var tag := PackedVector2Array([
		c + Vector2(-10, -8) * k,
		c + Vector2(8, -8) * k,
		c + Vector2(12, 0) * k,
		c + Vector2(8, 8) * k,
		c + Vector2(-10, 8) * k,
	])
	draw_colored_polygon(tag, ink)
	draw_circle(c + Vector2(8, 0) * k, 1.6 * k, Color("2A2118"))


func _draw_gift(c: Vector2, k: float, ink: Color) -> void:
	draw_rect(Rect2(c + Vector2(-10, -4) * k, Vector2(20, 14) * k), ink)
	draw_rect(Rect2(c + Vector2(-11, -8) * k, Vector2(22, 5) * k), ink.lightened(0.12))
	draw_rect(Rect2(c + Vector2(-2, -8) * k, Vector2(4, 18) * k), ink.darkened(0.2))
	draw_arc(c + Vector2(-3, -10) * k, 4.0 * k, PI, TAU, 8, ink.lightened(0.2), 1.8 * k)
	draw_arc(c + Vector2(3, -10) * k, 4.0 * k, PI, TAU, 8, ink.lightened(0.2), 1.8 * k)


func _draw_crowds(c: Vector2, k: float, ink: Color) -> void:
	draw_circle(c + Vector2(-6, -6) * k, 4.0 * k, ink)
	draw_circle(c + Vector2(7, -7) * k, 3.6 * k, ink.darkened(0.12))
	draw_rect(Rect2(c + Vector2(-11, -1) * k, Vector2(10, 11) * k), ink)
	draw_rect(Rect2(c + Vector2(3, 0) * k, Vector2(9, 10) * k), ink.darkened(0.12))


func _draw_restore(c: Vector2, k: float, ink: Color) -> void:
	_draw_brush(c + Vector2(-2, 2) * k, k * 0.78, ink)
	_draw_star(c + Vector2(8, -9) * k, k * 0.62, ink.lightened(0.2))


func _draw_star(c: Vector2, k: float, ink: Color) -> void:
	var pts := PackedVector2Array()
	for i in 5:
		var a: float = -PI * 0.5 + float(i) * TAU / 5.0
		pts.append(c + Vector2(cos(a), sin(a)) * 6.0 * k)
		var b: float = a + TAU / 10.0
		pts.append(c + Vector2(cos(b), sin(b)) * 2.6 * k)
	draw_colored_polygon(pts, ink)
