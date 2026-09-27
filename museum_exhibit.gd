extends Node2D

const Ui := preload("res://ui_style.gd")
const ArtCatalogScript := preload("res://art_catalog.gd")

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
const MIN_LABEL_SCREEN_PX := 11.0
const PLAQUE_CLEARANCE := 8.0
const STAND_LAYOUT := {
	"t_rex": {"title": "T. rex", "x": 760.0, "y": 236.0, "w": 480.0, "h": 250.0},
	"small_finds": {"title": "Small Finds", "x": 70.0, "y": 236.0, "w": 400.0, "h": 230.0},
	"triceratops": {"title": "Triceratops", "x": 70.0, "y": 500.0, "w": 460.0, "h": 260.0},
	"brachiosaurus": {"title": "Brachiosaurus", "x": 1470.0, "y": 480.0, "w": 460.0, "h": 280.0},
	"velociraptor": {"title": "Velociraptor", "x": 70.0, "y": 1100.0, "w": 400.0, "h": 230.0},
	"stegosaurus": {"title": "Stegosaurus", "x": 1470.0, "y": 1100.0, "w": 460.0, "h": 230.0},
}

var _case_ids: PackedStringArray = PackedStringArray()

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


func display_slots(piece_id: String) -> int:
	return int(GameState.piece_need(piece_id))


func slot_on(piece_id: String, slot: int) -> bool:
	return slot >= 0 and int(GameState.piece_count(piece_id)) > slot


func _slot_clean(piece_id: String, slot: int) -> bool:
	return slot_on(piece_id, slot) and _owned_clean(piece_id)


func _draw() -> void:
	_draw_hall()
	_draw_t_rex_bay()
	_draw_small_finds_bay()
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
	_rect(xf, -8, -84, 70, 38, torso_on, torso_clean)
	_rect(xf, 54, -72, 54, 14, tail_on, tail_clean)
	_rect(xf, -6, -52, 22, 30, legs_on, legs_clean)
	_rect(xf, -2, -26, 16, 26, legs_on, legs_clean)
	_rect(xf, 28, -48, 18, 26, legs_on, legs_clean)
	_rect(xf, 26, -24, 20, 24, legs_on, legs_clean)
	var jaw_bone_on: bool = GameState.has_piece("t_rex_jaw")
	var jaw_bone_clean: bool = _owned_clean("t_rex_jaw")
	_rect(xf, -4, -66, 18, 6, jaw_bone_on, jaw_bone_clean)
	_rect(xf, -30, -100, 26, 26, head_on, head_clean)
	_rect(xf, -78, -110, 52, 26, head_on, head_clean)
	_rect(xf, -72, -86, 34, 8, jaw_bone_on, jaw_bone_clean)
	for i in display_slots("t_rex_tooth"):
		var tooth_x: float = -70.0 + float(i) * 5.5
		_poly(xf, PackedVector2Array([
			Vector2(tooth_x, -86.0),
			Vector2(tooth_x + 4.0, -86.0),
			Vector2(tooth_x + 2.0, -78.0),
		]), slot_on("t_rex_tooth", i), _slot_clean("t_rex_tooth", i))
	_draw_stand_finish("t_rex", stand)


func _draw_small_finds_bay() -> void:
	var stand: Rect2 = stand_rect("small_finds")
	var mount: Rect2 = _draw_stand(stand, "Small Finds", "small_finds")
	if _draw_mount_art("small_finds", mount):
		_draw_stand_finish("small_finds", stand)
		return
	draw_rect(mount, Color(0.42, 0.58, 0.62, 0.12))
	draw_rect(mount, Color(0.72, 0.86, 0.90, 0.22), false, 1.5)
	var ids: PackedStringArray = _case_piece_ids()
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
	_draw_stand_finish("small_finds", stand)


func _case_piece_ids() -> PackedStringArray:
	if _case_ids.is_empty():
		for path in Tuning.extra_fossil_paths:
			var data: Resource = load(str(path))
			if data == null:
				continue
			var piece_id: String = str(data.get("piece_id"))
			if piece_id.is_empty() or _case_ids.has(piece_id):
				continue
			_case_ids.append(piece_id)
		if _case_ids.is_empty():
			_case_ids = PackedStringArray(["trilobite", "amber_insect"])
	var ids: PackedStringArray = _case_ids.duplicate()
	for piece_id in GameState.pieces:
		var id: String = str(piece_id)
		if GameState.stand_for_piece(id) != "small_finds":
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
		_:
			_draw_generic_scrap(fossil_rect, owned, clean)
	var title: String = _case_cell_title(piece_id)
	var color: Color = Ui.GOLD if owned else Color(0.58, 0.46, 0.36, 0.72)
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
	_rect(xf, -14, -68, 82, 36, body_on, body_clean)
	_rect(xf, 60, -56, 44, 12, tail_on, tail_clean)
	_rect(xf, -10, -34, 16, 34, legs_on, legs_clean)
	_rect(xf, 16, -34, 16, 34, legs_on, legs_clean)
	_rect(xf, 42, -34, 16, 34, legs_on, legs_clean)
	_rect(xf, 66, -32, 16, 32, legs_on, legs_clean)
	_rect(xf, -62, -92, 40, 46, skull_on, skull_clean)
	_rect(xf, -86, -66, 38, 26, skull_on, skull_clean)
	_rect(xf, -98, -56, 16, 12, skull_on, skull_clean)
	_rect(xf, -48, -100, 8, 20, brow_on, brow_clean)
	_rect(xf, -32, -98, 8, 18, brow_on, brow_clean)
	_rect(xf, -78, -72, 8, 16, nose_on, nose_clean)
	for i in display_slots("triceratops_tooth"):
		var tooth_x: float = -98.0 + float(i) * 3.6
		_rect(xf, tooth_x, -50.0, 3.0, 8.0, slot_on("triceratops_tooth", i), _slot_clean("triceratops_tooth", i))
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
	_rect(xf, 48, -56, 42, 12, tail_on, tail_clean)
	_rect(xf, -16, -40, 16, 40, arm_on, arm_clean)
	_rect(xf, 6, -36, 16, 36, legs_on, legs_clean)
	_rect(xf, 28, -36, 16, 36, legs_on, legs_clean)
	_rect(xf, 48, -34, 16, 34, legs_on, legs_clean)
	_rect(xf, -28, -102, 22, 36, neck_on, neck_clean)
	_rect(xf, -42, -124, 20, 28, neck_on, neck_clean)
	_rect(xf, -70, -132, 32, 16, head_on, head_clean)
	for i in display_slots("brachiosaurus_tooth"):
		var peg_x: float = -68.0 + float(i) * 4.0
		_rect(xf, peg_x, -118.0, 3.0, 6.0, slot_on("brachiosaurus_tooth", i), _slot_clean("brachiosaurus_tooth", i))
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
	_rect(xf, -14, -50, 52, 22, torso_on, torso_clean)
	_rect(xf, 32, -46, 64, 8, tail_on, tail_clean)
	_rect(xf, 2, -34, 14, 34, legs_on, legs_clean)
	_rect(xf, 14, -16, 16, 6, slot_on("velociraptor_claw", 0), _slot_clean("velociraptor_claw", 0))
	_rect(xf, -8, -14, 12, 5, slot_on("velociraptor_claw", 1), _slot_clean("velociraptor_claw", 1))
	_rect(xf, -8, -30, 10, 18, legs_on, legs_clean)
	_rect(xf, -28, -64, 16, 18, head_on, head_clean)
	_rect(xf, -54, -72, 28, 16, head_on, head_clean)
	_rect(xf, -50, -58, 14, 6, head_on, head_clean)
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
	_rect(xf, -18, -54, 82, 28, torso_on, torso_clean)
	_rect(xf, 56, -46, 40, 10, tail_on, tail_clean)
	_rect(xf, -12, -28, 14, 20, legs_on, legs_clean)
	_rect(xf, 12, -28, 14, 20, legs_on, legs_clean)
	_rect(xf, 36, -28, 14, 20, legs_on, legs_clean)
	_rect(xf, 58, -26, 14, 18, legs_on, legs_clean)
	var foot_xs: Array[float] = [-12.0, 12.0, 36.0, 58.0]
	for i in display_slots("stegosaurus_foot"):
		var foot_x: float = foot_xs[i] if i < foot_xs.size() else 58.0 + float(i - 3) * 16.0
		_rect(xf, foot_x, -8.0, 14.0, 8.0, slot_on("stegosaurus_foot", i), _slot_clean("stegosaurus_foot", i))
	_rect(xf, -44, -48, 28, 14, head_on, head_clean)
	var plate_pts: Array[PackedVector2Array] = [
		PackedVector2Array([Vector2(-4, -54), Vector2(8, -84), Vector2(20, -54)]),
		PackedVector2Array([Vector2(22, -54), Vector2(36, -88), Vector2(50, -54)]),
		PackedVector2Array([Vector2(48, -54), Vector2(60, -80), Vector2(72, -54)]),
	]
	for i in display_slots("stegosaurus_plate"):
		if i >= plate_pts.size():
			continue
		_poly(xf, plate_pts[i], slot_on("stegosaurus_plate", i), _slot_clean("stegosaurus_plate", i))
	_rect(xf, 90, -54, 6, 16, tail_on, tail_clean)
	_rect(xf, 100, -50, 6, 14, tail_on, tail_clean)
	_draw_stand_finish("stegosaurus", stand)


func _draw_stand(stand: Rect2, _title: String, stand_id: String) -> Rect2:
	var featured: bool = GameState.featured_stand_id == stand_id and GameState.stand_is_filled(stand_id)
	if featured:
		_draw_spotlight(stand)
	_draw_platform(stand, featured)
	_draw_plaque(Vector2(stand.get_center().x, stand.end.y - 12.0), plaque_title_for(stand_id), featured)
	return Rect2(
		stand.position.x + 22.0,
		stand.position.y + 16.0,
		stand.size.x - 44.0,
		stand.size.y - 54.0
	)


func _draw_stand_finish(stand_id: String, stand: Rect2) -> void:
	if GameState.stand_has_pending_unveil(stand_id):
		_draw_ribbon(stand, stand_id)
		_redraw_plaque(stand_id)
	if flash_t > 0.0 and flash_stand_id == stand_id:
		draw_rect(stand, Color(1.0, 0.86, 0.40, 0.55 * flash_t))
		draw_rect(stand.grow(10.0), Color(1.0, 0.92, 0.55, 0.28 * flash_t), false, 6.0)


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


func _draw_spotlight(stand: Rect2) -> void:
	var power: float = spotlight_beam_scale()
	var apex: Vector2 = Vector2(stand.get_center().x, stand.position.y - 90.0 * power)
	var inset: float = 8.0 / maxf(power, 0.35)
	var left: Vector2 = Vector2(stand.position.x + inset, stand.end.y - 8.0)
	var right: Vector2 = Vector2(stand.end.x - inset, stand.end.y - 8.0)
	draw_colored_polygon(PackedVector2Array([apex, left, right]), Color(1.0, 0.86, 0.45, 0.10 + 0.08 * power))
	draw_circle(Vector2(stand.get_center().x, stand.position.y + 18.0), 78.0 * power, Color(1.0, 0.90, 0.55, 0.07 + 0.05 * power))
	draw_circle(stand.get_center(), minf(stand.size.x, stand.size.y) * 0.42 * power, Color(1.0, 0.84, 0.40, 0.06 + 0.04 * power))


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
	var glow: float = 0.12 if featured else 0.06
	draw_circle(rect.get_center() + Vector2(0, -18), minf(rect.size.x, rect.size.y) * 0.36, Color(0.89, 0.72, 0.35, glow))


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
	_draw_label(center + Vector2(0, 5), title, 16 if featured else 14, Color("FFE08A") if featured else Ui.GOLD)


func _draw_plaque_lip(rect: Rect2) -> void:
	var lip := Rect2(rect.position.x - 8.0, rect.end.y - 3.0, rect.size.x + 16.0, 9.0)
	draw_rect(lip, Color("3A2818"))
	draw_rect(Rect2(lip.position.x, lip.end.y - 3.0, lip.size.x, 3.0), Color("2A1C10"))
	draw_line(lip.position, Vector2(lip.end.x, lip.position.y), Color("8A6A40"), 1.2)


func _draw_plaque_plate(rect: Rect2, featured: bool) -> void:
	draw_rect(rect, Color("4A3418") if featured else Color("3A2A14"))
	draw_rect(rect.grow(-3.0), Color("3A2A14") if featured else Color("2C2118"))


func _draw_plaque_bevel(rect: Rect2, featured: bool) -> void:
	var outer: Color = Color("8A6A28") if featured else Color("6A523C")
	var hi: Color = Color("FFE8A0") if featured else Color("E8C878")
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
	var font: Font = Ui.display_font()
	var size: int = label_font_size(font_size)
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string(font, center + Vector2(-width * 0.5, 0.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
