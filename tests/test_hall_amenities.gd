extends SceneTree

## Museum shop ranks place hall furniture. Start hall stays bare.
## Run: godot --headless --path <project> -s res://tests/test_hall_amenities.gd

var _failed: int = 0
var _passed: int = 0
var GS: Node

const NORTH_HALL_Y := 650.0
const UNUSED_SCATTER_BENCHES := [
	Vector2(548, 420),
	Vector2(20, 520),
	Vector2(1400, 420),
	Vector2(250, 900),
	Vector2(1650, 920),
]
const UNUSED_LAMPS := [
	Vector2(320, 430),
	Vector2(1680, 430),
	Vector2(320, 860),
	Vector2(1680, 860),
	Vector2(1000, 1080),
	Vector2(320, 1280),
	Vector2(1680, 1280),
	Vector2(620, 268),
	Vector2(1380, 268),
	Vector2(1000, 498),
	Vector2(1240, 158),
	Vector2(28, 850),
	Vector2(1972, 850),
	Vector2(760, 1462),
]
const FLOOR_Y := 218.0
const AISLE := Rect2(920.0, 500.0, 160.0, 980.0)
const NORTH_VIEW_Y := 500.0
const HALL_SIZE := Vector2(2000, 1480)
const WEST_WALL_X := 40.0
const EAST_WALL_X := 1960.0
const NORTH_WALL_Y := 196.0
const SOUTH_WALL_Y := 1440.0
const BOARD := Rect2(810, 20, 380, 164)
const FRAME_A := Rect2(220, 86, 200, 96)
const FRAME_B := Rect2(1630, 86, 200, 96)
const NORTH_GIFT := Rect2(1280, 388, 96, 48)
const SOUTH_GIFT := Rect2(1120, 1420, 140, 40)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	GS = root.get_node("GameState")
	_test_start_hall_has_no_shop_furniture()
	_test_labels_zero_hides_wall_frames()
	_test_labels_below_three_hides_case_titles()
	_test_benches_rank_one_fronts_t_rex()
	_test_lighting_rank_one_places_t_rex_bay_lamp_and_runner()
	_test_gift_shop_rank_one_places_north_kiosk()
	_test_glass_case_zero_has_no_sheen()
	_test_benches_rank_n_fronts_first_n_dino_stands()
	_test_each_new_bench_is_a_distinct_stand_slot()
	_test_fifth_bench_fronts_stegosaurus()
	_test_hall_stays_at_five_benches_and_lamps()
	_test_lighting_rank_n_ties_lamps_to_the_same_stands()
	_test_lighting_each_rank_adds_a_bay_fixture()
	_test_unveil_time_has_no_hours_plate()
	_test_warm_lights_stay_off_featured_name()
	_test_glass_case_sheen_scales_on_cases_only()
	_test_labels_rank_one_shows_wall_frames()
	_test_labels_rank_three_shows_case_titles()
	_test_labels_enrich_plaque_gold()
	_test_gift_details_scale_on_the_north_prop()
	_test_late_ranks_add_south_gift()
	_test_south_props_stay_off_mounts_and_aisle()
	_test_crowd_ranks_add_no_benches_or_shops()
	_test_rank_one_tells_sit_in_the_default_north_view()
	_test_crowds_place_north_velvet_rope()
	_test_unveil_crowd_places_board_bunting()
	print("hall_amenities %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _reset() -> void:
	GS.pieces.clear()
	GS.money = 0
	GS.featured_stand_id = ""
	GS.pending_unveils.clear()
	GS.unveil_spike_left = 0.0
	if "unveil_rush_stacks" in GS:
		GS.unveil_rush_stacks = 0
	if "unveil_rush_unit" in GS:
		GS.unveil_rush_unit = 0.0
	GS._income_accum = 0.0
	for item in GS.catalog:
		GS.levels[item["id"]] = 0
	GS.apply_upgrades()


func _make_exhibit() -> Node2D:
	var exhibit: Node2D = Node2D.new()
	exhibit.set_script(load("res://museum_exhibit.gd"))
	root.add_child(exhibit)
	return exhibit


func _set_rank(id: String, rank: int) -> void:
	GS.levels[id] = rank
	GS.apply_upgrades()


func _amenity_stand_ids(exhibit: Node2D) -> Array:
	var ids: Array = []
	for stand_id in exhibit.STAND_LAYOUT:
		var id := str(stand_id)
		if id == "small_finds" or id == "plant_fossils":
			continue
		ids.append(id)
	return ids


func _assert_bench_fronts_stand(exhibit: Node2D, bench: Rect2, stand_id: String) -> void:
	var stand: Rect2 = exhibit.stand_rect(stand_id)
	_assert(bench.size.x > 1.0 and bench.size.y > 1.0, "%s bench has size" % stand_id)
	_assert(not stand.intersects(bench), "%s bench stays off the mount" % stand_id)
	_assert(not _overlaps_gather_slots(exhibit, bench), "%s bench stays off gather slots" % stand_id)
	_assert(not AISLE.intersects(bench), "%s bench stays off the visitor path" % stand_id)
	_assert(bench.position.y >= stand.end.y - 0.5, "%s bench is south of the stand" % stand_id)
	_assert(bench.position.y <= stand.end.y + 48.0, "%s bench sits just south of the stand" % stand_id)
	var center_x: float = bench.get_center().x
	var stand_cx: float = stand.get_center().x
	if absf(stand_cx - 1000.0) <= 80.0:
		_assert(bench.position.x >= stand.position.x - 8.0, "%s bench stays in front of the stand" % stand_id)
		_assert(bench.end.x <= stand.end.x + 8.0, "%s bench stays in front of the stand" % stand_id)
		_assert(absf(center_x - stand_cx) <= stand.size.x * 0.45, "%s bench stays near the stand center after the runner dodge" % stand_id)
	else:
		_assert(absf(center_x - stand_cx) <= 12.0, "%s bench is centered on the stand" % stand_id)


func _assert_lamp_on_stand_bay(exhibit: Node2D, lamp: Vector2, stand_id: String) -> void:
	var stand: Rect2 = exhibit.stand_rect(stand_id)
	var cx: float = stand.get_center().x
	_assert(_is_edge_lamp(lamp), "%s lamp sits on a hall wall" % stand_id)
	if cx < 1000.0:
		_assert(lamp.x <= WEST_WALL_X, "%s lamp is on the west wall" % stand_id)
		_assert(absf(lamp.y - stand.get_center().y) <= stand.size.y * 0.5 + 8.0, "%s lamp is at that bay's height" % stand_id)
	elif cx > 1000.0:
		_assert(lamp.x >= EAST_WALL_X, "%s lamp is on the east wall" % stand_id)
		_assert(absf(lamp.y - stand.get_center().y) <= stand.size.y * 0.5 + 8.0, "%s lamp is at that bay's height" % stand_id)
	else:
		_assert(lamp.y <= NORTH_WALL_Y, "%s lamp is on the north wall" % stand_id)
		_assert(lamp.x >= stand.position.x - 16.0 and lamp.x <= stand.end.x + 16.0, "%s lamp sits on that bay's wall" % stand_id)
		_assert(not BOARD.has_point(lamp), "%s lamp stays off the FOSSIL HALL board" % stand_id)


func _assert_rope_pairs_aisle_at_row(exhibit: Node2D, rope: Rect2, stand_id: String) -> void:
	var stand: Rect2 = exhibit.stand_rect(stand_id)
	_assert(not AISLE.intersects(rope), "%s rope stays off the walker aisle" % stand_id)
	_assert(not stand.intersects(rope), "%s rope stays off the mount" % stand_id)
	_assert(rope.end.x <= AISLE.position.x or rope.position.x >= AISLE.end.x, "%s rope flanks the aisle" % stand_id)
	var y_ok: bool = absf(rope.position.y - stand.end.y) <= 24.0
	if not y_ok:
		for other_id in exhibit.STAND_LAYOUT:
			var other: Rect2 = exhibit.stand_rect(str(other_id))
			if absf(other.position.y - stand.position.y) < 80.0 and absf(rope.position.y - other.end.y) <= 24.0:
				y_ok = true
				break
	_assert(y_ok, "%s rope sits at that aisle crossing" % stand_id)
	if rope.end.x <= AISLE.position.x:
		_assert(AISLE.position.x - rope.end.x <= 24.0, "%s west rope hugs the aisle" % stand_id)
	else:
		_assert(rope.position.x - AISLE.end.x <= 24.0, "%s east rope hugs the aisle" % stand_id)


func _has_point_vec(points: Array, want: Vector2) -> bool:
	for point in points:
		if point == want:
			return true
	return false


func _test_start_hall_has_no_shop_furniture() -> void:
	_reset()
	var exhibit: Node2D = _make_exhibit()
	_assert(exhibit.has_method("hall_bench_rects"), "exhibit exposes bench rects")
	_assert(exhibit.has_method("hall_lamp_count"), "exhibit exposes lamp count")
	_assert(exhibit.has_method("hall_runner_visible"), "exhibit exposes runner visibility")
	_assert(exhibit.has_method("hall_frame_rects"), "exhibit exposes wall frames")
	_assert(exhibit.has_method("hall_gift_rect"), "exhibit exposes the gift counter")
	_assert(exhibit.has_method("hall_hours_rect"), "exhibit exposes the hours query")
	_assert(exhibit.has_method("hall_case_glass_alpha"), "exhibit exposes case glass alpha")
	_assert(exhibit.has_method("hall_case_titles_visible"), "exhibit exposes case-title visibility")
	if not exhibit.has_method("hall_bench_rects"):
		exhibit.free()
		return
	_assert(exhibit.call("hall_bench_rects").is_empty(), "0 Museum ranks draw 0 benches")
	_assert(int(exhibit.call("hall_lamp_count")) == 0, "0 Museum ranks draw 0 lamps")
	_assert(not bool(exhibit.call("hall_runner_visible")), "0 lighting ranks hide the runner")
	if exhibit.has_method("hall_lamp_fixture_rects"):
		_assert(exhibit.call("hall_lamp_fixture_rects").is_empty(), "0 lighting ranks hide lamp fixtures")
	if exhibit.has_method("hall_lamp_pools"):
		_assert(exhibit.call("hall_lamp_pools").is_empty(), "0 lighting ranks hide lamp wash")
	_assert(exhibit.call("hall_frame_rects").is_empty(), "0 labels ranks draw 0 wall frames")
	_assert(exhibit.call("hall_gift_rect").size == Vector2.ZERO, "0 gift_shop ranks hide the counter")
	_assert(exhibit.call("hall_hours_rect").size == Vector2.ZERO, "0 unveil_time ranks have no hours plate")
	if exhibit.has_method("hall_gift_south_rect"):
		_assert(exhibit.call("hall_gift_south_rect").size == Vector2.ZERO, "0 gift_shop ranks hide the south counter")
	if exhibit.has_method("hall_crowd_rope_rects"):
		_assert(exhibit.call("hall_crowd_rope_rects").is_empty(), "0 crowds ranks hide the velvet ropes")
	if exhibit.has_method("hall_opening_bunting_rect"):
		_assert(exhibit.call("hall_opening_bunting_rect").size == Vector2.ZERO, "0 unveil_crowd ranks hide the opening bunting")
	_assert(is_equal_approx(float(exhibit.call("hall_case_glass_alpha", "small_finds")), 0.0), "start hall has no Small Finds sheen")
	_assert(is_equal_approx(float(exhibit.call("hall_case_glass_alpha", "plant_fossils")), 0.0), "start hall has no Plant Fossils sheen")
	_assert(not bool(exhibit.call("hall_case_titles_visible")), "start hall hides case-cell titles")
	_assert(str(exhibit.call("hall_board").get("status", "")).find("waiting") >= 0, "empty hall still says it is waiting")
	exhibit.free()


func _test_labels_zero_hides_wall_frames() -> void:
	_reset()
	var exhibit: Node2D = _make_exhibit()
	if not exhibit.has_method("hall_frame_rects"):
		_assert(false, "labels 0 has no wall frames")
		exhibit.free()
		return
	_assert(exhibit.call("hall_frame_rects").is_empty(), "labels 0 has no wall frames")
	exhibit.free()


func _test_labels_below_three_hides_case_titles() -> void:
	_reset()
	var exhibit: Node2D = _make_exhibit()
	if not exhibit.has_method("hall_case_titles_visible"):
		_assert(false, "labels < 3 hides case-cell titles")
		exhibit.free()
		return
	_assert(not bool(exhibit.call("hall_case_titles_visible")), "labels 0 hides case-cell titles")
	_set_rank("labels", 1)
	_assert(not bool(exhibit.call("hall_case_titles_visible")), "labels 1 hides case-cell titles")
	_set_rank("labels", 2)
	_assert(not bool(exhibit.call("hall_case_titles_visible")), "labels 2 hides case-cell titles")
	exhibit.free()


func _test_benches_rank_one_fronts_t_rex() -> void:
	_reset()
	_set_rank("benches", 1)
	var exhibit: Node2D = _make_exhibit()
	if not exhibit.has_method("hall_bench_rects"):
		_assert(false, "rank 1 benches places the T. rex bench")
		exhibit.free()
		return
	var benches: Array = exhibit.call("hall_bench_rects")
	_assert(benches.size() == 1, "rank 1 benches draws one bench")
	if benches.size() == 1:
		var bench: Rect2 = benches[0]
		_assert_bench_fronts_stand(exhibit, bench, "t_rex")
		_assert(bench.position.y < exhibit.stand_rect("triceratops").position.y, "rank 1 benches sits in the north hall")
		_assert(bench.size.x > 1.0 and bench.size.y > 1.0, "the T. rex bench has size")
		_assert(bench.position != UNUSED_SCATTER_BENCHES[0], "rank 1 is not the Small Finds–T. rex gap leftover")
	exhibit.free()


func _test_lighting_rank_one_places_t_rex_bay_lamp_and_runner() -> void:
	_reset()
	_set_rank("lighting", 1)
	var exhibit: Node2D = _make_exhibit()
	if not exhibit.has_method("hall_lamp_count") or not exhibit.has_method("hall_runner_visible"):
		_assert(false, "rank 1 lighting places the T. rex bay lamp and runner")
		exhibit.free()
		return
	_assert(int(exhibit.call("hall_lamp_count")) == 1, "rank 1 lighting draws one lamp")
	_assert(bool(exhibit.call("hall_runner_visible")), "rank 1 lighting lays the center runner")
	if exhibit.has_method("hall_lamp_centers"):
		var lamps: PackedVector2Array = exhibit.call("hall_lamp_centers")
		_assert(lamps.size() == 1, "rank 1 lighting lists one lamp center")
		if lamps.size() == 1:
			_assert_lamp_on_stand_bay(exhibit, lamps[0], "t_rex")
			_assert(lamps[0].x < BOARD.position.x or lamps[0].x > BOARD.end.x, "rank 1 sconce sits beside the FOSSIL HALL board")
			_assert(lamps[0].y < NORTH_VIEW_Y, "rank 1 sconce sits in the default north view")
			_assert(lamps[0].y < FLOOR_Y, "rank 1 is a wall sconce, not an aisle hanger over T. rex")
	if exhibit.has_method("hall_runner_rect"):
		var runner: Rect2 = exhibit.call("hall_runner_rect")
		_assert(runner.size.x > 24.0 and runner.size.x <= 72.0, "rank 1 runner is a warm stripe, not a billboard")
		_assert(runner.position.x < 1000.0 and runner.end.x > 1000.0, "rank 1 runner stays on the aisle axis")
	_assert_visible_fixture(exhibit, 0, "rank 1")
	exhibit.free()


func _test_gift_shop_rank_one_places_north_kiosk() -> void:
	_reset()
	_set_rank("gift_shop", 1)
	var exhibit: Node2D = _make_exhibit()
	if not exhibit.has_method("hall_gift_rect"):
		_assert(false, "rank 1 gift_shop places the north kiosk")
		exhibit.free()
		return
	var gift: Rect2 = exhibit.call("hall_gift_rect")
	_assert(gift.size.x > 1.0 and gift.size.y > 1.0, "rank 1 gift_shop places the kiosk")
	_assert(gift.position == NORTH_GIFT.position, "rank 1 gift kiosk sits east of the aisle near Plant Fossils")
	_assert(gift.position.y < NORTH_VIEW_Y, "rank 1 gift kiosk sits in the default north view")
	_assert(gift.position.x >= 1080.0, "gift kiosk sits east of the aisle")
	_assert(not _overlaps_stand_or_gather(exhibit, gift), "north gift kiosk stays off mounts and gather slots")
	if exhibit.has_method("hall_gift_south_rect"):
		_assert(exhibit.call("hall_gift_south_rect").size == Vector2.ZERO, "rank 1 gift_shop does not add the south counter")
	exhibit.free()


func _test_glass_case_zero_has_no_sheen() -> void:
	_reset()
	var exhibit: Node2D = _make_exhibit()
	if not exhibit.has_method("hall_case_glass_alpha"):
		_assert(false, "glass_case 0 has no sheen")
		exhibit.free()
		return
	_assert(is_equal_approx(float(exhibit.call("hall_case_glass_alpha", "small_finds")), 0.0), "glass_case 0 has no Small Finds sheen")
	_assert(is_equal_approx(float(exhibit.call("hall_case_glass_alpha", "plant_fossils")), 0.0), "glass_case 0 has no Plant Fossils sheen")
	_assert(is_equal_approx(float(exhibit.call("hall_case_glass_alpha", "t_rex")), 0.0), "dino mounts stay unglazed at rank 0")
	exhibit.free()


func _test_benches_rank_n_fronts_first_n_dino_stands() -> void:
	_reset()
	var exhibit: Node2D = _make_exhibit()
	if not exhibit.has_method("hall_bench_rects"):
		_assert(false, "benches rank N draws the first N benches")
		exhibit.free()
		return
	var stands: Array = _amenity_stand_ids(exhibit)
	_assert(stands.size() == 5, "five dinosaur stands get benches")
	var south_gap: float = -1.0
	for rank in 5:
		_set_rank("benches", rank + 1)
		var benches: Array = exhibit.call("hall_bench_rects")
		_assert(benches.size() == rank + 1, "benches rank %d draws %d benches" % [rank + 1, rank + 1])
		if benches.size() != rank + 1:
			continue
		for i in rank + 1:
			var bench: Rect2 = benches[i]
			_assert_bench_fronts_stand(exhibit, bench, stands[i])
			var stand: Rect2 = exhibit.stand_rect(str(stands[i]))
			var gap: float = bench.position.y - stand.end.y
			if south_gap < 0.0:
				south_gap = gap
			_assert(is_equal_approx(gap, south_gap), "bench %d uses the same south gap as the first bench" % (i + 1))
			_assert(not _has_point_vec(UNUSED_SCATTER_BENCHES, bench.position), "bench %d is not a leftover scatter coord" % (i + 1))
	exhibit.free()


func _test_each_new_bench_is_a_distinct_stand_slot() -> void:
	_reset()
	var exhibit: Node2D = _make_exhibit()
	if not exhibit.has_method("hall_bench_rects"):
		_assert(false, "each bench rank adds one distinct stand slot")
		exhibit.free()
		return
	var stands: Array = _amenity_stand_ids(exhibit)
	var seen: Array = []
	for rank in 5:
		_set_rank("benches", rank + 1)
		var benches: Array = exhibit.call("hall_bench_rects")
		_assert(benches.size() == rank + 1, "rank %d draws %d benches" % [rank + 1, rank + 1])
		if benches.size() != rank + 1:
			continue
		var newest: Rect2 = benches[rank]
		_assert_bench_fronts_stand(exhibit, newest, stands[rank])
		for earlier in seen:
			_assert(not (earlier as Rect2).intersects(newest), "bench %d is a new rect, not stacked on an earlier bench" % (rank + 1))
			_assert((earlier as Rect2).position != newest.position, "bench %d sits at a distinct origin" % (rank + 1))
		if rank == 0:
			_assert(newest.position.y < NORTH_HALL_Y, "rank 1 bench sits in the default north hall")
		seen.append(newest)
	exhibit.free()


func _test_fifth_bench_fronts_stegosaurus() -> void:
	_reset()
	_set_rank("benches", 5)
	var exhibit: Node2D = _make_exhibit()
	if not exhibit.has_method("hall_bench_rects"):
		_assert(false, "rank 5 benches fills the five dinosaur slots")
		exhibit.free()
		return
	var stands: Array = _amenity_stand_ids(exhibit)
	var benches: Array = exhibit.call("hall_bench_rects")
	_assert(benches.size() == 5, "rank 5 benches draws five benches")
	if benches.size() == 5 and stands.size() == 5:
		_assert(str(stands[0]) == "t_rex", "first amenity stand is T. rex")
		_assert(str(stands[4]) == "stegosaurus", "fifth amenity stand is Stegosaurus")
		for i in 5:
			_assert_bench_fronts_stand(exhibit, benches[i], stands[i])
	exhibit.free()


func _test_hall_stays_at_five_benches_and_lamps() -> void:
	_reset()
	for item in GS.catalog:
		var id: String = str(item.get("id", ""))
		if id == "benches" or id == "lighting":
			_assert(int(item.get("max", 0)) == 5, "%s stays five ranks, no sixth hall copy" % id)
	_set_rank("benches", 8)
	_set_rank("lighting", 8)
	var exhibit: Node2D = _make_exhibit()
	if not exhibit.has_method("hall_bench_rects"):
		_assert(false, "hall still lists benches after extra ranks")
		exhibit.free()
		return
	_assert(exhibit.call("hall_bench_rects").size() == 5, "forced extra bench ranks still draw five benches")
	_assert(int(exhibit.call("hall_lamp_count")) == 5, "forced extra lamp ranks still draw five lamps")
	exhibit.free()


func _test_lighting_rank_n_ties_lamps_to_the_same_stands() -> void:
	_reset()
	var exhibit: Node2D = _make_exhibit()
	if not exhibit.has_method("hall_lamp_count"):
		_assert(false, "lighting rank N draws the first N lamps")
		exhibit.free()
		return
	var stands: Array = _amenity_stand_ids(exhibit)
	for rank in 5:
		_set_rank("lighting", rank + 1)
		_assert(int(exhibit.call("hall_lamp_count")) == rank + 1, "lighting rank %d draws %d lamps" % [rank + 1, rank + 1])
		if exhibit.has_method("hall_lamp_centers"):
			var lamps: PackedVector2Array = exhibit.call("hall_lamp_centers")
			_assert(lamps.size() == rank + 1, "lighting rank %d lists %d lamp centers" % [rank + 1, rank + 1])
			for i in mini(lamps.size(), rank + 1):
				_assert_lamp_on_stand_bay(exhibit, lamps[i], stands[i])
				_assert(_is_edge_lamp(lamps[i]), "lamp %d sits on a hall edge" % (i + 1))
				_assert(not _on_aisle_gather(lamps[i]), "lamp %d stays off the 920–1080 aisle" % (i + 1))
			for unused in UNUSED_LAMPS:
				_assert(not _has_point(lamps, unused), "unused lamp at %s stays unused" % unused)
			_assert_lamps_off_featured_and_t_rex(exhibit, lamps)
		_assert(bool(exhibit.call("hall_runner_visible")), "lighting rank %d keeps the runner" % (rank + 1))
	exhibit.free()


func _test_lighting_each_rank_adds_a_bay_fixture() -> void:
	_reset()
	var exhibit: Node2D = _make_exhibit()
	if not exhibit.has_method("hall_lamp_centers") or not exhibit.has_method("hall_lamp_fixture_rects"):
		_assert(false, "lighting exposes glanceable fixtures")
		exhibit.free()
		return
	var stands: Array = _amenity_stand_ids(exhibit)
	_assert(int(exhibit.call("hall_lamp_count")) == 0, "lighting 0 has no fixtures")
	_assert(exhibit.call("hall_lamp_fixture_rects").is_empty(), "lighting 0 has no lamp bodies")
	if exhibit.has_method("hall_lamp_pools"):
		_assert(exhibit.call("hall_lamp_pools").is_empty(), "lighting 0 has no lamp wash")
	_assert(not bool(exhibit.call("hall_runner_visible")), "lighting 0 hides the runner")
	for rank in 5:
		_set_rank("lighting", rank + 1)
		var lamps: PackedVector2Array = exhibit.call("hall_lamp_centers")
		var fixtures: Array = exhibit.call("hall_lamp_fixture_rects")
		_assert(lamps.size() == rank + 1, "rank %d has %d visible fixtures" % [rank + 1, rank + 1])
		_assert(fixtures.size() == rank + 1, "rank %d draws %d lamp bodies" % [rank + 1, rank + 1])
		_assert(bool(exhibit.call("hall_runner_visible")), "rank %d keeps the gold runner" % (rank + 1))
		_assert_one_lamp_object(exhibit, rank, "rank %d" % (rank + 1))
		_assert_visible_fixture(exhibit, rank, "rank %d" % (rank + 1))
		if lamps.size() > rank:
			_assert_lamp_on_stand_bay(exhibit, lamps[rank], stands[rank])
	var all_lamps: PackedVector2Array = exhibit.call("hall_lamp_centers")
	_assert(all_lamps.size() == 5, "max lighting places five stand-tied fixtures")
	if all_lamps.size() == 5 and stands.size() == 5:
		_assert_lamp_on_stand_bay(exhibit, all_lamps[0], "t_rex")
		_assert_lamp_on_stand_bay(exhibit, all_lamps[1], "triceratops")
		_assert_lamp_on_stand_bay(exhibit, all_lamps[2], "brachiosaurus")
		_assert_lamp_on_stand_bay(exhibit, all_lamps[3], "velociraptor")
		_assert_lamp_on_stand_bay(exhibit, all_lamps[4], "stegosaurus")
		_assert(all_lamps[1].x <= WEST_WALL_X, "Triceratops lamp is a west-wall sconce")
		_assert(all_lamps[2].x >= EAST_WALL_X, "Brachiosaurus lamp is an east-wall sconce")
		_assert(all_lamps[3].x <= WEST_WALL_X, "Velociraptor lamp is a west-wall sconce")
		_assert(all_lamps[4].x >= EAST_WALL_X, "Stegosaurus lamp is an east-wall sconce")
		_assert(all_lamps[1].y != all_lamps[0].y, "mid-hall lamps are not a second north-wall leftover")
	for lamp in all_lamps:
		_assert(_is_edge_lamp(lamp), "fixture at %s sits on a hall edge" % lamp)
		_assert(not _on_aisle_gather(lamp), "fixture at %s stays off the aisle gather path" % lamp)
	_assert_lamps_off_featured_and_t_rex(exhibit, all_lamps)
	exhibit.free()


func _test_unveil_time_has_no_hours_plate() -> void:
	_reset()
	var exhibit: Node2D = _make_exhibit()
	if not exhibit.has_method("hall_hours_rect"):
		_assert(false, "exhibit still answers the hours query")
		exhibit.free()
		return
	_assert(exhibit.call("hall_hours_rect").size == Vector2.ZERO, "unveil_time 0 has no hours plate")
	_set_rank("unveil_time", 1)
	_assert(exhibit.call("hall_hours_rect").size == Vector2.ZERO, "unveil_time 1 has no hours plate")
	_set_rank("unveil_time", 4)
	_assert(exhibit.call("hall_hours_rect").size == Vector2.ZERO, "unveil_time 4 has no hours plate")
	if exhibit.has_method("hall_hours_marks"):
		_assert(int(exhibit.call("hall_hours_marks")) == 0, "rank N hours shows no open marks")
	var feat: Rect2 = exhibit.call("hall_board_featured_rect")
	var board: Rect2 = exhibit.call("hall_board_rect")
	_assert(feat.size.y >= board.size.y - 50.0, "Featured keeps the board; no Hours reserve")
	exhibit.free()


func _test_warm_lights_stay_off_featured_name() -> void:
	_reset()
	GS.install_find("brachiosaurus_skull", "Brachiosaurus Skull", 1.0, true)
	GS.unveil_stand("brachiosaurus")
	GS.set_featured_stand("brachiosaurus")
	_set_rank("lighting", 5)
	_set_rank("unveil_time", 1)
	var exhibit: Node2D = _make_exhibit()
	if not exhibit.has_method("hall_lamp_discs"):
		_assert(false, "exhibit exposes lamp glow discs")
		exhibit.free()
		return
	var board: Rect2 = exhibit.call("hall_board_rect")
	var feat: Rect2 = exhibit.call("hall_board_featured_rect")
	var discs: Array = exhibit.call("hall_lamp_discs")
	_assert(not discs.is_empty(), "warm lights still place modest north lamps")
	var t_rex: Rect2 = exhibit.stand_rect("t_rex")
	for disc in discs:
		var glow: Rect2 = disc
		_assert(glow.size.x <= 28.0 and glow.size.y <= 28.0, "lamp glow is a small fixture halo, not a gold coin")
		_assert(not feat.intersects(glow), "lamp glow stays off the Featured name")
		_assert(not board.encloses(glow), "lamp glow is not a blob on the FOSSIL HALL board")
		_assert(not t_rex.intersects(glow), "lamp glow stays off the T. rex silhouette")
	if exhibit.has_method("hall_lamp_fixture_rects"):
		for fixture in exhibit.call("hall_lamp_fixture_rects"):
			_assert(not feat.intersects(fixture), "lamp body stays off the Featured name")
			_assert(not board.encloses(fixture), "lamp body is not drawn on the FOSSIL HALL board")
			_assert(not t_rex.intersects(fixture), "lamp body stays off the T. rex silhouette")
	if exhibit.has_method("hall_lamp_pools"):
		var pools: Array = exhibit.call("hall_lamp_pools")
		_assert(pools.size() == discs.size(), "max lighting lists one wash per lamp, not a second pool list")
		for i in pools.size():
			var pool: Rect2 = pools[i]
			_assert((pool as Rect2).get_center().is_equal_approx((discs[i] as Rect2).get_center()), "lamp wash shares the fixture center")
			_assert(not feat.intersects(pool), "lamp wash stays off the Featured name")
			_assert(not board.encloses(pool), "lamp wash is not a blob on the FOSSIL HALL board")
			_assert(not t_rex.intersects(pool), "lamp wash stays off the T. rex silhouette")
	var lamps: PackedVector2Array = exhibit.call("hall_lamp_centers")
	_assert(not lamps.is_empty() and lamps[0].y < NORTH_VIEW_Y, "rank 1 lighting still has a north tell")
	_assert(lamps[0].x < BOARD.position.x or lamps[0].x > BOARD.end.x or lamps[0].y < BOARD.position.y, "north lamp sits beside or above the board, not on Featured")
	for i in lamps.size():
		_assert(_is_edge_lamp(lamps[i]), "lamp %d sits on a hall edge, not over a bay" % (i + 1))
		_assert(not _on_aisle_gather(lamps[i]), "lamp %d stays off the aisle gather path" % (i + 1))
	_assert_lamps_off_featured_and_t_rex(exhibit, lamps)
	exhibit.free()


func _test_glass_case_sheen_scales_on_cases_only() -> void:
	_reset()
	var exhibit: Node2D = _make_exhibit()
	if not exhibit.has_method("hall_case_glass_alpha"):
		_assert(false, "glass_case sheen scales on the two cases")
		exhibit.free()
		return
	_set_rank("glass_case", 1)
	var small_one: float = float(exhibit.call("hall_case_glass_alpha", "small_finds"))
	var plant_one: float = float(exhibit.call("hall_case_glass_alpha", "plant_fossils"))
	_assert(small_one >= 0.22, "glass_case 1 paints a readable Small Finds sheen")
	_assert(plant_one >= 0.22, "glass_case 1 paints a readable Plant Fossils sheen")
	_assert(is_equal_approx(float(exhibit.call("hall_case_glass_alpha", "t_rex")), 0.0), "glass_case does not glaze T. rex")
	_assert(is_equal_approx(float(exhibit.call("hall_case_glass_alpha", "triceratops")), 0.0), "glass_case does not glaze dino mounts")
	_set_rank("glass_case", 6)
	_assert(float(exhibit.call("hall_case_glass_alpha", "small_finds")) > small_one, "higher glass_case rank thickens the sheen")
	exhibit.free()


func _test_labels_rank_one_shows_wall_frames() -> void:
	_reset()
	_set_rank("labels", 1)
	var exhibit: Node2D = _make_exhibit()
	if not exhibit.has_method("hall_frame_rects"):
		_assert(false, "labels 1 shows the two wall frames")
		exhibit.free()
		return
	var frames: Array = exhibit.call("hall_frame_rects")
	_assert(frames.size() == 2, "labels 1–2 draw both wall frames")
	if frames.size() == 2:
		_assert(frames[0].position == FRAME_A.position, "west wall frame stays at 220,86")
		_assert(frames[1].position == FRAME_B.position, "east wall frame stays at 1630,86")
		_assert(frames[0].size.x >= 190.0 and frames[0].size.y >= 90.0, "west wall frame is a hanging picture, not a sliver")
		_assert(frames[1].size.x >= 190.0 and frames[1].size.y >= 90.0, "east wall frame is a hanging picture, not a sliver")
	_set_rank("labels", 2)
	_assert(exhibit.call("hall_frame_rects").size() == 2, "labels 2 still draws both wall frames")
	exhibit.free()


func _test_labels_rank_three_shows_case_titles() -> void:
	_reset()
	_set_rank("labels", 3)
	var exhibit: Node2D = _make_exhibit()
	if not exhibit.has_method("hall_case_titles_visible"):
		_assert(false, "labels 3+ shows case-cell titles")
		exhibit.free()
		return
	_assert(bool(exhibit.call("hall_case_titles_visible")), "labels 3+ shows case-cell titles")
	_set_rank("labels", 6)
	_assert(bool(exhibit.call("hall_case_titles_visible")), "labels 6 still shows case-cell titles")
	exhibit.free()


func _test_labels_enrich_plaque_gold() -> void:
	_reset()
	var exhibit: Node2D = _make_exhibit()
	if not exhibit.has_method("hall_plaque_gold"):
		_assert(false, "higher labels ranks enrich plaque gold")
		exhibit.free()
		return
	var plain: Color = exhibit.call("hall_plaque_gold")
	_set_rank("labels", 6)
	var rich: Color = exhibit.call("hall_plaque_gold")
	_assert(rich.r + rich.g > plain.r + plain.g, "higher labels ranks enrich plaque gold")
	exhibit.free()


func _test_gift_details_scale_on_the_north_prop() -> void:
	_reset()
	var exhibit: Node2D = _make_exhibit()
	if not exhibit.has_method("hall_gift_rect"):
		_assert(false, "later gift ranks dress the north kiosk")
		exhibit.free()
		return
	_set_rank("gift_shop", 1)
	var gift: Rect2 = exhibit.call("hall_gift_rect")
	_assert(gift.position == NORTH_GIFT.position, "rank 1 gift is the north kiosk")
	_assert(not exhibit.call("hall_gift_has_rack") if exhibit.has_method("hall_gift_has_rack") else true, "rank 1 gift is only the kiosk")
	_set_rank("gift_shop", 3)
	_assert(exhibit.call("hall_gift_rect") == gift, "later gift ranks dress the same north kiosk")
	if exhibit.has_method("hall_gift_has_rack"):
		_assert(bool(exhibit.call("hall_gift_has_rack")), "later gift ranks add a postcard rack")
	if exhibit.has_method("hall_gift_has_stack"):
		_assert(bool(exhibit.call("hall_gift_has_stack")), "later gift ranks add a souvenir stack")
	exhibit.free()


func _test_late_ranks_add_south_gift() -> void:
	_reset()
	var exhibit: Node2D = _make_exhibit()
	if not exhibit.has_method("hall_gift_south_rect"):
		_assert(false, "late gift ranks add the south counter")
		exhibit.free()
		return
	_set_rank("gift_shop", 3)
	_assert(exhibit.call("hall_gift_south_rect").size == Vector2.ZERO, "gift ranks 1–3 keep only the north kiosk")
	_set_rank("gift_shop", 4)
	var south_gift: Rect2 = exhibit.call("hall_gift_south_rect")
	_assert(south_gift.position == SOUTH_GIFT.position, "gift rank 4+ adds the south counter")
	_assert(south_gift.position.y > 1380.0, "late gift extra sits at the south end")
	exhibit.free()


func _test_south_props_stay_off_mounts_and_aisle() -> void:
	_reset()
	_set_rank("benches", 5)
	_set_rank("gift_shop", 6)
	_set_rank("unveil_time", 4)
	_set_rank("crowds", 6)
	_set_rank("unveil_crowd", 4)
	var exhibit: Node2D = _make_exhibit()
	if not exhibit.has_method("hall_gift_rect"):
		_assert(false, "amenity props stay off mounts and the aisle")
		exhibit.free()
		return
	var props: Array = []
	props.append_array(exhibit.call("hall_bench_rects"))
	props.append(exhibit.call("hall_gift_rect"))
	if exhibit.has_method("hall_gift_south_rect"):
		props.append(exhibit.call("hall_gift_south_rect"))
	if exhibit.has_method("hall_crowd_rope_rects"):
		props.append_array(exhibit.call("hall_crowd_rope_rects"))
	var hours: Rect2 = exhibit.call("hall_hours_rect")
	var bunting: Rect2 = exhibit.call("hall_opening_bunting_rect") if exhibit.has_method("hall_opening_bunting_rect") else Rect2()
	_assert(hours.size == Vector2.ZERO, "unveil_time 4 still has no hours plate")
	for stand_id in exhibit.STAND_LAYOUT:
		var stand: Rect2 = exhibit.stand_rect(str(stand_id))
		for prop in props:
			_assert(not stand.intersects(prop), "%s stays off %s" % [_prop_name(prop, exhibit), stand_id])
	for prop in props:
		_assert(not AISLE.intersects(prop), "%s stays off the visitor aisle" % _prop_name(prop, exhibit))
		_assert(not _overlaps_gather_slots(exhibit, prop), "%s stays off visitor gather slots" % _prop_name(prop, exhibit))
	if bunting.size != Vector2.ZERO:
		_assert(BOARD.intersects(bunting) or bunting.position.y < 80.0, "opening bunting hangs on the north board wall")
	exhibit.free()


func _test_crowd_ranks_add_no_benches_or_shops() -> void:
	_reset()
	var exhibit: Node2D = _make_exhibit()
	if not exhibit.has_method("hall_bench_rects"):
		_assert(false, "crowd ranks add no benches or shops")
		exhibit.free()
		return
	_set_rank("unveil_crowd", 4)
	_set_rank("crowds", 6)
	_set_rank("spotlight", 3)
	_assert(exhibit.call("hall_bench_rects").is_empty(), "unveil_crowd and crowds add no benches")
	_assert(int(exhibit.call("hall_lamp_count")) == 0, "spotlight adds no lamps")
	_assert(exhibit.call("hall_gift_rect").size == Vector2.ZERO, "crowd ranks add no gift counter")
	exhibit.free()


func _test_rank_one_tells_sit_in_the_default_north_view() -> void:
	_reset()
	var exhibit: Node2D = _make_exhibit()
	_set_rank("benches", 1)
	_set_rank("gift_shop", 1)
	_set_rank("unveil_time", 1)
	_set_rank("crowds", 1)
	_set_rank("unveil_crowd", 1)
	_set_rank("lighting", 1)
	_set_rank("labels", 1)
	_set_rank("glass_case", 1)
	var benches: Array = exhibit.call("hall_bench_rects")
	_assert(not benches.is_empty() and benches[0].position.y < exhibit.stand_rect("triceratops").position.y, "rank 1 benches is the north T. rex slot")
	if not benches.is_empty():
		_assert_bench_fronts_stand(exhibit, benches[0], "t_rex")
	_assert(_in_north_view(exhibit.call("hall_gift_rect")), "rank 1 gift_shop is in the default north view")
	_assert(exhibit.call("hall_hours_rect").size == Vector2.ZERO, "rank 1 unveil_time places no hours plate")
	if exhibit.has_method("hall_crowd_rope_rects"):
		var ropes: Array = exhibit.call("hall_crowd_rope_rects")
		_assert(not ropes.is_empty() and _in_north_view(ropes[0]), "rank 1 crowds rope is in the default north view")
	else:
		_assert(false, "rank 1 crowds rope is in the default north view")
	if exhibit.has_method("hall_opening_bunting_rect"):
		_assert(_in_north_view(exhibit.call("hall_opening_bunting_rect")), "rank 1 unveil_crowd bunting is in the default north view")
	else:
		_assert(false, "rank 1 unveil_crowd bunting is in the default north view")
	if exhibit.has_method("hall_lamp_centers"):
		var lamps: PackedVector2Array = exhibit.call("hall_lamp_centers")
		_assert(not lamps.is_empty() and lamps[0].y < NORTH_VIEW_Y, "rank 1 lighting lamp is in the default north view")
	_assert(not exhibit.call("hall_frame_rects").is_empty() and _in_north_view(exhibit.call("hall_frame_rects")[0]), "rank 1 labels frame is in the default north view")
	_assert(float(exhibit.call("hall_case_glass_alpha", "small_finds")) >= 0.22, "rank 1 glass_case is readable on the north cases")
	exhibit.free()


func _test_crowds_place_north_velvet_rope() -> void:
	_reset()
	var exhibit: Node2D = _make_exhibit()
	if not exhibit.has_method("hall_crowd_rope_rects"):
		_assert(false, "crowds places a north velvet-rope marker")
		exhibit.free()
		return
	_assert(exhibit.call("hall_crowd_rope_rects").is_empty(), "crowds 0 hides the velvet rope")
	_set_rank("crowds", 1)
	var ropes: Array = exhibit.call("hall_crowd_rope_rects")
	_assert(ropes.size() == 1, "rank 1 crowds draws one north rope")
	if ropes.size() == 1:
		_assert_rope_pairs_aisle_at_row(exhibit, ropes[0], "t_rex")
		_assert(ropes[0].position.y < NORTH_HALL_Y, "rank 1 crowds rope sits in the north aisle")
		_assert(not AISLE.intersects(ropes[0]), "velvet rope stays off the walker aisle")
		_assert(not _overlaps_stand_or_gather(exhibit, ropes[0]), "velvet rope stays off mounts and gather slots")
	_set_rank("crowds", 2)
	var pair: Array = exhibit.call("hall_crowd_rope_rects")
	_assert(pair.size() == 2, "rank 2 crowds completes the T. rex aisle pair")
	if pair.size() == 2:
		_assert_rope_pairs_aisle_at_row(exhibit, pair[0], "t_rex")
		_assert_rope_pairs_aisle_at_row(exhibit, pair[1], "t_rex")
		_assert(pair[0].end.x <= AISLE.position.x, "first rope is west of the aisle")
		_assert(pair[1].position.x >= AISLE.end.x, "second rope is east of the aisle")
		_assert(is_equal_approx(pair[0].position.y, pair[1].position.y), "the T. rex pair shares one aisle crossing")
	_set_rank("crowds", 6)
	var all_ropes: Array = exhibit.call("hall_crowd_rope_rects")
	_assert(all_ropes.size() == 6, "max crowds places three aisle pairs")
	if all_ropes.size() == 6:
		_assert_rope_pairs_aisle_at_row(exhibit, all_ropes[2], "triceratops")
		_assert_rope_pairs_aisle_at_row(exhibit, all_ropes[3], "brachiosaurus")
		_assert_rope_pairs_aisle_at_row(exhibit, all_ropes[4], "velociraptor")
		_assert_rope_pairs_aisle_at_row(exhibit, all_ropes[5], "stegosaurus")
	exhibit.free()


func _test_unveil_crowd_places_board_bunting() -> void:
	_reset()
	var exhibit: Node2D = _make_exhibit()
	if not exhibit.has_method("hall_opening_bunting_rect"):
		_assert(false, "unveil_crowd places grand-opening bunting on the board")
		exhibit.free()
		return
	_assert(exhibit.call("hall_opening_bunting_rect").size == Vector2.ZERO, "unveil_crowd 0 hides the bunting")
	_set_rank("unveil_crowd", 1)
	var bunting: Rect2 = exhibit.call("hall_opening_bunting_rect")
	_assert(bunting.size.x > 1.0 and bunting.size.y > 1.0, "unveil_crowd 1 hangs opening bunting")
	_assert(_in_north_view(bunting), "opening bunting sits in the default north view")
	_assert(BOARD.intersects(bunting) or absf(bunting.position.y - BOARD.position.y) < 40.0, "opening bunting hangs on the FOSSIL HALL board")
	if exhibit.has_method("hall_opening_bunting_flags"):
		var one: int = int(exhibit.call("hall_opening_bunting_flags"))
		_set_rank("unveil_crowd", 4)
		_assert(int(exhibit.call("hall_opening_bunting_flags")) > one, "higher unveil_crowd ranks enrich the bunting")
	exhibit.free()


func _assert_one_lamp_object(exhibit: Node2D, index: int, label: String) -> void:
	if not exhibit.has_method("hall_lamp_centers") or not exhibit.has_method("hall_lamp_fixture_rects"):
		_assert(false, "%s lighting draws one fixture per lamp" % label)
		return
	var lamps: PackedVector2Array = exhibit.call("hall_lamp_centers")
	var fixtures: Array = exhibit.call("hall_lamp_fixture_rects")
	_assert(lamps.size() > index, "%s has one lamp center" % label)
	_assert(fixtures.size() == lamps.size(), "%s has one fixture rect per lamp, not a second object" % label)
	if lamps.size() <= index or fixtures.size() <= index:
		return
	var fixture: Rect2 = fixtures[index]
	_assert(fixture.get_center().is_equal_approx(lamps[index]), "%s fixture sits on its lamp center" % label)
	if exhibit.has_method("hall_lamp_discs"):
		var discs: Array = exhibit.call("hall_lamp_discs")
		_assert(discs.size() == lamps.size(), "%s has one halo per lamp" % label)
		if discs.size() > index:
			_assert((discs[index] as Rect2).get_center().is_equal_approx(lamps[index]), "%s halo shares the sconce center" % label)
	if exhibit.has_method("hall_lamp_pools"):
		var pools: Array = exhibit.call("hall_lamp_pools")
		_assert(pools.size() == lamps.size(), "%s lists one wash per lamp, not a separate pool-center list" % label)
		if pools.size() > index:
			_assert((pools[index] as Rect2).get_center().is_equal_approx(lamps[index]), "%s wash is attached to the sconce, not a floor disc" % label)


func _assert_visible_fixture(exhibit: Node2D, index: int, label: String) -> void:
	if not exhibit.has_method("hall_lamp_fixture_rects"):
		_assert(false, "%s lighting draws a glanceable fixture" % label)
		return
	var fixtures: Array = exhibit.call("hall_lamp_fixture_rects")
	_assert(fixtures.size() > index, "%s has a lamp body" % label)
	if fixtures.size() <= index:
		return
	var fixture: Rect2 = fixtures[index]
	_assert(fixture.size.x >= 12.0 and fixture.size.y >= 8.0, "%s lamp body is still visible" % label)
	_assert(fixture.size.x <= 22.0 and fixture.size.y <= 14.0, "%s lamp body stays a modest fixture" % label)
	_assert(_is_edge_lamp(fixture.get_center()), "%s lamp body sits on a hall edge" % label)
	if index == 0:
		_assert(fixture.position.y < NORTH_VIEW_Y, "%s T. rex bay sconce sits in the default north view" % label)
	var feat: Rect2 = exhibit.call("hall_board_featured_rect")
	var t_rex: Rect2 = exhibit.stand_rect("t_rex")
	_assert(not feat.intersects(fixture), "%s lamp body stays off the Featured name" % label)
	_assert(not t_rex.intersects(fixture), "%s lamp body stays off the T. rex silhouette" % label)
	_assert(not t_rex.has_point(fixture.get_center()), "%s fixture is not on the T. rex stand center" % label)
	_assert_one_lamp_object(exhibit, index, label)


func _has_point(points: PackedVector2Array, want: Vector2) -> bool:
	for point in points:
		if point == want:
			return true
	return false


func _is_edge_lamp(p: Vector2) -> bool:
	return p.x <= WEST_WALL_X or p.x >= EAST_WALL_X or p.y <= NORTH_WALL_Y or p.y >= SOUTH_WALL_Y


func _on_aisle_gather(p: Vector2) -> bool:
	return p.x >= AISLE.position.x and p.x <= AISLE.end.x


func _assert_lamps_off_featured_and_t_rex(exhibit: Node2D, lamps: PackedVector2Array) -> void:
	var feat: Rect2 = exhibit.call("hall_board_featured_rect")
	var t_rex: Rect2 = exhibit.stand_rect("t_rex")
	var t_rex_center: Vector2 = t_rex.get_center()
	for lamp in lamps:
		_assert(not feat.has_point(lamp), "lamp at %s stays off the Featured name" % lamp)
		_assert(not t_rex.has_point(lamp), "lamp at %s stays off the T. rex stand" % lamp)
		_assert(lamp.distance_to(t_rex_center) > 80.0, "lamp at %s is not on the T. rex stand center" % lamp)


func _in_north_view(prop: Rect2) -> bool:
	if prop.size == Vector2.ZERO:
		return false
	if prop.position.y < NORTH_VIEW_Y:
		return true
	return BOARD.intersects(prop)


func _overlaps_stand_or_gather(exhibit: Node2D, prop: Rect2) -> bool:
	for stand_id in exhibit.STAND_LAYOUT:
		if exhibit.stand_rect(str(stand_id)).intersects(prop):
			return true
	return _overlaps_gather_slots(exhibit, prop)


func _overlaps_gather_slots(exhibit: Node2D, prop: Rect2) -> bool:
	if not exhibit.has_method("gather_slots"):
		return false
	for stand_id in exhibit.STAND_LAYOUT:
		for slot in exhibit.call("gather_slots", str(stand_id)):
			if prop.has_point(slot):
				return true
	return false


func _prop_name(prop: Rect2, exhibit: Node2D) -> String:
	if exhibit.has_method("hall_gift_rect") and prop == exhibit.call("hall_gift_rect"):
		return "gift kiosk"
	if exhibit.has_method("hall_gift_south_rect") and prop == exhibit.call("hall_gift_south_rect"):
		return "south gift counter"
	if exhibit.has_method("hall_opening_bunting_rect") and prop == exhibit.call("hall_opening_bunting_rect"):
		return "opening bunting"
	return "amenity"


func _assert(ok: bool, label: String) -> void:
	if ok:
		_passed += 1
		print("PASS  %s" % label)
	else:
		_failed += 1
		print("FAIL  %s" % label)
