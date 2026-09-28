extends Node2D

const Ui := preload("res://ui_style.gd")
const ArtCatalogScript := preload("res://art_catalog.gd")

const HALL := Vector2(2000, 1480)
const FLOOR := Color("3C2C20")
const FLOOR_DARK := Color("2E2218")
const FLOOR_PLANK := Color("443224")
const WALL := Color("2A1C14")
const WALL_TRIM := Color("4A3426")
const RUNNER := Color("6A3C20")
const RUNNER_EDGE := Color("A88848")
const RUNNER_STRIPE := Color("9A7040")
const RUNNER_BAND := Rect2(972, 218, 56, 0)
const PLATFORM := Color("3A2C20")
const PLATFORM_LIP := Color("2A1E16")
const EMPTY_FILL := Color(0.38, 0.30, 0.24, 0.20)
const EMPTY_LINE := Color(0.58, 0.46, 0.36, 0.62)
const MIN_LABEL_SCREEN_PX := 11.0
const PLAQUE_CLEARANCE := 8.0
const RUNNER_X := 1000.0
const PAD_GAP := 18.0
const VIEW_PAD := 22.0
const VIEW_GAP := 36.0
const WALK_SPEED := 180.0
const NORTH_CROSS_Y := 500.0
const SIDE_HALL_Y := 598.0
const STAND_LAYOUT := {
	"t_rex": {"title": "T. rex", "x": 760.0, "y": 236.0, "w": 480.0, "h": 250.0},
	"small_finds": {"title": "Small Finds", "x": 70.0, "y": 236.0, "w": 400.0, "h": 230.0},
	"plant_fossils": {"title": "Plant Fossils", "x": 1530.0, "y": 236.0, "w": 400.0, "h": 230.0},
	"triceratops": {"title": "Triceratops", "x": 70.0, "y": 598.0, "w": 460.0, "h": 260.0},
	"brachiosaurus": {"title": "Brachiosaurus", "x": 1470.0, "y": 598.0, "w": 460.0, "h": 280.0},
	"velociraptor": {"title": "Velociraptor", "x": 70.0, "y": 1100.0, "w": 400.0, "h": 230.0},
	"stegosaurus": {"title": "Stegosaurus", "x": 1470.0, "y": 1100.0, "w": 460.0, "h": 230.0},
}
const HALL_BENCH_SIZE := Vector2(100, 28)
const HALL_BENCH_SOUTH_GAP := 30.0
const HALL_AISLE := Rect2(920.0, 218.0, 160.0, 1262.0)
const HALL_LAMP_WEST_X := 28.0
const HALL_LAMP_EAST_X := 1972.0
const HALL_LAMP_NORTH_Y := 158.0
const HALL_LAMP_RADII := [11.0, 11.0, 8.0, 8.0, 7.0]
const HALL_LAMP_FIXTURE := Vector2(16, 10)
const HALL_ROPE_SIZE := Vector2(64, 18)
const HALL_ROPE_AISLE_GAP := 8.0
const HALL_FRAME_RECTS := [
	Rect2(220, 86, 200, 96),
	Rect2(1630, 86, 200, 96),
]
const HALL_GIFT_RECT := Rect2(1280, 388, 96, 48)
const HALL_GIFT_SOUTH_RECT := Rect2(1120, 1420, 140, 40)
const HALL_CART_RECT := Rect2(16, 478, 72, 36)
const HALL_CART_SOUTH_RECT := Rect2(80, 1420, 72, 36)
const HALL_BUNTING_RECT := Rect2(810, 4, 380, 28)

var flash_stand_id: String = ""
var flash_t: float = 0.0
var pop_t: float = 0.0
var _crowd_t: float = 0.0
var _guests: Array = []
## Guests walk every frame; the hall does not. They draw on their own layer so
## the ~2000x1480 hall only re-records when an exhibit actually changes.
var _guest_layer: _GuestLayer


func _ready() -> void:
	_guest_layer = _GuestLayer.new()
	_guest_layer.host = self
	add_child(_guest_layer)


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
	if visitor_sprite_count() > 0:
		_crowd_t += delta
		_step_guests(delta)
		_redraw_guests()
	elif not _guests.is_empty():
		_guests.clear()
		_redraw_guests()
	if dirty:
		queue_redraw()


func _redraw_guests() -> void:
	if _guest_layer != null:
		_guest_layer.queue_redraw()
	else:
		queue_redraw()


func visitor_sprite_count() -> int:
	if GameState.has_method("visitor_sprite_count"):
		return int(GameState.call("visitor_sprite_count"))
	return 0


func stand_rect(stand_id: String) -> Rect2:
	if not STAND_LAYOUT.has(stand_id):
		return Rect2()
	var info: Dictionary = STAND_LAYOUT[stand_id]
	return Rect2(float(info["x"]), float(info["y"]), float(info["w"]), float(info["h"]))


func stand_mount_rect(stand_id: String) -> Rect2:
	return stand_mount_rect_for(stand_rect(stand_id))


func stand_mount_rect_for(stand: Rect2) -> Rect2:
	if stand.size == Vector2.ZERO:
		return Rect2()
	return Rect2(stand.position + Vector2(22.0, 16.0), stand.size - Vector2(44.0, 54.0))


func stand_id_at(hall_pos: Vector2) -> String:
	for stand_id in STAND_LAYOUT:
		if stand_rect(str(stand_id)).has_point(hall_pos):
			return str(stand_id)
	return ""


func display_slots(piece_id: String) -> int:
	return int(GameState.piece_need(piece_id))


func case_owned(piece_id: String) -> bool:
	return piece_id != "" and GameState.has_piece(piece_id)


func slot_on(piece_id: String, slot: int) -> bool:
	return slot >= 0 and int(GameState.piece_count(piece_id)) > slot


func _slot_clean(piece_id: String, slot: int) -> bool:
	return slot_on(piece_id, slot) and _owned_clean(piece_id)


func _draw() -> void:
	_draw_hall()
	_draw_t_rex_bay()
	_draw_small_finds_bay()
	_draw_plant_fossils_bay()
	_draw_triceratops_bay()
	_draw_sauropod_bay()
	_draw_raptor_bay()
	_draw_stego_bay()
	if _guest_layer == null:
		_draw_visitors()
	else:
		_guest_layer.queue_redraw()


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
	if hall_runner_visible():
		var runner: Rect2 = hall_runner_rect()
		draw_rect(runner, RUNNER)
		draw_rect(Rect2(runner.position.x + 20.0, runner.position.y, 16.0, runner.size.y), RUNNER_STRIPE)
		draw_rect(Rect2(runner.position.x, runner.position.y, 3.0, runner.size.y), RUNNER_EDGE)
		draw_rect(Rect2(runner.end.x - 3.0, runner.position.y, 3.0, runner.size.y), RUNNER_EDGE)
	var lamps: PackedVector2Array = hall_lamp_centers()
	for frame in hall_frame_rects():
		_draw_wall_frame(frame.position, frame.size)
	_draw_pillar(Vector2(896, 186))
	_draw_pillar(Vector2(1076, 186))
	for bench in hall_bench_rects():
		_draw_bench(bench.position)
	_draw_gift_counter()
	_draw_cleanup_cart()
	_draw_crowd_ropes()
	for i in lamps.size():
		_draw_warm_light(lamps[i], float(HALL_LAMP_RADII[i]))
	_draw_hall_board()
	_draw_opening_bunting()


func _draw_wall_frame(pos: Vector2, size: Vector2) -> void:
	var rank: int = _museum_rank("labels")
	var rect := Rect2(pos, size)
	var hook_w: float = 4.0 if rank <= 1 else 6.0
	draw_rect(Rect2(pos.x + size.x * 0.5 - hook_w * 0.5, pos.y - 8.0, hook_w, 10.0), Color("7A5A38"))
	draw_rect(rect.grow(2.0 if rank <= 1 else 3.0), Color("5A3C18"))
	draw_rect(rect, Color("C9A056") if rank <= 1 else Color("E4B75A"), false, 2.0 if rank <= 1 else 3.0)
	draw_rect(rect.grow(-5.0), Color("3A2818"))
	var picture := Rect2(pos + Vector2(12, 12), size - Vector2(24, 24))
	draw_rect(picture, Color("5A3C24"))
	draw_rect(Rect2(picture.position.x + 10.0, picture.position.y + 16.0, picture.size.x - 20.0, picture.size.y - 28.0), Color("B8A070") if rank <= 1 else Color("C8B080"))
	draw_rect(picture, Color("C9A056") if rank <= 1 else Color("E4B75A"), false, 1.2)


func _draw_pillar(top: Vector2) -> void:
	var height: float = HALL.y - top.y - 12.0
	draw_rect(Rect2(top.x, top.y, 28, height), Color("2A2118"))
	draw_rect(Rect2(top.x - 8, top.y, 44, 18), Color("4A3A2A"))
	draw_rect(Rect2(top.x - 6, HALL.y - 20, 40, 16), Color("4A3A2A"))
	draw_rect(Rect2(top.x + 6, top.y + 20, 6, height - 30), Color(0.89, 0.72, 0.35, 0.08))


func _draw_bench(pos: Vector2) -> void:
	draw_rect(Rect2(pos.x, pos.y + 2.0, 100, 14), Color("5A3C28"))
	draw_rect(Rect2(pos.x, pos.y, 100, 10), Color("8A5A32"))
	draw_rect(Rect2(pos.x, pos.y, 100, 10), Color("E4B75A"), false, 1.5)
	draw_rect(Rect2(pos.x + 8, pos.y + 14, 12, 14), Color("3A281C"))
	draw_rect(Rect2(pos.x + 80, pos.y + 14, 12, 14), Color("3A281C"))


func _draw_warm_light(center: Vector2, radius: float) -> void:
	var a: float = 0.14 + 0.018 * float(mini(_museum_rank("lighting"), 5))
	draw_circle(center, radius, Color(1.0, 0.84, 0.42, a))
	draw_circle(center, radius * 0.52, Color(1.0, 0.90, 0.55, a * 0.85))
	var shade: Rect2 = hall_lamp_fixture_rect_at(center)
	draw_rect(shade, Color("4A3420"))
	draw_rect(shade, Color("C9A056"), false, 1.0)
	draw_circle(center + Vector2(0.0, 1.0), 3.0, Color("E8C878"))
	draw_rect(Rect2(center.x - 1.0, center.y - 10.0, 2.0, 6.0), Color("A88848"))


func _draw_gift_counter() -> void:
	_draw_gift_prop(hall_gift_rect(), true)
	_draw_gift_prop(hall_gift_south_rect(), false)


func _draw_gift_prop(counter: Rect2, dress: bool) -> void:
	if counter.size == Vector2.ZERO:
		return
	var rank: int = _museum_rank("gift_shop")
	draw_rect(counter, Color("5A3C28"))
	draw_rect(Rect2(counter.position.x, counter.position.y, counter.size.x, 8.0 if rank <= 1 else 10.0), Color("7A4E2C") if rank <= 1 else Color("8A5A32"))
	draw_rect(counter, Color("C9A056") if rank <= 1 else Color("E4B75A"), false, 1.0 if rank <= 1 else 1.6)
	if dress:
		_draw_label(Vector2(counter.get_center().x, counter.position.y + 28.0), "Gifts", 12, Color("C9A056") if rank <= 1 else Color("FFE08A"))
	if dress and hall_gift_has_rack():
		var rack := Rect2(counter.position.x + 8.0, counter.position.y - 32.0, 40.0, 32.0)
		draw_rect(rack, Color("3A2A1C"))
		draw_rect(rack, Color("FFE08A"), false, 1.5)
		for i in 3:
			draw_rect(Rect2(rack.position.x + 4.0 + float(i) * 11.0, rack.position.y + 4.0, 8.0, 22.0), Color("C8B080"))
	if dress and hall_gift_has_stack():
		var stack := Rect2(counter.end.x - 40.0, counter.position.y - 18.0, 28.0, 18.0)
		draw_rect(stack, Color("6A3A2A"))
		draw_rect(Rect2(stack.position.x + 4.0, stack.position.y - 8.0, 20.0, 8.0), Color("8A4A32"))


func _draw_cleanup_cart() -> void:
	_draw_cart_prop(hall_cart_rect(), true)
	_draw_cart_prop(hall_cart_south_rect(), false)


func _draw_cart_prop(cart: Rect2, dress: bool) -> void:
	if cart.size == Vector2.ZERO:
		return
	var rank: int = _museum_rank("restoration")
	draw_rect(cart, Color("4A4030"))
	draw_rect(Rect2(cart.position.x, cart.position.y, cart.size.x, 8.0 if rank <= 1 else 10.0), Color("5A4A36") if rank <= 1 else Color("6A5A40"))
	draw_rect(cart, Color("C9A056") if rank <= 1 else Color("E4B75A"), false, 1.0 if rank <= 1 else 1.6)
	draw_circle(Vector2(cart.position.x + 12.0, cart.end.y), 6.0, Color("2A2418"))
	draw_circle(Vector2(cart.end.x - 12.0, cart.end.y), 6.0, Color("2A2418"))
	if dress and hall_cart_has_bucket():
		var bucket := Rect2(cart.end.x + 8.0, cart.position.y + 6.0, 18.0, 22.0)
		draw_rect(bucket, Color("4A5A6A"))
		draw_rect(Rect2(bucket.position.x - 2.0, bucket.position.y, bucket.size.x + 4.0, 4.0), Color("3A4A5A"))


func _draw_crowd_ropes() -> void:
	var rank: int = _museum_rank("crowds")
	var post_r: float = 4.0 if rank <= 1 else 6.0
	var velvet_w: float = 2.0 if rank <= 1 else 3.0
	var post_gold: Color = Color("C9A056") if rank <= 1 else Color("E4B75A")
	for rope in hall_crowd_rope_rects():
		var left := Vector2(rope.position.x + 6.0, rope.end.y)
		var right := Vector2(rope.end.x - 6.0, rope.end.y)
		draw_circle(left, post_r, Color("3A2818"))
		draw_circle(right, post_r, Color("3A2818"))
		draw_rect(Rect2(left.x - 2.0, rope.position.y, 4.0, rope.size.y), post_gold)
		draw_rect(Rect2(right.x - 2.0, rope.position.y, 4.0, rope.size.y), post_gold)
		draw_line(left + Vector2(0.0, -10.0), right + Vector2(0.0, -10.0), Color("6A1C28"), velvet_w)


func _draw_opening_bunting() -> void:
	var band: Rect2 = hall_opening_bunting_rect()
	if band.size == Vector2.ZERO:
		return
	var rank: int = _museum_rank("unveil_crowd")
	draw_rect(Rect2(band.position.x, band.position.y + 4.0, band.size.x, 3.0 if rank <= 1 else 4.0), Color("7A5A24") if rank <= 1 else Color("8A6A28"))
	var flags: int = hall_opening_bunting_flags()
	var step: float = band.size.x / float(maxi(flags, 1))
	var spread: float = 0.28 if rank <= 1 else 0.38
	for i in flags:
		var x: float = band.position.x + step * (float(i) + 0.5)
		var gold: Color = Color("C9A056").lerp(Color("E4B75A"), clampf(float(rank) / 4.0, 0.0, 1.0))
		draw_colored_polygon(PackedVector2Array([
			Vector2(x - step * spread, band.position.y + 6.0),
			Vector2(x + step * spread, band.position.y + 6.0),
			Vector2(x, band.end.y),
		]), gold if i % 2 == 0 else Color("5A1820"))


func _museum_rank(id: String) -> int:
	return int(GameState.levels.get(id, 0))


func hall_amenity_stand_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for stand_id in STAND_LAYOUT:
		var id := str(stand_id)
		if id == "small_finds" or id == "plant_fossils":
			continue
		ids.append(id)
	return ids


func hall_bench_rects() -> Array:
	var rects: Array = []
	var ids: PackedStringArray = hall_amenity_stand_ids()
	var rank: int = mini(_museum_rank("benches"), ids.size())
	for i in rank:
		rects.append(_bench_rect_for_stand(ids[i]))
	return rects


func _bench_rect_for_stand(stand_id: String) -> Rect2:
	var stand: Rect2 = stand_rect(stand_id)
	var size := HALL_BENCH_SIZE
	var x: float = stand.get_center().x - size.x * 0.5
	var y: float = stand.end.y + HALL_BENCH_SOUTH_GAP
	var bench := Rect2(Vector2(x, y), size)
	if HALL_AISLE.intersects(bench) or _runner_path().intersects(bench):
		x = mini(HALL_AISLE.position.x - size.x, stand.end.x - size.x)
		x = maxf(x, stand.position.x)
		bench = Rect2(Vector2(x, y), size)
		if HALL_AISLE.intersects(bench) or _runner_path().intersects(bench):
			x = maxf(HALL_AISLE.end.x, stand.position.x)
			x = mini(x, stand.end.x - size.x)
			bench = Rect2(Vector2(x, y), size)
	return bench


func _runner_path() -> Rect2:
	return Rect2(RUNNER_BAND.position.x, 218.0, RUNNER_BAND.size.x, HALL.y - 218.0)


func hall_lamp_centers() -> PackedVector2Array:
	var lamps := PackedVector2Array()
	var ids: PackedStringArray = hall_amenity_stand_ids()
	var rank: int = mini(_museum_rank("lighting"), ids.size())
	for i in rank:
		lamps.append(_lamp_center_for_stand(ids[i]))
	return lamps


func _lamp_center_for_stand(stand_id: String) -> Vector2:
	var stand: Rect2 = stand_rect(stand_id)
	var cx: float = stand.get_center().x
	if cx < RUNNER_X:
		return Vector2(HALL_LAMP_WEST_X, stand.get_center().y)
	if cx > RUNNER_X:
		return Vector2(HALL_LAMP_EAST_X, stand.get_center().y)
	return Vector2(stand.position.x, HALL_LAMP_NORTH_Y)


func hall_lamp_count() -> int:
	return hall_lamp_centers().size()


func hall_lamp_discs() -> Array:
	var discs: Array = []
	var lamps: PackedVector2Array = hall_lamp_centers()
	for i in lamps.size():
		var radius: float = float(HALL_LAMP_RADII[i])
		discs.append(Rect2(lamps[i] - Vector2(radius, radius), Vector2(radius * 2.0, radius * 2.0)))
	return discs


func hall_lamp_fixture_rect_at(center: Vector2) -> Rect2:
	return Rect2(center - HALL_LAMP_FIXTURE * 0.5, HALL_LAMP_FIXTURE)


func hall_lamp_fixture_rects() -> Array:
	var rects: Array = []
	for lamp in hall_lamp_centers():
		rects.append(hall_lamp_fixture_rect_at(lamp))
	return rects


func hall_lamp_pools() -> Array:
	return hall_lamp_discs()


func hall_runner_visible() -> bool:
	return _museum_rank("lighting") > 0


func hall_runner_rect() -> Rect2:
	if not hall_runner_visible():
		return Rect2()
	return Rect2(RUNNER_BAND.position, Vector2(RUNNER_BAND.size.x, HALL.y - RUNNER_BAND.position.y))


func hall_frame_rects() -> Array:
	if _museum_rank("labels") <= 0:
		return []
	return HALL_FRAME_RECTS.duplicate()


func hall_gift_rect() -> Rect2:
	if _museum_rank("gift_shop") <= 0:
		return Rect2()
	return HALL_GIFT_RECT


func hall_gift_south_rect() -> Rect2:
	if _museum_rank("gift_shop") < 4:
		return Rect2()
	return HALL_GIFT_SOUTH_RECT


func hall_gift_has_rack() -> bool:
	return _museum_rank("gift_shop") >= 2


func hall_gift_has_stack() -> bool:
	return _museum_rank("gift_shop") >= 3


func hall_cart_rect() -> Rect2:
	if _museum_rank("restoration") <= 0:
		return Rect2()
	return HALL_CART_RECT


func hall_cart_south_rect() -> Rect2:
	if _museum_rank("restoration") < 4:
		return Rect2()
	return HALL_CART_SOUTH_RECT


func hall_cart_has_bucket() -> bool:
	return _museum_rank("restoration") >= 2


func hall_hours_rect() -> Rect2:
	return Rect2()


func hall_hours_marks() -> int:
	return 0


func hall_crowd_rope_rects() -> Array:
	var rank: int = _museum_rank("crowds")
	if rank <= 0:
		return []
	var slots: Array = _crowd_rope_slots()
	var ropes: Array = []
	for i in mini(rank, slots.size()):
		ropes.append(slots[i])
	return ropes


func _crowd_rope_slots() -> Array:
	var slots: Array = []
	var last_south: float = -1000.0
	var size := HALL_ROPE_SIZE
	var gap: float = HALL_ROPE_AISLE_GAP
	for stand_id in hall_amenity_stand_ids():
		var south: float = stand_rect(stand_id).end.y
		if south - last_south <= 80.0:
			continue
		last_south = south
		slots.append(Rect2(Vector2(HALL_AISLE.position.x - gap - size.x, south), size))
		slots.append(Rect2(Vector2(HALL_AISLE.end.x + gap, south), size))
	return slots


func hall_opening_bunting_rect() -> Rect2:
	if _museum_rank("unveil_crowd") <= 0:
		return Rect2()
	return HALL_BUNTING_RECT


func hall_opening_bunting_flags() -> int:
	var rank: int = _museum_rank("unveil_crowd")
	if rank <= 0:
		return 0
	return 4 + rank


func hall_case_glass_alpha(stand_id: String) -> float:
	if stand_id != "small_finds" and stand_id != "plant_fossils":
		return 0.0
	var rank: int = _museum_rank("glass_case")
	if rank <= 0:
		return 0.0
	return 0.22 + 0.04 * float(rank)


func hall_case_titles_visible() -> bool:
	return _museum_rank("labels") >= 3


func hall_plaque_gold() -> Color:
	var t: float = clampf(float(_museum_rank("labels")) / 6.0, 0.0, 1.0)
	return Ui.GOLD.lerp(Color("FFE08A"), t)


func hall_board() -> Dictionary:
	var featured: String = ""
	if GameState.featured_stand_id != "":
		featured = GameState.stand_title(GameState.featured_stand_id)
	return {
		"title": "FOSSIL HALL",
		"featured_label": "Featured" if featured != "" else "",
		"featured": featured,
		"status": _hall_board_status(featured != ""),
	}


func hall_board_rect() -> Rect2:
	return Rect2(810.0, 20.0, 380.0, 164.0)


func hall_board_featured_rect() -> Rect2:
	var board: Rect2 = hall_board_rect()
	var top: float = board.position.y + 40.0
	return Rect2(board.position.x + 16.0, top, board.size.x - 32.0, board.end.y - top - 10.0)


func _hall_board_status(has_featured: bool) -> String:
	if has_featured:
		return ""
	if GameState.pieces.is_empty():
		return "The hall is waiting."
	var dusty: bool = false
	var mounted: bool = false
	for piece_id in GameState.pieces:
		var id: String = str(piece_id)
		if GameState.stand_for_piece(id) == "":
			continue
		mounted = true
		var piece: Dictionary = GameState.pieces[id]
		if not bool(piece.get("clean", false)):
			dusty = true
	if not mounted:
		return "The hall is waiting."
	if dusty:
		return "A dusty find is on display."
	return "A clean find is on display."


func _draw_hall_board() -> void:
	var card: Dictionary = hall_board()
	var board: Rect2 = hall_board_rect()
	draw_rect(board, Color("3A2818"))
	draw_rect(board.grow(-3.0), Color("2C1E14"))
	draw_rect(board, Ui.GOLD, false, 2.0)
	_draw_label(Vector2(board.get_center().x, board.position.y + 26.0), str(card.get("title", "")), 16, Ui.GOLD)
	var feat: Rect2 = hall_board_featured_rect()
	var featured: String = str(card.get("featured", ""))
	if featured != "":
		_draw_label(Vector2(feat.get_center().x, feat.position.y + feat.size.y * 0.32), str(card.get("featured_label", "")), 16, Color("C8B080"))
		_draw_label(Vector2(feat.get_center().x, feat.position.y + feat.size.y * 0.64), featured, 26, Color("FFE08A"))
	else:
		_draw_label(Vector2(feat.get_center().x, feat.get_center().y), str(card.get("status", "")), 14, Color("C8B080"))


func south_door() -> Vector2:
	return Vector2(RUNNER_X, HALL.y - 8.0)


func gather_pad(stand_id: String, slot: int = 0) -> Vector2:
	var slots: PackedVector2Array = gather_slots(stand_id)
	if slots.is_empty():
		return south_door()
	return slots[posmod(slot, slots.size())]


func gather_slots(stand_id: String) -> PackedVector2Array:
	var stand: Rect2 = stand_rect(stand_id)
	var slots := PackedVector2Array()
	if stand.size == Vector2.ZERO:
		return slots
	var left: float = stand.position.x + 28.0
	var right: float = stand.end.x - 28.0
	var south_y: float = stand.end.y + VIEW_PAD
	var x: float = left
	while x <= right + 0.5:
		slots.append(Vector2(x, south_y))
		x += VIEW_GAP
	var top: float = stand.position.y + 28.0
	var bot: float = stand.end.y - 20.0
	if stand.end.x < RUNNER_X - 16.0:
		var east_x: float = stand.end.x + VIEW_PAD
		var y: float = top
		while y <= bot + 0.5:
			slots.append(Vector2(east_x, y))
			y += VIEW_GAP
	elif stand.position.x > RUNNER_X + 16.0:
		var west_x: float = stand.position.x - VIEW_PAD
		var y: float = top
		while y <= bot + 0.5:
			slots.append(Vector2(west_x, y))
			y += VIEW_GAP
	return slots


func stand_completeness(stand_id: String) -> float:
	var ids: PackedStringArray = GameState.stand_piece_ids(stand_id)
	if ids.is_empty():
		return 0.0
	var have: int = 0
	var need: int = 0
	for piece_id in ids:
		var quota: int = GameState.piece_need(str(piece_id))
		need += quota
		have += mini(GameState.piece_count(str(piece_id)), quota)
	return float(have) / float(maxi(1, need))


func dwell_seconds(stand_id: String) -> float:
	var seconds: float = 2.0 + 6.0 * stand_completeness(stand_id)
	if GameState.stand_has_pending_unveil(stand_id):
		seconds += 0.8
	if GameState.featured_stand_id == stand_id and GameState.stand_is_filled(stand_id):
		seconds += 1.0
	return seconds


func stand_rate_line(stand_id: String) -> String:
	return "$%.2f / sec" % GameState.stand_income(stand_id)


func stand_rate_rect(stand_id: String) -> Rect2:
	var stand: Rect2 = stand_rect(stand_id)
	if stand.size == Vector2.ZERO:
		return Rect2()
	var font: Font = Ui.display_font()
	var font_size: int = label_font_size(11)
	var text_w: float = font.get_string_size(stand_rate_line(stand_id), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var size := Vector2(text_w + 16.0, float(font_size) + 10.0)
	return Rect2(stand.end.x - 8.0 - size.x, stand.position.y + 8.0, size.x, size.y)


func visitor_positions() -> PackedVector2Array:
	_sync_guests()
	var spots := PackedVector2Array()
	for guest in _guests:
		spots.append(guest["pos"])
	return spots


func _draw_visitors(c: CanvasItem = null) -> void:
	_sync_guests()
	for i in _guests.size():
		_draw_visitor(_guests[i]["pos"], i, c)


func _sync_guests() -> void:
	var n: int = visitor_sprite_count()
	while _guests.size() < n:
		var lane: float = float(_guests.size() % 5 - 2) * 14.0
		var guest: Dictionary = {
			"id": _guests.size(),
			"pos": south_door() + Vector2(lane, 8.0),
			"lane": lane,
			"waypoints": [],
			"stops": PackedStringArray(),
			"stop_i": 0,
			"state": "travel",
			"dwell_left": 0.0,
			"view_stand": "",
			"view_slot": -1,
		}
		_plan_guest(guest)
		_guests.append(guest)
	while _guests.size() > n:
		_guests.pop_back()


func _step_guests(delta: float) -> void:
	_sync_guests()
	for guest in _guests:
		_step_guest(guest, delta)


func _plan_guest(guest: Dictionary) -> void:
	guest["stops"] = _pick_stops()
	guest["stop_i"] = 0
	guest["dwell_left"] = 0.0
	var stops: PackedStringArray = guest["stops"]
	if stops.is_empty():
		guest["state"] = "leave"
		guest["view_stand"] = ""
		guest["view_slot"] = -1
		guest["waypoints"] = _aisle_waypoints(guest["pos"], south_door() + Vector2(guest["lane"], 0.0), float(guest["lane"]))
		return
	guest["state"] = "travel"
	guest["waypoints"] = _aisle_waypoints(guest["pos"], _claim_view_spot(stops[0], guest), float(guest["lane"]))


func _pick_stops() -> PackedStringArray:
	var filled: Array = []
	for stand_id in STAND_LAYOUT:
		if GameState.stand_is_filled(str(stand_id)):
			filled.append(str(stand_id))
	if filled.is_empty():
		return PackedStringArray()
	var picks := PackedStringArray()
	var pool: Array = filled.duplicate()
	var n: int = 1 + randi() % mini(3, pool.size())
	for _i in n:
		if pool.is_empty():
			break
		var total: float = 0.0
		for stand_id in pool:
			total += _stand_weight(str(stand_id))
		var roll: float = randf() * total
		var chosen: String = str(pool[0])
		for stand_id in pool:
			roll -= _stand_weight(str(stand_id))
			if roll <= 0.0:
				chosen = str(stand_id)
				break
		picks.append(chosen)
		pool.erase(chosen)
	return picks


func _stand_weight(stand_id: String) -> float:
	var weight: float = 1.0 + 3.0 * stand_completeness(stand_id)
	if GameState.stand_has_pending_unveil(stand_id):
		weight += 2.0
	if GameState.featured_stand_id == stand_id:
		weight += 2.5
	return weight


func _step_guest(guest: Dictionary, delta: float) -> void:
	if str(guest.get("state", "")) == "dwell":
		guest["dwell_left"] = float(guest["dwell_left"]) - delta
		if float(guest["dwell_left"]) > 0.0:
			return
		_advance_guest(guest)
		return
	var waypoints: Array = guest["waypoints"]
	if waypoints.is_empty():
		_advance_guest(guest)
		return
	if _move_toward(guest, waypoints[0], delta):
		waypoints.remove_at(0)
		guest["waypoints"] = waypoints
		if waypoints.is_empty():
			_advance_guest(guest)


func _advance_guest(guest: Dictionary) -> void:
	var state: String = str(guest.get("state", ""))
	var stops: PackedStringArray = guest["stops"]
	var stop_i: int = int(guest.get("stop_i", 0))
	if state == "travel" and stop_i < stops.size():
		guest["state"] = "dwell"
		guest["dwell_left"] = dwell_seconds(stops[stop_i])
		return
	if state == "dwell":
		guest["stop_i"] = stop_i + 1
		stop_i += 1
		if stop_i < stops.size():
			guest["state"] = "travel"
			guest["waypoints"] = _aisle_waypoints(guest["pos"], _claim_view_spot(stops[stop_i], guest), float(guest["lane"]))
			return
	if state != "leave":
		guest["state"] = "leave"
		guest["view_stand"] = ""
		guest["view_slot"] = -1
		guest["waypoints"] = _aisle_waypoints(guest["pos"], south_door() + Vector2(guest["lane"], 0.0), float(guest["lane"]))
		return
	_plan_guest(guest)


func _claim_view_spot(stand_id: String, guest: Dictionary) -> Vector2:
	var slots: PackedVector2Array = gather_slots(stand_id)
	if slots.is_empty():
		guest["view_stand"] = stand_id
		guest["view_slot"] = 0
		return gather_pad(stand_id)
	var used: Dictionary = {}
	var self_id: int = int(guest.get("id", -1))
	for other in _guests:
		if int(other.get("id", -2)) == self_id:
			continue
		if str(other.get("view_stand", "")) != stand_id:
			continue
		used[int(other.get("view_slot", -1))] = true
	var seed: int = abs(self_id * 5 + int(guest.get("lane", 0.0)))
	for step in slots.size():
		var idx: int = posmod(seed + step, slots.size())
		if used.has(idx):
			continue
		guest["view_stand"] = stand_id
		guest["view_slot"] = idx
		return slots[idx]
	var overflow: int = 0
	for key in used:
		if int(key) >= 0:
			overflow += 1
	var idx: int = posmod(seed, slots.size())
	guest["view_stand"] = stand_id
	guest["view_slot"] = idx
	var extra := Vector2(float(overflow % 3 - 1) * 14.0, float(int(overflow / 3) % 2) * 12.0)
	return slots[idx] + extra


func _move_toward(guest: Dictionary, dest: Vector2, delta: float) -> bool:
	var offset: Vector2 = dest - guest["pos"]
	var dist: float = offset.length()
	var step: float = WALK_SPEED * delta
	if dist <= step:
		guest["pos"] = dest
		return true
	guest["pos"] = guest["pos"] + offset / dist * step
	return false


func _aisle_waypoints(from: Vector2, dest: Vector2, lane: float) -> Array:
	var rx: float = RUNNER_X + lane
	var from_safe: float = _cross_y_for(from)
	var dest_safe: float = _cross_y_for(dest)
	var pts: Array = []
	if abs(from.x - rx) > 8.0:
		if abs(from.y - from_safe) > 8.0:
			pts.append(Vector2(from.x, from_safe))
		pts.append(Vector2(rx, from_safe))
	elif abs(from.y - from_safe) > 8.0:
		pts.append(Vector2(rx, from_safe))
	if pts.is_empty() or abs((pts[pts.size() - 1] as Vector2).y - dest_safe) > 8.0 or abs((pts[pts.size() - 1] as Vector2).x - rx) > 8.0:
		pts.append(Vector2(rx, dest_safe))
	if abs(dest.x - rx) > 8.0:
		pts.append(Vector2(dest.x, dest_safe))
	pts.append(dest)
	return _dedupe_path(from, pts)


func _cross_y_for(point: Vector2) -> float:
	if point.y < SIDE_HALL_Y:
		return NORTH_CROSS_Y
	return _runner_safe_y(point.y)


func _runner_safe_y(y: float) -> float:
	var safe: float = y
	for stand_id in STAND_LAYOUT:
		var stand: Rect2 = stand_rect(str(stand_id))
		if stand.end.x < 920.0 or stand.position.x > 1080.0:
			continue
		if safe >= stand.position.y and safe <= stand.end.y:
			safe = stand.end.y + PAD_GAP
	return safe


func _dedupe_path(from: Vector2, pts: Array) -> Array:
	var out: Array = []
	var prev: Vector2 = from
	for pt in pts:
		var next: Vector2 = pt
		if next.distance_to(prev) < 6.0:
			continue
		out.append(next)
		prev = next
	return out


func _draw_visitor(pos: Vector2, index: int, c: CanvasItem = null) -> void:
	if c == null:
		c = self
	var coats: PackedColorArray = PackedColorArray([
		Color("6A4A32"),
		Color("3A4A62"),
		Color("5A3A3A"),
		Color("3A5A42"),
		Color("4A3A52"),
	])
	var coat: Color = coats[index % coats.size()]
	c.draw_circle(pos + Vector2(0, -10), 4.5, Color("E8D4B0"))
	c.draw_rect(Rect2(pos.x - 4.0, pos.y - 6.0, 8.0, 11.0), coat)
	c.draw_rect(Rect2(pos.x - 3.5, pos.y + 5.0, 3.0, 7.0), Color("2A2218"))
	c.draw_rect(Rect2(pos.x + 0.5, pos.y + 5.0, 3.0, 7.0), Color("2A2218"))


func _draw_mount_art(stand_id: String, mount: Rect2) -> bool:
	if not ArtCatalogScript.has_final("museum", stand_id):
		return false
	var complete: bool = GameState.stand_is_filled(stand_id)
	var color := Color.WHITE if complete else Color(1, 1, 1, 0.55)
	return ArtCatalogScript.draw_if_present(self, "museum", stand_id, mount, color)


func _draw_t_rex_bay() -> void:
	var stand: Rect2 = stand_rect("t_rex")
	var mount: Rect2 = _draw_stand(stand, "T. rex", "t_rex")
	if _draw_mount_art("t_rex", mount):
		_draw_stand_finish("t_rex", stand)
		return
	var xf := _fit(mount, Vector2(-86, -110), Vector2(108, 0))
	var head_on: bool = _region_on("t_rex", "head")
	var head_clean: bool = _region_clean("t_rex", "head")
	var torso_on: bool = _region_on("t_rex", "torso")
	var torso_clean: bool = _region_clean("t_rex", "torso")
	var legs_on: bool = _region_on("t_rex", "legs")
	var legs_clean: bool = _region_clean("t_rex", "legs")
	var tail_on: bool = _region_on("t_rex", "tail")
	var tail_clean: bool = _region_clean("t_rex", "tail")
	_rect(xf, -8, -84, 70, 38, torso_on, torso_clean, _cond("t_rex", "torso"))
	_rect(xf, 54, -72, 54, 14, tail_on, tail_clean, _cond("t_rex", "tail"))
	_rect(xf, -6, -52, 22, 30, legs_on, legs_clean, _cond("t_rex", "legs"))
	_rect(xf, -2, -26, 16, 26, legs_on, legs_clean, _cond("t_rex", "legs"))
	_rect(xf, 28, -48, 18, 26, legs_on, legs_clean, _cond("t_rex", "legs"))
	_rect(xf, 26, -24, 20, 24, legs_on, legs_clean, _cond("t_rex", "legs"))
	var jaw_bone_on: bool = GameState.has_piece("t_rex_jaw")
	var jaw_bone_clean: bool = _owned_clean("t_rex_jaw")
	_rect(xf, -4, -66, 18, 6, jaw_bone_on, jaw_bone_clean, _cond("t_rex", "jaw_bone"))
	_rect(xf, -30, -100, 26, 26, head_on, head_clean, _cond("t_rex", "head"))
	_rect(xf, -78, -110, 52, 26, head_on, head_clean, _cond("t_rex", "head"))
	_rect(xf, -72, -86, 34, 8, jaw_bone_on, jaw_bone_clean, _cond("t_rex", "jaw_bone"))
	for i in display_slots("t_rex_tooth"):
		var tooth_x: float = -70.0 + float(i) * 5.5
		_poly(xf, PackedVector2Array([
			Vector2(tooth_x, -86.0),
			Vector2(tooth_x + 4.0, -86.0),
			Vector2(tooth_x + 2.0, -78.0),
		]), slot_on("t_rex_tooth", i), _slot_clean("t_rex_tooth", i), GameState.piece_condition("t_rex_tooth"))
	_draw_stand_finish("t_rex", stand)


func _draw_small_finds_bay() -> void:
	var stand: Rect2 = stand_rect("small_finds")
	var mount: Rect2 = _draw_stand(stand, "Small Finds", "small_finds")
	if not _draw_mount_art("small_finds", mount):
		_draw_case_cells(mount, "small_finds")
	_draw_case_glass(mount, "small_finds")
	_draw_stand_finish("small_finds", stand)


func _draw_plant_fossils_bay() -> void:
	var stand: Rect2 = stand_rect("plant_fossils")
	var mount: Rect2 = _draw_stand(stand, "Plant Fossils", "plant_fossils")
	if not _draw_mount_art("plant_fossils", mount):
		_draw_case_cells(mount, "plant_fossils")
	_draw_case_glass(mount, "plant_fossils")
	_draw_stand_finish("plant_fossils", stand)


func _draw_case_cells(mount: Rect2, stand_id: String) -> void:
	var ids: PackedStringArray = _case_piece_ids(stand_id)
	var count: int = maxi(ids.size(), 2)
	var gap: float = 10.0
	var cell_w: float = (mount.size.x - gap * float(count + 1)) / float(count)
	for i in count:
		var piece_id: String = ids[i] if i < ids.size() else ""
		var cell := Rect2(
			mount.position.x + gap + float(i) * (cell_w + gap),
			mount.position.y + 6.0,
			cell_w,
			mount.size.y - 12.0
		)
		_draw_case_cell(cell, piece_id)


func _draw_case_glass(mount: Rect2, stand_id: String) -> void:
	var alpha: float = hall_case_glass_alpha(stand_id)
	if alpha <= 0.0:
		return
	var rank: int = _museum_rank("glass_case")
	var width: float = 1.6 + 0.4 * float(rank)
	var fill_a: float = alpha * (0.38 if rank <= 1 else 0.52)
	if stand_id == "small_finds":
		draw_rect(mount, Color(0.78, 0.90, 0.94, fill_a))
		draw_rect(mount, Color(0.92, 0.98, 1.0, alpha * 0.85), false, width)
	else:
		draw_rect(mount, Color(0.76, 0.90, 0.62, fill_a))
		draw_rect(mount, Color(0.88, 0.96, 0.74, alpha * 0.85), false, width)
	var lid := Rect2(mount.position.x - 3.0, mount.position.y - 6.0, mount.size.x + 6.0, 7.0 + float(rank) * 0.6)
	draw_rect(lid, Color(0.88, 0.94, 0.96, minf(0.42, alpha + 0.08)))
	draw_rect(lid, Color(1.0, 1.0, 1.0, alpha * 0.70), false, 1.2)
	var sheen := Rect2(mount.position.x + 8.0, mount.position.y + 6.0, mount.size.x * (0.34 if rank <= 1 else 0.42), 8.0 + float(rank))
	draw_rect(sheen, Color(1.0, 1.0, 1.0, minf(0.34, alpha * 0.50)))


func _case_piece_ids(stand_id: String) -> PackedStringArray:
	var ids: PackedStringArray = PackedStringArray()
	for path in Tuning.extra_fossil_paths:
		var data: Resource = load(str(path))
		if data == null:
			continue
		var piece_id: String = str(data.get("piece_id"))
		if piece_id.is_empty() or ids.has(piece_id):
			continue
		if GameState.stand_for_piece(piece_id) != stand_id:
			continue
		ids.append(piece_id)
	if ids.is_empty():
		if stand_id == "small_finds":
			ids = PackedStringArray(["trilobite", "amber_insect"])
		elif stand_id == "plant_fossils":
			ids = PackedStringArray(["cycad", "fossil_flower"])
	for piece_id in GameState.pieces:
		var id: String = str(piece_id)
		if GameState.stand_for_piece(id) != stand_id:
			continue
		if ids.has(id):
			continue
		ids.append(id)
	return ids


func _draw_case_cell(cell: Rect2, piece_id: String) -> void:
	draw_rect(cell, Color("241810"))
	draw_rect(cell, Color("5A4634"), false, 1.5)
	var owned: bool = piece_id != "" and GameState.has_piece(piece_id)
	var clean: bool = false
	if owned:
		var piece: Dictionary = GameState.pieces[piece_id]
		clean = bool(piece.get("clean", false))
	var fossil_rect := Rect2(cell.position + Vector2(6, 4), Vector2(cell.size.x - 12.0, cell.size.y - 28.0))
	match piece_id:
		"tooth":
			_draw_tooth_mount(fossil_rect, owned, clean)
		"vertebra":
			_draw_vertebra_mount(fossil_rect, owned, clean)
		"trilobite":
			_draw_trilobite_mount(fossil_rect, owned, clean)
		"amber_insect":
			_draw_amber_mount(fossil_rect, owned, clean)
		"cycad":
			_draw_cycad_mount(fossil_rect, owned, clean)
		"fossil_flower":
			_draw_flower_mount(fossil_rect, owned, clean)
		_:
			_draw_generic_scrap(fossil_rect, owned, clean)
	if hall_case_titles_visible():
		var title: String = _case_cell_title(piece_id)
		var color: Color = hall_plaque_gold() if owned else Color(0.58, 0.46, 0.36, 0.72)
		_draw_label(Vector2(cell.get_center().x, cell.end.y - 10.0), title, 12, color)


func _case_cell_title(piece_id: String) -> String:
	match piece_id:
		"tooth":
			return "Tooth"
		"vertebra":
			return "Vertebra"
		"trilobite":
			return "Trilobite"
		"amber_insect":
			return "Amber"
		"cycad":
			return "Cycad"
		"fossil_flower":
			return "Flower"
		"":
			return "Empty"
		_:
			if GameState.has_piece(piece_id):
				return str(GameState.pieces[piece_id].get("name", piece_id))
			return piece_id.capitalize()


func _draw_tooth_mount(cell: Rect2, owned: bool, clean: bool) -> void:
	var xf := _fit(cell, Vector2(-18, -52), Vector2(18, -8))
	_poly(xf, PackedVector2Array([
		Vector2(-16, -50), Vector2(16, -50), Vector2(7, -18), Vector2(-7, -18)
	]), owned, clean)
	_rect(xf, -6, -20, 12, 12, owned, clean)


func _draw_vertebra_mount(cell: Rect2, owned: bool, clean: bool) -> void:
	var xf := _fit(cell, Vector2(-28, -48), Vector2(28, -8))
	_rect(xf, -22, -34, 44, 18, owned, clean)
	_rect(xf, -10, -48, 20, 16, owned, clean)
	_rect(xf, -8, -18, 16, 10, owned, clean)
	if owned:
		draw_circle(xf * Vector2(0, -25), 5.0 * xf.x.length(), Color("2B2118"))


func _draw_generic_scrap(cell: Rect2, owned: bool, clean: bool) -> void:
	var xf := _fit(cell, Vector2(-20, -36), Vector2(20, -8))
	_rect(xf, -16, -28, 32, 14, owned, clean)
	_rect(xf, -8, -36, 16, 10, owned, clean)


func _draw_trilobite_mount(cell: Rect2, owned: bool, clean: bool) -> void:
	var xf := _fit(cell, Vector2(-22, -40), Vector2(22, -8))
	_rect(xf, -18, -28, 36, 16, owned, clean)
	_rect(xf, -10, -38, 20, 12, owned, clean)
	_rect(xf, -8, -16, 16, 8, owned, clean)


func _draw_amber_mount(cell: Rect2, owned: bool, clean: bool) -> void:
	var xf := _fit(cell, Vector2(-18, -40), Vector2(18, -8))
	_poly(xf, PackedVector2Array([
		Vector2(-6, -38), Vector2(12, -32), Vector2(10, -12), Vector2(-12, -16)
	]), owned, clean)
	_rect(xf, -4, -28, 8, 10, owned, clean)


func _draw_cycad_mount(cell: Rect2, owned: bool, clean: bool) -> void:
	var xf := _fit(cell, Vector2(-22, -44), Vector2(22, -8))
	_rect(xf, -5, -26, 10, 18, owned, clean)
	_poly(xf, PackedVector2Array([
		Vector2(0, -42), Vector2(8, -28), Vector2(-8, -28)
	]), owned, clean)
	_poly(xf, PackedVector2Array([
		Vector2(-18, -36), Vector2(-4, -28), Vector2(-10, -22)
	]), owned, clean)
	_poly(xf, PackedVector2Array([
		Vector2(18, -36), Vector2(4, -28), Vector2(10, -22)
	]), owned, clean)


func _draw_flower_mount(cell: Rect2, owned: bool, clean: bool) -> void:
	var xf := _fit(cell, Vector2(-20, -42), Vector2(20, -8))
	_poly(xf, PackedVector2Array([
		Vector2(0, -40), Vector2(6, -28), Vector2(-6, -28)
	]), owned, clean)
	_poly(xf, PackedVector2Array([
		Vector2(16, -30), Vector2(4, -26), Vector2(8, -16)
	]), owned, clean)
	_poly(xf, PackedVector2Array([
		Vector2(-16, -30), Vector2(-4, -26), Vector2(-8, -16)
	]), owned, clean)
	_poly(xf, PackedVector2Array([
		Vector2(10, -12), Vector2(0, -20), Vector2(-10, -12)
	]), owned, clean)
	_rect(xf, -5, -26, 10, 10, owned, clean)


func _draw_triceratops_bay() -> void:
	var stand: Rect2 = stand_rect("triceratops")
	var mount: Rect2 = _draw_stand(stand, "Triceratops", "triceratops")
	if _draw_mount_art("triceratops", mount):
		_draw_stand_finish("triceratops", stand)
		return
	var skull_on: bool = _region_on("triceratops", "skull")
	var skull_clean: bool = _region_clean("triceratops", "skull")
	var body_on: bool = _region_on("triceratops", "body")
	var body_clean: bool = _region_clean("triceratops", "body")
	var nose_on: bool = _region_on("triceratops", "nose")
	var nose_clean: bool = _region_clean("triceratops", "nose")
	var brow_on: bool = _region_on("triceratops", "brow")
	var brow_clean: bool = _region_clean("triceratops", "brow")
	var legs_on: bool = _region_on("triceratops", "legs")
	var legs_clean: bool = _region_clean("triceratops", "legs")
	var tail_on: bool = _region_on("triceratops", "tail")
	var tail_clean: bool = _region_clean("triceratops", "tail")
	var xf := _fit(mount, Vector2(-98, -100), Vector2(104, 0))
	_rect(xf, -14, -68, 82, 36, body_on, body_clean, _cond("triceratops", "body"))
	_rect(xf, 60, -56, 44, 12, tail_on, tail_clean, _cond("triceratops", "tail"))
	_rect(xf, -10, -34, 16, 34, legs_on, legs_clean, _cond("triceratops", "legs"))
	_rect(xf, 16, -34, 16, 34, legs_on, legs_clean, _cond("triceratops", "legs"))
	_rect(xf, 42, -34, 16, 34, legs_on, legs_clean, _cond("triceratops", "legs"))
	_rect(xf, 66, -32, 16, 32, legs_on, legs_clean, _cond("triceratops", "legs"))
	_rect(xf, -62, -92, 40, 46, skull_on, skull_clean, _cond("triceratops", "skull"))
	_rect(xf, -86, -66, 38, 26, skull_on, skull_clean, _cond("triceratops", "skull"))
	_rect(xf, -98, -56, 16, 12, skull_on, skull_clean, _cond("triceratops", "skull"))
	_rect(xf, -48, -100, 8, 20, brow_on, brow_clean, _cond("triceratops", "brow"))
	_rect(xf, -32, -98, 8, 18, brow_on, brow_clean, _cond("triceratops", "brow"))
	_rect(xf, -78, -72, 8, 16, nose_on, nose_clean, _cond("triceratops", "nose"))
	for i in display_slots("triceratops_tooth"):
		var tooth_x: float = -98.0 + float(i) * 3.6
		_rect(xf, tooth_x, -50.0, 3.0, 8.0, slot_on("triceratops_tooth", i), _slot_clean("triceratops_tooth", i), GameState.piece_condition("triceratops_tooth"))
	if skull_on:
		draw_circle(xf * Vector2(-62, -52), 5.0 * xf.x.length(), Color("2B2118"))
	_draw_stand_finish("triceratops", stand)


func _draw_sauropod_bay() -> void:
	var stand: Rect2 = stand_rect("brachiosaurus")
	var mount: Rect2 = _draw_stand(stand, "Brachiosaurus", "brachiosaurus")
	if _draw_mount_art("brachiosaurus", mount):
		_draw_stand_finish("brachiosaurus", stand)
		return
	var xf := _fit(mount, Vector2(-70, -132), Vector2(90, 0))
	var torso_on: bool = _region_on("brachiosaurus", "arm") or _region_on("brachiosaurus", "legs")
	var arm_on: bool = _region_on("brachiosaurus", "arm")
	var arm_clean: bool = _region_clean("brachiosaurus", "arm")
	var legs_on: bool = _region_on("brachiosaurus", "legs")
	var legs_clean: bool = _region_clean("brachiosaurus", "legs")
	var tail_on: bool = _region_on("brachiosaurus", "tail")
	var tail_clean: bool = _region_clean("brachiosaurus", "tail")
	var neck_on: bool = _region_on("brachiosaurus", "neck")
	var neck_clean: bool = _region_clean("brachiosaurus", "neck")
	var head_on: bool = _region_on("brachiosaurus", "head")
	var head_clean: bool = _region_clean("brachiosaurus", "head")
	_rect(xf, -18, -70, 74, 36, torso_on, arm_clean or legs_clean)
	_rect(xf, 48, -56, 42, 12, tail_on, tail_clean, _cond("brachiosaurus", "tail"))
	_rect(xf, -16, -40, 16, 40, arm_on, arm_clean, _cond("brachiosaurus", "arm"))
	_rect(xf, 6, -36, 16, 36, legs_on, legs_clean, _cond("brachiosaurus", "legs"))
	_rect(xf, 28, -36, 16, 36, legs_on, legs_clean, _cond("brachiosaurus", "legs"))
	_rect(xf, 48, -34, 16, 34, legs_on, legs_clean, _cond("brachiosaurus", "legs"))
	_rect(xf, -28, -102, 22, 36, neck_on, neck_clean, _cond("brachiosaurus", "neck"))
	_rect(xf, -42, -124, 20, 28, neck_on, neck_clean, _cond("brachiosaurus", "neck"))
	_rect(xf, -70, -132, 32, 16, head_on, head_clean, _cond("brachiosaurus", "head"))
	for i in display_slots("brachiosaurus_tooth"):
		var peg_x: float = -68.0 + float(i) * 4.0
		_rect(xf, peg_x, -118.0, 3.0, 6.0, slot_on("brachiosaurus_tooth", i), _slot_clean("brachiosaurus_tooth", i), GameState.piece_condition("brachiosaurus_tooth"))
	_draw_stand_finish("brachiosaurus", stand)


func _draw_raptor_bay() -> void:
	var stand: Rect2 = stand_rect("velociraptor")
	var mount: Rect2 = _draw_stand(stand, "Velociraptor", "velociraptor")
	if _draw_mount_art("velociraptor", mount):
		_draw_stand_finish("velociraptor", stand)
		return
	var xf := _fit(mount, Vector2(-54, -74), Vector2(96, 0))
	var torso_on: bool = _region_on("velociraptor", "torso")
	var torso_clean: bool = _region_clean("velociraptor", "torso")
	var tail_on: bool = _region_on("velociraptor", "tail")
	var tail_clean: bool = _region_clean("velociraptor", "tail")
	var legs_on: bool = _region_on("velociraptor", "legs")
	var legs_clean: bool = _region_clean("velociraptor", "legs")
	var head_on: bool = _region_on("velociraptor", "head")
	var head_clean: bool = _region_clean("velociraptor", "head")
	_rect(xf, -14, -50, 52, 22, torso_on, torso_clean, _cond("velociraptor", "torso"))
	_rect(xf, 32, -46, 64, 8, tail_on, tail_clean, _cond("velociraptor", "tail"))
	_rect(xf, 2, -34, 14, 34, legs_on, legs_clean, _cond("velociraptor", "legs"))
	_rect(xf, 14, -16, 16, 6, slot_on("velociraptor_claw", 0), _slot_clean("velociraptor_claw", 0), GameState.piece_condition("velociraptor_claw"))
	_rect(xf, -8, -14, 12, 5, slot_on("velociraptor_claw", 1), _slot_clean("velociraptor_claw", 1), GameState.piece_condition("velociraptor_claw"))
	_rect(xf, -8, -30, 10, 18, legs_on, legs_clean, _cond("velociraptor", "legs"))
	_rect(xf, -28, -64, 16, 18, head_on, head_clean, _cond("velociraptor", "head"))
	_rect(xf, -54, -72, 28, 16, head_on, head_clean, _cond("velociraptor", "head"))
	_rect(xf, -50, -58, 14, 6, head_on, head_clean, _cond("velociraptor", "head"))
	_draw_stand_finish("velociraptor", stand)


func _owned_clean(piece_id: String) -> bool:
	if not GameState.has_piece(piece_id):
		return false
	var piece: Dictionary = GameState.pieces[piece_id]
	return bool(piece.get("clean", false))


func _region_on(stand_id: String, region: String) -> bool:
	return bool(GameState.stand_region_filled(stand_id, region))


func _region_clean(stand_id: String, region: String) -> bool:
	return bool(GameState.stand_region_clean(stand_id, region))


func _draw_stego_bay() -> void:
	var stand: Rect2 = stand_rect("stegosaurus")
	var mount: Rect2 = _draw_stand(stand, "Stegosaurus", "stegosaurus")
	if _draw_mount_art("stegosaurus", mount):
		_draw_stand_finish("stegosaurus", stand)
		return
	var torso_on: bool = _region_on("stegosaurus", "torso")
	var torso_clean: bool = _region_clean("stegosaurus", "torso")
	var legs_on: bool = _region_on("stegosaurus", "legs")
	var legs_clean: bool = _region_clean("stegosaurus", "legs")
	var tail_on: bool = _region_on("stegosaurus", "tail")
	var tail_clean: bool = _region_clean("stegosaurus", "tail")
	var head_on: bool = _region_on("stegosaurus", "head")
	var head_clean: bool = _region_clean("stegosaurus", "head")
	var xf := _fit(mount, Vector2(-52, -88), Vector2(108, 0))
	_rect(xf, -18, -54, 82, 28, torso_on, torso_clean, _cond("stegosaurus", "torso"))
	_rect(xf, 56, -46, 40, 10, tail_on, tail_clean, _cond("stegosaurus", "tail"))
	_rect(xf, -12, -28, 14, 20, legs_on, legs_clean, _cond("stegosaurus", "legs"))
	_rect(xf, 12, -28, 14, 20, legs_on, legs_clean, _cond("stegosaurus", "legs"))
	_rect(xf, 36, -28, 14, 20, legs_on, legs_clean, _cond("stegosaurus", "legs"))
	_rect(xf, 58, -26, 14, 18, legs_on, legs_clean, _cond("stegosaurus", "legs"))
	var foot_xs: Array[float] = [-12.0, 12.0, 36.0, 58.0]
	for i in display_slots("stegosaurus_foot"):
		var foot_x: float = foot_xs[i] if i < foot_xs.size() else 58.0 + float(i - 3) * 16.0
		_rect(xf, foot_x, -8.0, 14.0, 8.0, slot_on("stegosaurus_foot", i), _slot_clean("stegosaurus_foot", i), GameState.piece_condition("stegosaurus_foot"))
	_rect(xf, -44, -48, 28, 14, head_on, head_clean, _cond("stegosaurus", "head"))
	var plate_pts: Array[PackedVector2Array] = [
		PackedVector2Array([Vector2(-4, -54), Vector2(8, -84), Vector2(20, -54)]),
		PackedVector2Array([Vector2(22, -54), Vector2(36, -88), Vector2(50, -54)]),
		PackedVector2Array([Vector2(48, -54), Vector2(60, -80), Vector2(72, -54)]),
	]
	for i in display_slots("stegosaurus_plate"):
		if i >= plate_pts.size():
			continue
		_poly(xf, plate_pts[i], slot_on("stegosaurus_plate", i), _slot_clean("stegosaurus_plate", i), GameState.piece_condition("stegosaurus_plate"))
	_rect(xf, 90, -54, 6, 16, tail_on, tail_clean, _cond("stegosaurus", "tail"))
	_rect(xf, 100, -50, 6, 14, tail_on, tail_clean, _cond("stegosaurus", "tail"))
	_draw_stand_finish("stegosaurus", stand)


func _draw_stand(stand: Rect2, _title: String, stand_id: String) -> Rect2:
	var featured: bool = GameState.featured_stand_id == stand_id and GameState.stand_is_filled(stand_id)
	_draw_platform(stand, featured)
	_draw_plaque(Vector2(stand.get_center().x, stand.end.y - 12.0), plaque_title_for(stand_id), featured)
	return stand_mount_rect(stand_id)


func _draw_stand_finish(stand_id: String, stand: Rect2) -> void:
	if GameState.featured_stand_id == stand_id and GameState.stand_is_filled(stand_id):
		_draw_spotlight(stand)
	if GameState.stand_has_pending_unveil(stand_id):
		_draw_ribbon(stand, stand_id)
		_redraw_plaque(stand_id)
	if flash_t > 0.0 and flash_stand_id == stand_id:
		draw_rect(stand, Color(1.0, 0.86, 0.40, 0.55 * flash_t))
		draw_rect(stand.grow(10.0), Color(1.0, 0.92, 0.55, 0.28 * flash_t), false, 6.0)
	_draw_stand_rate(stand_id)


func _draw_stand_rate(stand_id: String) -> void:
	var rect: Rect2 = stand_rate_rect(stand_id)
	if rect.size == Vector2.ZERO:
		return
	var line: String = stand_rate_line(stand_id)
	draw_rect(rect, Color("2C2118"))
	draw_rect(rect, Ui.GOLD, false, 1.2)
	var font: Font = Ui.display_font()
	var font_size: int = label_font_size(11)
	draw_string(font, Vector2(rect.position.x + 8.0, rect.position.y + float(font_size) + 2.0), line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Ui.GOLD)
	_draw_stand_condition(stand_id, rect)


func stand_condition_stars(stand_id: String) -> int:
	## Average condition of what is on the stand, as 0-5 stars (0 = empty).
	return int(round(GameState.stand_condition(stand_id)))


func _draw_stand_condition(stand_id: String, chip: Rect2) -> void:
	var stars: int = stand_condition_stars(stand_id)
	if stars <= 0:
		return
	if GameState.stand_is_masterpiece(stand_id):
		_draw_masterpiece_frame(stand_id, chip)
	var r: float = 8.0
	var gap: float = 18.0
	var y: float = chip.end.y + 13.0
	var x0: float = chip.end.x - gap * 4.0 - r - 2.0
	for i in 5:
		_draw_star(Vector2(x0 + gap * float(i), y), r, i < stars)


## Hall rect of a stand's condition stars (hover it for an explanation).
func stand_stars_rect(stand_id: String) -> Rect2:
	if stand_condition_stars(stand_id) <= 0:
		return Rect2()
	var chip: Rect2 = stand_rate_rect(stand_id)
	if chip.size == Vector2.ZERO:
		return Rect2()
	var r: float = 8.0
	var gap: float = 18.0
	var x0: float = chip.end.x - gap * 4.0 - r - 2.0
	return Rect2(Vector2(x0 - r - 4.0, chip.end.y + 3.0), Vector2(gap * 4.0 + r * 2.0 + 8.0, r * 2.0 + 6.0))


func stand_at_stars(hall_pos: Vector2) -> String:
	for stand_id in STAND_LAYOUT.keys():
		if stand_stars_rect(str(stand_id)).has_point(hall_pos):
			return str(stand_id)
	return ""


## Data for the hover card (StarTip): overall stars, each bone's stars, and
## the average that makes the overall rating.
func stand_condition_info(stand_id: String) -> Dictionary:
	var stars: int = stand_condition_stars(stand_id)
	var below: int = 0
	var total: int = 0
	var sum: float = 0.0
	var bones: Array = []
	var title: String = GameState.stand_title(stand_id)
	for piece_id in GameState.stand_piece_ids(stand_id):
		var cond: int = int(GameState.piece_condition(str(piece_id)))
		bones.append({"name": _short_bone_name(str(piece_id), title), "cond": cond})
		if cond <= 0:
			continue
		total += 1
		sum += float(cond)
		if cond < Tuning.masterpiece_min_condition:
			below += 1
	return {
		"stars": stars,
		"word": Tuning.condition_name(maxi(stars, 1)),
		"below": below,
		"total": total,
		"avg": sum / float(total) if total > 0 else 0.0,
		"bones": _found_first(bones),
		"master_stars": Tuning.masterpiece_min_condition,
		"complete": GameState.stand_is_complete(stand_id),
		"master": GameState.stand_is_masterpiece(stand_id),
	}


func _found_first(bones: Array) -> Array:
	## Mounted bones lead the list; missing ones trail as "not found".
	var found: Array = []
	var missing: Array = []
	for b in bones:
		(found if int(b["cond"]) > 0 else missing).append(b)
	return found + missing


## "Velociraptor Claw" on the Velociraptor stand reads as just "Claw".
func _short_bone_name(piece_id: String, stand_title: String) -> String:
	var data: FossilData = GameState.fossil_data_for(piece_id)
	var name: String = data.name if data != null else piece_id.capitalize()
	if not stand_title.is_empty() and name.begins_with(stand_title + " "):
		name = name.substr(stand_title.length() + 1)
	return name


## Plain-language explanation of a stand's stars, shown on hover.
func stand_condition_tip(stand_id: String) -> String:
	var stars: int = stand_condition_stars(stand_id)
	if stars <= 0:
		return ""
	var lines: PackedStringArray = []
	lines.append("%s: %d of 5 stars (%s)" % [GameState.stand_title(stand_id), stars, Tuning.condition_name(stars)])
	lines.append("Stars = how well its bones survived underground.")
	lines.append("1 Poor · 2 Fair · 3 Good · 4 Great · 5 Perfect")
	var below: int = 0
	var total: int = 0
	for piece_id in GameState.stand_piece_ids(stand_id):
		var cond: int = int(GameState.piece_condition(str(piece_id)))
		if cond <= 0:
			continue
		total += 1
		if cond < Tuning.masterpiece_min_condition:
			below += 1
	if GameState.stand_is_masterpiece(stand_id):
		lines.append("Masterpiece! Every bone is 5 stars.")
	elif below > 0:
		lines.append("%d of %d bones have under 5 stars." % [below, total])
		lines.append("Better copies from digs, or the Repair Workshop, raise them.")
		lines.append("Complete + every bone 5 stars = Masterpiece (more visitors).")
	return "\n".join(lines)


## Why the stars are what they are: how many bones hold the stand back.
func stand_condition_note(stand_id: String) -> String:
	var below: int = 0
	for piece_id in GameState.stand_piece_ids(stand_id):
		var cond: int = int(GameState.piece_condition(str(piece_id)))
		if cond > 0 and cond < Tuning.masterpiece_min_condition:
			below += 1
	if below <= 0:
		return ""
	return "%d bone%s below Perfect" % [below, "" if below == 1 else "s"]


func _draw_masterpiece_frame(stand_id: String, _chip: Rect2) -> void:
	## Gold frame + "Masterpiece" tag: a finished stand where every bone is Perfect.
	var stand: Rect2 = stand_rect(stand_id)
	draw_rect(stand.grow(4.0), Color("FFD66B"), false, 4.0)
	draw_rect(stand.grow(9.0), Color(1.0, 0.84, 0.42, 0.35), false, 3.0)
	var font: Font = Ui.display_font()
	var size: int = label_font_size(12)
	var text := "MASTERPIECE"
	var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	## A badge hung on the frame's top edge, clear of the skeleton.
	var tag_size := Vector2(w + 14.0, float(size) + 8.0)
	var tag := Rect2(Vector2(stand.get_center().x - tag_size.x * 0.5, stand.position.y - tag_size.y * 0.6), tag_size)
	draw_rect(tag, Color("FFD66B"))
	draw_string(font, Vector2(tag.position.x + 6.0, tag.end.y - 5.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color("2A1D12"))


func _draw_star(center: Vector2, r: float, filled: bool) -> void:
	var pts := PackedVector2Array()
	for k in 10:
		var ang: float = -PI * 0.5 + float(k) * PI / 5.0
		var rad: float = r if k % 2 == 0 else r * 0.45
		pts.append(center + Vector2(cos(ang), sin(ang)) * rad)
	if filled:
		draw_colored_polygon(pts, Ui.GOLD)
	pts.append(pts[0])
	draw_polyline(pts, Color("2C2118") if filled else Color(Ui.GOLD, 0.55), 1.0)


func spotlight_beam_scale() -> float:
	return 0.20 + 0.35 * Tuning.spotlight_mult


func plaque_title_for(stand_id: String) -> String:
	if not STAND_LAYOUT.has(stand_id):
		return ""
	var title: String = str(STAND_LAYOUT[stand_id]["title"])
	var featured: bool = GameState.featured_stand_id == stand_id and GameState.stand_is_filled(stand_id)
	var rank: int = int(GameState.levels.get("spotlight", 0))
	if featured and rank > 0:
		return "%s  ·  %dx" % [title, int(round(Tuning.spotlight_mult))]
	return title


func spotlight_cone_points(stand: Rect2) -> PackedVector2Array:
	if stand.size == Vector2.ZERO:
		return PackedVector2Array()
	var center: Vector2 = stand_mount_rect_for(stand).get_center()
	var power: float = spotlight_beam_scale()
	var apex_y: float = maxf(stand.position.y - 90.0 * power, hall_board_rect().end.y + 8.0)
	var radius: float = spotlight_disc_radius(stand)
	var spread: float = radius * 0.85
	return PackedVector2Array([
		Vector2(center.x, apex_y),
		Vector2(center.x - spread, center.y + radius * 0.25),
		Vector2(center.x + spread, center.y + radius * 0.25),
	])


func spotlight_disc_radius(stand: Rect2) -> float:
	var mount: Rect2 = stand_mount_rect_for(stand)
	if mount.size == Vector2.ZERO:
		return 0.0
	return minf(mount.size.x, mount.size.y) * (0.30 + 0.04 * spotlight_beam_scale())


func spotlight_disc_rect(stand: Rect2) -> Rect2:
	var radius: float = spotlight_disc_radius(stand)
	if radius <= 0.0:
		return Rect2()
	var center: Vector2 = stand_mount_rect_for(stand).get_center()
	return Rect2(center - Vector2(radius, radius), Vector2(radius * 2.0, radius * 2.0))


func hall_spotlight_cones() -> Array:
	var stand_id: String = str(GameState.featured_stand_id)
	if stand_id == "" or not GameState.stand_is_filled(stand_id):
		return []
	return [spotlight_cone_points(stand_rect(stand_id))]


func hall_spotlight_discs() -> Array:
	var stand_id: String = str(GameState.featured_stand_id)
	if stand_id == "" or not GameState.stand_is_filled(stand_id):
		return []
	var disc: Rect2 = spotlight_disc_rect(stand_rect(stand_id))
	if disc.size == Vector2.ZERO:
		return []
	return [disc]


func hall_platform_glow_discs() -> Array:
	return []


func _draw_spotlight(stand: Rect2) -> void:
	var cone: PackedVector2Array = spotlight_cone_points(stand)
	if cone.size() < 3:
		return
	var power: float = spotlight_beam_scale()
	draw_colored_polygon(cone, Color(1.0, 0.86, 0.45, 0.16 + 0.10 * power))
	var disc: Rect2 = spotlight_disc_rect(stand)
	var radius: float = disc.size.x * 0.5
	if radius <= 0.0:
		return
	var center: Vector2 = disc.get_center()
	draw_circle(center, radius, Color(1.0, 0.88, 0.50, 0.14 + 0.10 * power))
	draw_circle(center, radius * 0.55, Color(1.0, 0.92, 0.58, 0.10 + 0.08 * power))


func ribbon_prompt(stand_id: String) -> String:
	var lines: PackedStringArray = ribbon_prompt_lines(stand_id)
	return " ".join(lines)


func ribbon_prompt_lines(stand_id: String) -> PackedStringArray:
	var ids: PackedStringArray = GameState.pending_unveil_ids(stand_id)
	if ids.is_empty():
		return PackedStringArray(["Click to unveil"])
	if ids.size() >= 2:
		return PackedStringArray(["Unveil %d finds" % ids.size()])
	var bone: String = GameState.pending_unveil_label(stand_id)
	if bone.is_empty():
		return PackedStringArray(["Click to unveil"])
	return PackedStringArray(["Unveil", bone])


func ribbon_font_size(stand_id: String) -> int:
	var lines: PackedStringArray = ribbon_prompt_lines(stand_id)
	var max_w: float = _ribbon_text_max_width(stand_id)
	var font: Font = Ui.display_font()
	var size: int = label_font_size(12)
	while size > 8:
		if _ribbon_lines_width(lines, font, size) <= max_w:
			return size
		size -= 1
	return size


func _ribbon_text_max_width(stand_id: String) -> float:
	return maxf(40.0, stand_rect(stand_id).size.x - 48.0)


func _ribbon_lines_width(lines: PackedStringArray, font: Font, font_size: int) -> float:
	var max_w: float = 0.0
	for line in lines:
		max_w = maxf(max_w, font.get_string_size(str(line), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
	return max_w


func label_font_size(base: int) -> int:
	var zoom: float = maxf(get_global_transform().get_scale().x, 0.001)
	if float(base) * zoom >= MIN_LABEL_SCREEN_PX:
		return base
	return maxi(base, int(ceili(MIN_LABEL_SCREEN_PX / zoom)))


func plaque_rect(stand_id: String) -> Rect2:
	if not STAND_LAYOUT.has(stand_id):
		return Rect2()
	var featured: bool = GameState.featured_stand_id == stand_id and GameState.stand_is_filled(stand_id)
	var stand: Rect2 = stand_rect(stand_id)
	return _plaque_rect_at(Vector2(stand.get_center().x, stand.end.y - 12.0), plaque_title_for(stand_id), featured)


func ribbon_vertical_rect(stand_id: String) -> Rect2:
	var stand: Rect2 = stand_rect(stand_id)
	var plaque: Rect2 = plaque_rect(stand_id)
	var band_h: float = 22.0
	var bottom: float = plaque.position.y - PLAQUE_CLEARANCE
	var height: float = maxf(0.0, bottom - stand.position.y)
	return Rect2(stand.get_center().x - band_h * 0.5, stand.position.y, band_h, height)


func ribbon_label_rect(stand_id: String) -> Rect2:
	var stand: Rect2 = stand_rect(stand_id)
	var plaque: Rect2 = plaque_rect(stand_id)
	var lines: PackedStringArray = ribbon_prompt_lines(stand_id)
	var font: Font = Ui.display_font()
	var font_size: int = ribbon_font_size(stand_id)
	var max_w: float = _ribbon_lines_width(lines, font, font_size)
	var line_h: float = float(font_size) + 4.0
	var inset: float = 12.0
	var max_chip_w: float = maxf(48.0, stand.size.x - inset * 2.0)
	var bottom: float = plaque.position.y - PLAQUE_CLEARANCE
	var max_chip_h: float = maxf(line_h + 12.0, bottom - (stand.position.y + 8.0))
	var size: Vector2 = Vector2(minf(max_chip_w, max_w + 24.0), minf(max_chip_h, line_h * float(lines.size()) + 12.0))
	var min_top: float = stand.position.y + 8.0
	var max_top: float = bottom - size.y
	var top: float = stand.get_center().y - size.y * 0.5
	if max_top < min_top:
		top = min_top
		size.y = maxf(0.0, bottom - top)
	else:
		top = clampf(top, min_top, max_top)
	var left: float = stand.get_center().x - size.x * 0.5
	left = clampf(left, stand.position.x + inset, stand.end.x - inset - size.x)
	return Rect2(left, top, size.x, size.y)


func _redraw_plaque(stand_id: String) -> void:
	if not STAND_LAYOUT.has(stand_id):
		return
	var featured: bool = GameState.featured_stand_id == stand_id and GameState.stand_is_filled(stand_id)
	var stand: Rect2 = stand_rect(stand_id)
	_draw_plaque(Vector2(stand.get_center().x, stand.end.y - 12.0), plaque_title_for(stand_id), featured)


func _draw_ribbon(stand: Rect2, stand_id: String = "") -> void:
	var gold: Color = Color("E4B75A")
	var plaque: Rect2 = plaque_rect(stand_id) if stand_id != "" else Rect2()
	var cover_h: float = stand.size.y
	if plaque.size != Vector2.ZERO:
		cover_h = maxf(0.0, plaque.position.y - stand.position.y)
	draw_rect(Rect2(stand.position, Vector2(stand.size.x, cover_h)), Color(0.10, 0.07, 0.05, 0.78))
	var band_h: float = 22.0
	var hy: float = stand.get_center().y - band_h * 0.5
	draw_rect(Rect2(stand.position.x, hy, stand.size.x, band_h), gold)
	draw_rect(Rect2(stand.position.x, hy, stand.size.x, band_h), Color("8A6A28"), false, 2.0)
	var vertical: Rect2 = ribbon_vertical_rect(stand_id) if stand_id != "" else Rect2(stand.get_center().x - band_h * 0.5, stand.position.y, band_h, cover_h)
	draw_rect(vertical, gold)
	draw_rect(vertical, Color("8A6A28"), false, 2.0)
	var c: Vector2 = stand.get_center()
	draw_circle(c, 18.0, Color("F6E08A"))
	draw_circle(c, 18.0, gold, false, 2.0)
	var chip: Rect2 = ribbon_label_rect(stand_id) if stand_id != "" else Rect2()
	if chip.size == Vector2.ZERO:
		return
	draw_rect(chip, Color("2C2118"))
	draw_rect(chip, gold, false, 1.5)
	var lines: PackedStringArray = ribbon_prompt_lines(stand_id)
	var font_size: int = ribbon_font_size(stand_id) if stand_id != "" else label_font_size(12)
	var line_h: float = float(font_size) + 4.0
	var start_y: float = chip.position.y + 8.0 + float(font_size)
	var font: Font = Ui.display_font()
	for i in lines.size():
		var line: String = str(lines[i])
		var width: float = font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		draw_string(font, Vector2(chip.get_center().x - width * 0.5, start_y + float(i) * line_h), line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, gold)


func _draw_platform(rect: Rect2, featured: bool = false) -> void:
	draw_rect(Rect2(rect.position + Vector2(6, 10), rect.size), Color(0, 0, 0, 0.28))
	draw_rect(rect, PLATFORM)
	draw_rect(Rect2(rect.position.x, rect.end.y - 16, rect.size.x, 16), PLATFORM_LIP)
	var border: Color = Color("F0D070") if featured else Ui.LINE
	draw_rect(rect, border, false, 3.0 if featured else 2.0)


func _plaque_rect_at(center: Vector2, title: String, featured: bool = false) -> Rect2:
	var font: Font = Ui.display_font()
	var font_size: int = label_font_size(16 if featured else 14)
	var text_w: float = font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var pop: float = 1.0
	if featured:
		pop += 0.16 * pop_t
	var height: float = float(26 if featured else 24) + float(maxi(0, font_size - 14))
	var size: Vector2 = Vector2(maxf(158.0, text_w + 36.0), height) * pop
	return Rect2(center - size * 0.5, size)


func _draw_plaque(center: Vector2, title: String, featured: bool = false) -> void:
	var rect: Rect2 = _plaque_rect_at(center, title, featured)
	_draw_plaque_lip(rect)
	draw_rect(Rect2(rect.position + Vector2(2, 3), rect.size), Color(0, 0, 0, 0.38))
	_draw_plaque_plate(rect, featured)
	_draw_plaque_bevel(rect, featured)
	_draw_plaque_screws(rect)
	_draw_label(center + Vector2(0, 5), title, 16 if featured else 14, Color("FFE08A") if featured else hall_plaque_gold())


func _draw_plaque_lip(rect: Rect2) -> void:
	var lip := Rect2(rect.position.x - 8.0, rect.end.y - 3.0, rect.size.x + 16.0, 9.0)
	draw_rect(lip, Color("3A2818"))
	draw_rect(Rect2(lip.position.x, lip.end.y - 3.0, lip.size.x, 3.0), Color("2A1C10"))
	draw_line(lip.position, Vector2(lip.end.x, lip.position.y), Color("8A6A40"), 1.2)


func _draw_plaque_plate(rect: Rect2, featured: bool) -> void:
	draw_rect(rect, Color("4A3418") if featured else Color("3A2A14"))
	draw_rect(rect.grow(-3.0), Color("3A2A14") if featured else Color("2C2118"))


func _draw_plaque_bevel(rect: Rect2, featured: bool) -> void:
	var gold: Color = hall_plaque_gold()
	var outer: Color = Color("8A6A28") if featured else gold.darkened(0.35)
	var hi: Color = Color("FFE8A0") if featured else gold
	var lo: Color = Color("4A3010")
	draw_rect(rect, outer, false, 2.0)
	var inner := rect.grow(-2.0)
	draw_line(inner.position, Vector2(inner.end.x, inner.position.y), hi, 1.2)
	draw_line(inner.position, Vector2(inner.position.x, inner.end.y), hi, 1.2)
	draw_line(Vector2(inner.position.x, inner.end.y), inner.end, lo, 1.2)
	draw_line(Vector2(inner.end.x, inner.position.y), inner.end, lo, 1.2)


func _draw_plaque_screws(rect: Rect2) -> void:
	var inset := Vector2(7.0, 6.0)
	var heads: PackedVector2Array = PackedVector2Array([
		rect.position + inset,
		Vector2(rect.end.x - inset.x, rect.position.y + inset.y),
		Vector2(rect.position.x + inset.x, rect.end.y - inset.y),
		rect.end - inset,
	])
	for p in heads:
		draw_circle(p, 2.5, Color("5A4630"))
		draw_circle(p, 1.6, Color("C9A056"))
		draw_line(p + Vector2(-1.3, 0.2), p + Vector2(1.3, -0.2), Color("3A2814"), 0.8)


func _fit(mount: Rect2, local_min: Vector2, local_max: Vector2) -> Transform2D:
	var size := local_max - local_min
	var inner := Rect2(mount.position + Vector2(6, 6), mount.size - Vector2(12, 12))
	var s: float = minf(inner.size.x / maxf(size.x, 1.0), inner.size.y / maxf(size.y, 1.0))
	var origin := Vector2(
		inner.get_center().x - (local_min.x + local_max.x) * 0.5 * s,
		inner.end.y - local_max.y * s
	)
	return Transform2D(0.0, Vector2(s, s), 0.0, origin)


## Mounted bone color by condition (Poor .. Perfect): the skeleton shows its stars.
const COND_FILL: PackedColorArray = [
	Color("A99A84"),
	Color("CDBD9E"),
	Color("E6D6B2"),
	Color("F7E9C6"),
	Color("FFF7E2"),
]
const PERFECT_EDGE := Color("FFD66B")


func _cond(stand_id: String, region: String) -> int:
	return int(GameState.stand_region_condition(stand_id, region))


func _rect(xf: Transform2D, x: float, y: float, w: float, h: float, owned: bool, clean: bool, cond: int = 3) -> void:
	var a := xf * Vector2(x, y)
	var b := xf * Vector2(x + w, y + h)
	_draw_bone_rect(Rect2(a, b - a), owned, clean, cond)


func _poly(xf: Transform2D, locals: PackedVector2Array, owned: bool, clean: bool, cond: int = 3) -> void:
	var pts := PackedVector2Array()
	for p in locals:
		pts.append(xf * p)
	_draw_bone_poly(pts, owned, clean, cond)


func _bone_fill(clean: bool, cond: int) -> Color:
	var base: Color = COND_FILL[clampi(cond, 1, 5) - 1]
	return base if clean else base.lerp(Color("6E5230"), 0.55)


func _draw_bone_rect(rect: Rect2, owned: bool, clean: bool, cond: int = 3) -> void:
	if owned:
		var color := _bone_fill(clean, cond)
		draw_rect(rect, color)
		var edge: Color = PERFECT_EDGE if cond >= 5 else color.darkened(0.18)
		draw_rect(rect, edge, false, 2.0 if cond >= 5 else 1.2)
		_draw_wear(rect, cond)
	else:
		draw_rect(rect, EMPTY_FILL)
		draw_rect(rect, EMPTY_LINE, false, 2.0)


func _draw_wear(rect: Rect2, cond: int) -> void:
	## Poor/Fair bones show cracks and chips so the low stars have a visible cause.
	var cracks: int = maxi(0, 3 - cond)
	if cracks <= 0 or rect.size.x < 8.0 or rect.size.y < 8.0:
		return
	var ink := Color(0.25, 0.18, 0.12, 0.8)
	for i in cracks:
		var t: float = (float(i) + 1.0) / float(cracks + 1)
		var top := Vector2(rect.position.x + rect.size.x * t, rect.position.y + 2.0)
		var mid := Vector2(top.x + rect.size.x * 0.08, rect.position.y + rect.size.y * 0.5)
		var bottom := Vector2(top.x - rect.size.x * 0.05, rect.end.y - 3.0)
		draw_line(top, mid, ink, 1.5)
		draw_line(mid, bottom, ink, 1.5)


func _draw_bone_poly(points: PackedVector2Array, owned: bool, clean: bool, cond: int = 3) -> void:
	if points.size() < 3:
		return
	var fill := _bone_fill(clean, cond) if owned else EMPTY_FILL
	var line := (PERFECT_EDGE if cond >= 5 else fill.darkened(0.18)) if owned else EMPTY_LINE
	draw_colored_polygon(points, fill)
	for i in points.size():
		draw_line(points[i], points[(i + 1) % points.size()], line, 2.0, true)


func _draw_label(center: Vector2, text: String, font_size: int, color: Color) -> void:
	var font: Font = Ui.display_font()
	var size: int = label_font_size(font_size)
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string(font, center + Vector2(-width * 0.5, 0.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


class _GuestLayer extends Node2D:
	var host: Node2D

	func _draw() -> void:
		if host != null:
			host.call("_draw_visitors", self)
