extends SceneTree

## Visitors cause exhibit $/sec. Bones attract, amenities raise donation, crowds add people.
## Run: godot --headless --path <project> -s res://tests/test_museum_visitors.gd

var _failed: int = 0
var _passed: int = 0
var GS: Node
var TN: Node


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	GS = root.get_node("GameState")
	TN = root.get_node("Tuning")
	_test_empty_hall_has_no_crowd()
	_test_mounted_bone_attracts_visitors_and_pays_ticket()
	_test_comfort_upgrades_raise_donation()
	_test_crowd_upgrades_raise_headcount()
	_test_spotlight_multiplies_featured_draw()
	_test_unveil_is_a_visitor_surge_not_cash()
	_test_unveil_plus_n_walkers_enter_from_the_south()
	_test_packed_hall_unveil_still_adds_one_walker_per_announced_visitor()
	_test_unveil_crowd_rank_scales_incoming_walkers()
	_test_header_names_visitors_and_donation()
	_test_walkers_pack_after_a_crowd()
	_test_gather_pads_stay_off_the_stands()
	_test_viewing_slots_spread_around_the_stand()
	_test_crowd_spreads_instead_of_stacking()
	_test_visitors_enter_from_the_south_and_stay_off_mounts()
	_test_richer_stands_hold_visitors_longer()
	_test_each_stand_shows_its_own_rate()
	_test_spotlight_raises_the_featured_stand_rate()
	print("museum_visitors %d passed, %d failed" % [_passed, _failed])
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


func _test_empty_hall_has_no_crowd() -> void:
	_reset()
	_assert(GS.has_method("museum_visitors"), "GameState exposes museum_visitors")
	if not GS.has_method("museum_visitors"):
		return
	_assert(int(GS.call("museum_visitors")) == 0, "empty hall has 0 visitors")
	_assert(is_equal_approx(float(GS.museum_income()), 0.0), "empty hall pays $0/sec")


func _test_mounted_bone_attracts_visitors_and_pays_ticket() -> void:
	_reset()
	if not GS.has_method("museum_visitors") or not GS.has_method("museum_donation"):
		_assert(false, "visitors and donation exist")
		return
	GS.install_find("tooth", "Tooth", 1.0, true)
	var visitors: int = int(GS.call("museum_visitors"))
	var donation: float = float(GS.call("museum_donation"))
	_assert(visitors > 0, "a mounted tooth attracts visitors")
	_assert(donation > 0.0, "each visitor leaves a donation")
	_assert(is_equal_approx(float(GS.museum_income()), float(visitors) * donation), "income is visitors times donation")


func _test_comfort_upgrades_raise_donation() -> void:
	_reset()
	if not GS.has_method("museum_donation"):
		_assert(false, "donation exists")
		return
	GS.install_find("tooth", "Tooth", 1.0, true)
	var before: float = float(GS.call("museum_donation"))
	var before_visitors: int = int(GS.call("museum_visitors"))
	GS.levels["lighting"] = 1
	GS.levels["benches"] = 1
	GS.levels["labels"] = 1
	GS.levels["gift_shop"] = 1
	GS.apply_upgrades()
	_assert(float(GS.call("museum_donation")) > before + 0.0001, "lights, benches, labels, and gifts raise donation")
	_assert(int(GS.call("museum_visitors")) == before_visitors, "comfort upgrades do not add people")
	_assert(str(GS.shop_effect_line("lighting")).find("per visitor") >= 0, "Warm Lights shop line is donation per visitor")
	_assert(str(GS.shop_effect_line("benches")).find("per visitor") >= 0, "Benches shop line is donation per visitor")


func _test_crowd_upgrades_raise_headcount() -> void:
	_reset()
	if not GS.has_method("museum_visitors"):
		_assert(false, "visitors exist")
		return
	GS.install_find("tooth", "Tooth", 1.0, true)
	var before: int = int(GS.call("museum_visitors"))
	var before_donation: float = float(GS.call("museum_donation"))
	GS.levels["glass_case"] = 1
	GS.levels["crowds"] = 1
	GS.apply_upgrades()
	_assert(int(GS.call("museum_visitors")) > before, "Glass Case and Weekend Crowds add visitors")
	_assert(is_equal_approx(float(GS.call("museum_donation")), before_donation), "crowd upgrades do not raise the ticket")
	_assert(str(GS.shop_effect_line("glass_case")).find("visitor") >= 0, "Glass Case shop line is visitors")
	_assert(str(GS.shop_effect_line("crowds")).find("visitor") >= 0, "Weekend Crowds shop line is visitors")


func _test_spotlight_multiplies_featured_draw() -> void:
	_reset()
	if not GS.has_method("museum_visitors"):
		_assert(false, "visitors exist")
		return
	GS.install_find("triceratops_skull", "Triceratops Skull", 1.0, true)
	GS.install_find("tooth", "Tooth", 1.0, true)
	GS.unveil_spike_left = 0.0
	var base: int = int(GS.call("museum_visitors"))
	GS.levels["spotlight"] = 1
	GS.apply_upgrades()
	GS.set_featured_stand("triceratops")
	_assert(int(GS.call("museum_visitors")) > base, "featured stand draws extra visitors")
	_assert(is_equal_approx(float(GS.museum_income()), float(GS.call("museum_visitors")) * float(GS.call("museum_donation"))), "featured income still visitors times donation")


func _test_unveil_is_a_visitor_surge_not_cash() -> void:
	_reset()
	if not GS.has_method("museum_visitors"):
		_assert(false, "visitors exist")
		return
	GS.install_find("triceratops_skull", "Triceratops Skull", 1.0, true)
	var before: int = int(GS.call("museum_visitors"))
	var paid: int = int(GS.unveil_stand("triceratops"))
	_assert(paid == 0, "unveil does not drop a cash burst")
	_assert(int(GS.money) == 0, "the bank does not pop on unveil")
	_assert(int(GS.call("museum_visitors")) > before, "unveil packs extra visitors")
	_assert(float(GS.museum_income()) > float(before) * float(GS.call("museum_donation")), "the packed hall pays more each second")
	var line: String = str(GS.call("unveil_rush_line")) if GS.has_method("unveil_rush_line") else ""
	_assert(line.find("visitor") >= 0, "surge copy names visitors")
	_assert(line.find("s") >= 0, "surge copy keeps the timer")
	GS._process(float(GS.unveil_spike_left) + 0.05)
	_assert(int(GS.call("museum_visitors")) == before, "the extra crowd drains back")


func _pack_weekend_crowd() -> void:
	for _i in 8:
		GS.install_find("tooth", "Tooth", 1.0, true)
	GS.levels["crowds"] = 6
	GS.apply_upgrades()


func _incoming_at_door(exhibit: Node2D, before_count: int) -> int:
	var door: Vector2 = exhibit.call("south_door")
	var spots: PackedVector2Array = exhibit.call("visitor_positions")
	var incoming: int = 0
	for i in range(before_count, spots.size()):
		if spots[i].distance_to(door) < 40.0:
			incoming += 1
	return incoming


func _test_unveil_plus_n_walkers_enter_from_the_south() -> void:
	_reset()
	GS.install_find("triceratops_skull", "Triceratops Skull", 1.0, true)
	var exhibit: Node2D = _make_exhibit()
	var before_sprites: int = int(exhibit.call("visitor_sprite_count"))
	var mus: Node = (load("res://museum.gd") as GDScript).new()
	root.add_child(mus)
	mus.visible = true
	mus._unveil_stand("triceratops")
	var extra: int = int(GS.call("surge_visitors"))
	var banner: String = str(mus._banner.text)
	_assert(extra == 8, "a first unveil reports +8 visitors")
	_assert(banner.find("+8 visitors") >= 0, "the toast names those +8 visitors")
	_assert(int(GS.call("visitor_sprite_count")) == before_sprites + extra, "walker count rises by the announced +N")
	_assert(int(exhibit.call("visitor_sprite_count")) == before_sprites + extra, "the hall draws one new person per announced visitor")
	_assert(_incoming_at_door(exhibit, before_sprites) == extra, "those +N people start at the south door")
	mus.free()
	exhibit.free()


func _test_packed_hall_unveil_still_adds_one_walker_per_announced_visitor() -> void:
	_reset()
	GS.install_find("triceratops_skull", "Triceratops Skull", 1.0, true)
	_pack_weekend_crowd()
	var visitors: int = int(GS.call("museum_visitors"))
	var before_sprites: int = int(GS.call("visitor_sprite_count"))
	_assert(visitors > 24, "weekend crowds coarsen the packed hall")
	_assert(before_sprites < visitors, "packed hall uses fewer sprites than people")
	var exhibit: Node2D = _make_exhibit()
	var hall_before: int = int(exhibit.call("visitor_sprite_count"))
	GS.unveil_stand("triceratops")
	var extra: int = int(GS.call("surge_visitors"))
	var line: String = str(GS.call("unveil_rush_line"))
	_assert(extra == 8, "the packed unveil still announces +8 visitors")
	_assert(line.find("+8 visitors") >= 0, "the rush line shows +8 visitors")
	_assert(int(GS.call("visitor_sprite_count")) == before_sprites + extra, "coarsening does not hide the +8 rush")
	_assert(int(exhibit.call("visitor_sprite_count")) == hall_before + extra, "the hall adds 8 walkers for +8 visitors")
	_assert(_incoming_at_door(exhibit, hall_before) == extra, "the rush walks in from the south door")
	exhibit.free()


func _test_unveil_crowd_rank_scales_incoming_walkers() -> void:
	_reset()
	GS.install_find("triceratops_skull", "Triceratops Skull", 1.0, true)
	_pack_weekend_crowd()
	GS.levels["unveil_crowd"] = 1
	GS.apply_upgrades()
	var before_sprites: int = int(GS.call("visitor_sprite_count"))
	var exhibit: Node2D = _make_exhibit()
	var hall_before: int = int(exhibit.call("visitor_sprite_count"))
	GS.unveil_stand("triceratops")
	var extra: int = int(GS.call("surge_visitors"))
	_assert(extra == 10, "Opening Crowd rank 1 announces +10 visitors")
	_assert(str(GS.call("unveil_rush_line")).find("+10 visitors") >= 0, "the rush line shows the ranked +10")
	_assert(int(GS.call("visitor_sprite_count")) == before_sprites + extra, "rank 1 rush adds 10 walkers")
	_assert(_incoming_at_door(exhibit, hall_before) == extra, "the ranked rush enters from the south")
	exhibit.free()
	_reset()
	GS.install_find("t_rex_tooth", "T. rex Tooth", 1.0, true)
	_pack_weekend_crowd()
	GS.levels["unveil_crowd"] = 4
	GS.apply_upgrades()
	before_sprites = int(GS.call("visitor_sprite_count"))
	exhibit = _make_exhibit()
	hall_before = int(exhibit.call("visitor_sprite_count"))
	GS.unveil_stand("t_rex")
	extra = int(GS.call("surge_visitors"))
	_assert(extra == 16, "Opening Crowd rank 4 announces +16 visitors")
	_assert(int(GS.call("visitor_sprite_count")) == before_sprites + extra, "rank 4 rush adds 16 walkers")
	_assert(_incoming_at_door(exhibit, hall_before) == extra, "the bigger rush still walks in from the south")
	exhibit.free()


func _test_header_names_visitors_and_donation() -> void:
	_reset()
	GS.install_find("tooth", "Tooth", 1.0, true)
	var mus: Node = (load("res://museum.gd") as GDScript).new()
	root.add_child(mus)
	mus.visible = true
	if mus.has_method("_refresh"):
		mus.call("_refresh")
	var stats: Dictionary = {}
	if mus.has_method("header_stats"):
		stats = mus.call("header_stats")
	_assert(str(stats.get("visitors_label", "")) == "visitors", "the header names the visitor count")
	_assert(str(stats.get("each_label", "")) == "each", "the header names the donation")
	_assert(str(stats.get("rate_label", "")) == "/ sec", "the header still shows / sec")
	var visitors: Label = mus.get("_visitors") as Label
	var each: Label = mus.get("_each") as Label
	var rate: Label = mus.get("_rate") as Label
	_assert(visitors != null and visitors.visible, "visitor count is a header label")
	_assert(each != null and each.visible, "donation is a header label")
	_assert(rate != null and rate.visible, "hall rate is a header label")
	mus.free()


func _test_walkers_pack_after_a_crowd() -> void:
	_reset()
	_assert(GS.has_method("visitor_sprite_count"), "GameState exposes walker count")
	if not GS.has_method("visitor_sprite_count"):
		return
	_assert(int(GS.call("visitor_sprite_count")) == 0, "no walkers in an empty hall")
	for _i in 8:
		GS.install_find("tooth", "Tooth", 1.0, true)
	var visitors: int = int(GS.call("museum_visitors"))
	var sprites: int = int(GS.call("visitor_sprite_count"))
	_assert(sprites == visitors, "early crowd is one walker per visitor")
	GS.levels["crowds"] = 6
	GS.apply_upgrades()
	visitors = int(GS.call("museum_visitors"))
	sprites = int(GS.call("visitor_sprite_count"))
	_assert(visitors > 24, "weekend crowds can pass two dozen people")
	_assert(sprites < visitors, "packed hall coarsens walkers")
	_assert(sprites <= 48, "walker sprites stay capped")
	var exhibit: Node2D = Node2D.new()
	exhibit.set_script(load("res://museum_exhibit.gd"))
	root.add_child(exhibit)
	_assert(exhibit.has_method("visitor_sprite_count"), "the hall can draw the packed walkers")
	if exhibit.has_method("visitor_sprite_count"):
		_assert(int(exhibit.call("visitor_sprite_count")) == sprites, "hall walkers match the visitor number")
	exhibit.free()


func _make_exhibit() -> Node2D:
	var exhibit: Node2D = Node2D.new()
	exhibit.set_script(load("res://museum_exhibit.gd"))
	root.add_child(exhibit)
	return exhibit


func _test_gather_pads_stay_off_the_stands() -> void:
	var exhibit: Node2D = _make_exhibit()
	_assert(exhibit.has_method("gather_pad"), "hall exposes an aisle-face gather pad")
	_assert(exhibit.has_method("south_door"), "hall exposes the south door")
	if not exhibit.has_method("gather_pad") or not exhibit.has_method("south_door"):
		exhibit.free()
		return
	var door: Vector2 = exhibit.call("south_door")
	_assert(door.x > 920.0 and door.x < 1080.0, "south door sits on the runner")
	_assert(door.y > 1400.0, "south door is at the bottom of the hall")
	for stand_id in exhibit.STAND_LAYOUT:
		var stand: Rect2 = exhibit.stand_rect(str(stand_id))
		var pad: Vector2 = exhibit.call("gather_pad", str(stand_id))
		_assert(not stand.has_point(pad), "%s gather pad stays off the mount" % str(stand_id))
		_assert(pad.y >= stand.end.y - 0.5, "%s gather pad is on the plaque / aisle face" % str(stand_id))
	exhibit.free()


func _test_viewing_slots_spread_around_the_stand() -> void:
	var exhibit: Node2D = _make_exhibit()
	_assert(exhibit.has_method("gather_slots"), "each stand has a ring of viewing spots")
	if not exhibit.has_method("gather_slots"):
		exhibit.free()
		return
	for stand_id in ["t_rex", "triceratops", "brachiosaurus"]:
		var stand: Rect2 = exhibit.stand_rect(stand_id)
		var slots: PackedVector2Array = exhibit.call("gather_slots", stand_id)
		_assert(slots.size() >= 8, "%s has a crowd-sized viewing apron" % stand_id)
		var min_x: float = 9999.0
		var max_x: float = -9999.0
		var min_y: float = 9999.0
		var max_y: float = -9999.0
		for slot in slots:
			_assert(not stand.has_point(slot), "%s viewing spot stays off the mount" % stand_id)
			min_x = minf(min_x, slot.x)
			max_x = maxf(max_x, slot.x)
			min_y = minf(min_y, slot.y)
			max_y = maxf(max_y, slot.y)
		_assert(max_x - min_x > 80.0 or max_y - min_y > 80.0, "%s viewing spots spread around the stand" % stand_id)
	var first: Vector2 = exhibit.call("gather_pad", "triceratops", 0)
	var second: Vector2 = exhibit.call("gather_pad", "triceratops", 1)
	_assert(first.distance_to(second) > 20.0, "two viewers do not share one slot")
	exhibit.free()


func _test_crowd_spreads_instead_of_stacking() -> void:
	_reset()
	GS.install_find("triceratops_skull", "Triceratops Skull", 1.0, true)
	GS.levels["crowds"] = 4
	GS.apply_upgrades()
	var exhibit: Node2D = _make_exhibit()
	if not exhibit.has_method("visitor_positions"):
		_assert(false, "hall can place a spread-out crowd")
		exhibit.free()
		return
	for _i in 50:
		exhibit.tick(0.2)
	var stand: Rect2 = exhibit.stand_rect("triceratops")
	var apron: Rect2 = stand.grow(70.0)
	var xs: Array = []
	var ys: Array = []
	for pos in exhibit.call("visitor_positions"):
		if not apron.has_point(pos):
			continue
		if stand.has_point(pos):
			continue
		xs.append(pos.x)
		ys.append(pos.y)
	_assert(xs.size() >= 3, "several visitors gather at the stand")
	if xs.size() >= 3:
		xs.sort()
		ys.sort()
		var span: float = maxf(float(xs[xs.size() - 1]) - float(xs[0]), float(ys[ys.size() - 1]) - float(ys[0]))
		_assert(span > 80.0, "the crowd fans out around the exhibit, not one slot")
	exhibit.free()


func _test_visitors_enter_from_the_south_and_stay_off_mounts() -> void:
	_reset()
	GS.install_find("triceratops_skull", "Triceratops Skull", 1.0, true)
	GS.install_find("tooth", "Tooth", 1.0, true)
	var exhibit: Node2D = _make_exhibit()
	_assert(exhibit.has_method("visitor_positions"), "hall exposes walker positions")
	if not exhibit.has_method("visitor_positions"):
		exhibit.free()
		return
	var start: PackedVector2Array = exhibit.call("visitor_positions")
	_assert(not start.is_empty(), "a crowd has walkers to place")
	if not start.is_empty():
		_assert(start[0].y > 1300.0, "walkers enter from the south")
	var clipped: String = ""
	for _i in 80:
		exhibit.tick(0.25)
		var spots: PackedVector2Array = exhibit.call("visitor_positions")
		for pos in spots:
			for stand_id in exhibit.STAND_LAYOUT:
				if exhibit.stand_rect(str(stand_id)).has_point(pos):
					clipped = "%s at (%.0f, %.0f)" % [str(stand_id), pos.x, pos.y]
					break
			if clipped != "":
				break
		if clipped != "":
			break
	_assert(clipped == "", "walkers stay off the mounts" if clipped == "" else "walkers stay off the mounts (%s)" % clipped)
	exhibit.free()


func _test_richer_stands_hold_visitors_longer() -> void:
	_reset()
	var exhibit: Node2D = _make_exhibit()
	_assert(exhibit.has_method("dwell_seconds"), "hall exposes dwell time")
	if not exhibit.has_method("dwell_seconds"):
		exhibit.free()
		return
	GS.install_find("triceratops_tooth", "Triceratops Tooth", 1.0, true)
	var sparse: float = float(exhibit.call("dwell_seconds", "triceratops"))
	GS.install_find("triceratops_vertebra", "Triceratops Vertebra", 1.0, true)
	GS.install_find("triceratops_skull", "Triceratops Skull", 1.0, true)
	GS.install_find("triceratops_hind_limb", "Triceratops Hind Limb", 1.0, true)
	GS.install_find("triceratops_tail", "Triceratops Tail", 1.0, true)
	var richer: float = float(exhibit.call("dwell_seconds", "triceratops"))
	_assert(sparse >= 1.5 and sparse <= 3.5, "a thin mount is a short look")
	_assert(richer > sparse + 1.5, "a fuller mount holds the crowd longer")
	exhibit.free()


func _test_each_stand_shows_its_own_rate() -> void:
	_reset()
	GS.install_find("triceratops_skull", "Triceratops Skull", 1.0, true)
	GS.install_find("tooth", "Tooth", 1.0, true)
	var exhibit: Node2D = _make_exhibit()
	_assert(exhibit.has_method("stand_rate_line"), "each stand can name its $/sec")
	_assert(exhibit.has_method("stand_rate_rect"), "the rate sits on the stand")
	if not exhibit.has_method("stand_rate_line") or not exhibit.has_method("stand_rate_rect"):
		exhibit.free()
		return
	var trike: String = str(exhibit.call("stand_rate_line", "triceratops"))
	var scraps: String = str(exhibit.call("stand_rate_line", "small_finds"))
	_assert(trike.find("$") >= 0 and trike.find("/ sec") >= 0, "Triceratops rate is $ / sec")
	_assert(scraps.find("$") >= 0 and scraps.find("/ sec") >= 0, "Small Finds rate is $ / sec")
	_assert(trike != scraps, "stands show their own rate, not one shared number")
	var stand: Rect2 = exhibit.stand_rect("triceratops")
	var chip: Rect2 = exhibit.call("stand_rate_rect", "triceratops")
	var plaque: Rect2 = exhibit.plaque_rect("triceratops")
	_assert(chip.position.x > stand.get_center().x, "rate chip sits on the right")
	_assert(chip.position.y < stand.position.y + 36.0, "rate chip sits at the top")
	_assert(not chip.intersects(plaque), "rate chip does not cover the plaque")
	exhibit.free()


func _test_spotlight_raises_the_featured_stand_rate() -> void:
	_reset()
	GS.install_find("triceratops_skull", "Triceratops Skull", 1.0, true)
	var exhibit: Node2D = _make_exhibit()
	if not exhibit.has_method("stand_rate_line"):
		_assert(false, "stand rate exists for the 4x upgrade")
		exhibit.free()
		return
	var before: String = str(exhibit.call("stand_rate_line", "triceratops"))
	GS.levels["spotlight"] = 3
	GS.apply_upgrades()
	GS.set_featured_stand("triceratops")
	var after: String = str(exhibit.call("stand_rate_line", "triceratops"))
	_assert(float(GS.stand_income("triceratops")) > float(GS.piece_income("triceratops_skull")) * 3.5, "rank 3 featured stand is 4x")
	_assert(after != before, "the stand chip updates when the exhibit is featured")
	_assert(after.find("$") >= 0 and after.find("/ sec") >= 0, "featured rate stays $ / sec")
	exhibit.free()


func _assert(ok: bool, label: String) -> void:
	if ok:
		_passed += 1
		print("PASS  %s" % label)
	else:
		_failed += 1
		print("FAIL  %s" % label)
