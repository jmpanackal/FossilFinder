extends SceneTree

## Spotlight + Unveiling with Small Finds on a side wall.
## Skull unveils on Triceratops. Tooth/vertebra unveil in the wall case.

var _failed: int = 0
var _passed: int = 0
var GS: Node
var TN: Node


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	GS = root.get_node("GameState")
	TN = root.get_node("Tuning")
	_test_empty_aisle_layout()
	_test_new_skull_is_pending_unveil()
	_test_scraps_mount_in_small_finds()
	_test_museum_click_unveils_then_spotlights()
	_test_museum_click_unveils_small_finds()
	_test_header_shows_featured_name_and_income()
	_test_header_names_a_mounted_tooth()
	_test_featured_small_finds_income_is_readable()
	_test_dusty_featured_case_header_is_not_zero()
	_test_old_save_piece_is_not_pending()
	_test_empty_stands_never_pending()
	_test_duplicate_does_not_reflag_after_unveil()
	_test_empty_stand_cannot_be_featured()
	_test_filled_stand_can_be_featured()
	_test_featuring_again_keeps_featured()
	_test_empty_stand_does_not_steal_spotlight()
	_test_spotlight_doubles_that_stand_only()
	_test_unveil_pays_and_clears_pending()
	_test_unveil_starts_income_spike()
	print("hall_spotlight %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _reset() -> void:
	GS.pieces.clear()
	GS.money = 0
	GS.featured_stand_id = ""
	GS.pending_unveils.clear()
	GS.unveil_spike_left = 0.0
	GS._income_accum = 0.0
	for item in GS.catalog:
		GS.levels[item["id"]] = 0
	GS.apply_upgrades()


func _test_empty_aisle_layout() -> void:
	var exhibit: Node2D = Node2D.new()
	exhibit.set_script(load("res://museum_exhibit.gd"))
	root.add_child(exhibit)
	var layout: Dictionary = exhibit.STAND_LAYOUT
	_assert(layout.size() == 6, "hall has six stands")
	_assert(layout.has("small_finds"), "Small Finds case exists")
	_assert(str(layout["small_finds"]["title"]) == "Small Finds", "case plaque says Small Finds")
	_assert(layout.has("t_rex") and layout.has("triceratops") and layout.has("velociraptor"), "far and left stands exist")
	_assert(layout.has("brachiosaurus") and layout.has("stegosaurus"), "right stands exist")
	_assert(str(layout["brachiosaurus"]["title"]) == "Brachiosaurus", "sauropod plaque says Brachiosaurus")
	var t_rex: Rect2 = exhibit.stand_rect("t_rex")
	var case_stand: Rect2 = exhibit.stand_rect("small_finds")
	var left_a: Rect2 = exhibit.stand_rect("triceratops")
	var left_b: Rect2 = exhibit.stand_rect("velociraptor")
	var right_a: Rect2 = exhibit.stand_rect("brachiosaurus")
	var right_b: Rect2 = exhibit.stand_rect("stegosaurus")
	_assert(t_rex.position.y < left_a.position.y and t_rex.position.y < right_a.position.y, "T. rex stands at the far end")
	_assert(left_a.position.x < 400.0 and left_b.position.x < 400.0, "Triceratops and Velociraptor stay left")
	_assert(right_a.position.x > 1400.0 and right_b.position.x > 1400.0, "Brachiosaurus and Stegosaurus stay right")
	_assert(case_stand.position.x < 400.0, "Small Finds sits on a side or end wall")
	_assert(case_stand.position.y < 480.0, "Small Finds is an end bay, not down the aisle")
	_assert(not case_stand.intersects(t_rex), "Small Finds does not cover T. rex")
	var aisle: Rect2 = Rect2(920.0, 500.0, 160.0, 900.0)
	_assert(not aisle.intersects(case_stand), "Small Finds leaves the aisle open")
	_assert(not aisle.intersects(left_a) and not aisle.intersects(left_b), "left stands leave the aisle open")
	_assert(not aisle.intersects(right_a) and not aisle.intersects(right_b), "right stands leave the aisle open")
	_assert(exhibit.stand_id_at(case_stand.get_center()) == "small_finds", "clicking the case hits Small Finds")
	exhibit.free()


func _test_museum_click_unveils_then_spotlights() -> void:
	_reset()
	GS.install_find("triceratops_skull", "Triceratops Skull", 1.0, true)
	var mus: Node = (load("res://museum.gd") as GDScript).new()
	root.add_child(mus)
	var pad_pos: Vector2 = _pad_pos_for_stand(mus, "triceratops")
	mus._click_hall(pad_pos)
	_assert(not GS.stand_has_pending_unveil("triceratops"), "click unveils the ribboned bay")
	_assert(int(GS.money) == int(TN.unveil_burst_clean), "click pays the cash burst")
	_assert(float(GS.unveil_spike_left) > 0.0, "click starts the income spike")
	mus._click_hall(pad_pos)
	_assert(str(GS.featured_stand_id) == "triceratops", "second click spotlights the filled stand")
	mus.free()


func _test_museum_click_unveils_small_finds() -> void:
	_reset()
	GS.install_find("tooth", "Tooth", 1.0, true)
	var mus: Node = (load("res://museum.gd") as GDScript).new()
	root.add_child(mus)
	var pad_pos: Vector2 = _pad_pos_for_stand(mus, "small_finds")
	mus._click_hall(pad_pos)
	_assert(not GS.stand_has_pending_unveil("small_finds"), "click unveils the ribboned case")
	_assert(int(GS.money) == int(TN.unveil_burst_clean), "click pays the cash burst")
	mus._click_hall(pad_pos)
	_assert(str(GS.featured_stand_id) == "small_finds", "second click spotlights the case")
	mus.free()


func _header_rate(line: String) -> float:
	var start: int = line.find("$")
	if start < 0:
		return -1.0
	var rest: String = line.substr(start + 1)
	var end: int = rest.find(" ")
	if end < 0:
		return float(rest)
	return float(rest.substr(0, end))


func _header_amount(line: String) -> String:
	var start: int = line.find("$")
	if start < 0:
		return ""
	var rest: String = line.substr(start + 1)
	var end: int = rest.find(" ")
	if end < 0:
		return rest
	return rest.substr(0, end)


func _test_featured_small_finds_income_is_readable() -> void:
	_reset()
	GS.install_find("tooth", "Tooth", 1.0, true)
	GS.install_find("vertebra", "Vertebra", 0.4, false)
	GS.unveil_stand("small_finds")
	GS.unveil_spike_left = 0.0
	var dusty: float = float(GS.piece_income("vertebra"))
	var clean: float = float(GS.piece_income("tooth"))
	_assert(dusty > 0.0, "dusty vertebra still pays")
	_assert(dusty < clean, "dusty scrap pays less than a clean scrap")
	var base: float = float(GS.museum_income())
	_assert(bool(GS.set_featured_stand("small_finds")), "Small Finds can take the light")
	var featured: float = float(GS.museum_income())
	_assert(is_equal_approx(featured, base * float(TN.spotlight_mult)), "spotlight doubles the case")
	_assert(featured >= 0.10, "featured Small Finds ticks at least ten cents a second")
	var mus: Node = (load("res://museum.gd") as GDScript).new()
	root.add_child(mus)
	mus.visible = true
	mus._refresh()
	var line: String = str(mus._income.text)
	_assert(line.find("$0.0 /") < 0, "header does not show $0.0 while the case earns")
	_assert(_header_rate(line) >= 0.10, "header prints the featured case rate")
	var cents: PackedStringArray = _header_amount(line).split(".")
	_assert(cents.size() == 2 and cents[1].length() == 2, "header shows hundredths so a live tick cannot hide")
	mus.free()


func _test_dusty_featured_case_header_is_not_zero() -> void:
	_reset()
	GS.install_find("tooth", "Tooth", 0.0, false)
	GS.install_find("vertebra", "Vertebra", 0.2, false)
	GS.unveil_stand("small_finds")
	GS.unveil_spike_left = 0.0
	GS.set_featured_stand("small_finds")
	_assert(float(GS.museum_income()) >= 0.10, "two dusty scraps featured still tick")
	var mus: Node = (load("res://museum.gd") as GDScript).new()
	root.add_child(mus)
	mus.visible = true
	mus._refresh()
	var line: String = str(mus._income.text)
	_assert(line.find("$0.0 /") < 0, "dusty featured header is not $0.0")
	_assert(_header_rate(line) >= 0.10, "dusty featured header still reads as a tick")
	mus.free()


func _test_header_names_a_mounted_tooth() -> void:
	_reset()
	GS.install_find("tooth", "Tooth", 0.0, false)
	GS.unveil_stand("small_finds")
	var mus: Node = (load("res://museum.gd") as GDScript).new()
	root.add_child(mus)
	mus.visible = true
	mus._refresh()
	_assert(str(mus._note.text).find("waiting") < 0, "a mounted tooth is not an empty hall")
	_assert(str(mus._note.text).find("dusty") >= 0, "header admits the tooth is dusty")
	mus.free()


func _test_header_shows_featured_name_and_income() -> void:
	_reset()
	GS.install_find("triceratops_skull", "Triceratops Skull", 1.0, true)
	GS.unveil_stand("triceratops")
	GS.set_featured_stand("triceratops")
	var mus: Node = (load("res://museum.gd") as GDScript).new()
	root.add_child(mus)
	mus.visible = true
	mus._refresh()
	_assert(str(mus._note.text).find("Triceratops") >= 0, "header names the featured stand")
	_assert(str(mus._income.text).find("$") >= 0, "header shows exhibit income")
	mus.free()


func _pad_pos_for_stand(mus: Node, stand_id: String) -> Vector2:
	var exhibit: Node2D = mus._canvas
	var stand: Rect2 = exhibit.stand_rect(stand_id)
	return stand.get_center() - Vector2(0.0, 68.0) + mus._pan


func _test_new_skull_is_pending_unveil() -> void:
	_reset()
	GS.install_find("triceratops_skull", "Triceratops Skull", 1.0, true)
	_assert(GS.stand_for_piece("triceratops_skull") == "triceratops", "skull maps to Triceratops bay")
	_assert(GS.stand_has_pending_unveil("triceratops"), "new skull waits under a ribbon")
	_assert(not GS.stand_has_pending_unveil("t_rex"), "other bays stay uncovered")


func _test_scraps_mount_in_small_finds() -> void:
	_reset()
	GS.install_find("tooth", "Tooth", 1.0, true)
	GS.install_find("vertebra", "Vertebra", 0.4, false)
	_assert(GS.stand_for_piece("tooth") == "small_finds", "tooth maps to the Small Finds case")
	_assert(GS.stand_for_piece("vertebra") == "small_finds", "vertebra maps to the Small Finds case")
	_assert(GS.stand_has_pending_unveil("small_finds"), "scraps raise a ribbon on the case")
	_assert(bool(GS.set_featured_stand("small_finds")), "filled Small Finds can be featured")
	_assert(float(GS.piece_income("tooth")) > 0.0, "tooth still earns")
	_assert(float(GS.piece_income("vertebra")) > 0.0, "vertebra still earns")


func _test_old_save_piece_is_not_pending() -> void:
	_reset()
	GS.pieces["triceratops_skull"] = {
		"name": "Triceratops Skull",
		"cleanliness": 1.0,
		"clean": true,
	}
	_assert(GS.stand_is_filled("triceratops"), "old skull still fills the bay")
	_assert(not GS.stand_has_pending_unveil("triceratops"), "old saves are not ribboned")


func _test_empty_stands_never_pending() -> void:
	_reset()
	_assert(not GS.stand_is_filled("t_rex"), "T. rex starts empty")
	_assert(not GS.stand_has_pending_unveil("t_rex"), "empty stands never have ribbons")
	_assert(not GS.stand_has_pending_unveil("brachiosaurus"), "empty sauropod has no ribbon")


func _test_duplicate_does_not_reflag_after_unveil() -> void:
	_reset()
	GS.install_find("triceratops_skull", "Triceratops Skull", 1.0, true)
	var burst: int = int(GS.unveil_stand("triceratops"))
	_assert(burst > 0, "first unveil pays")
	_assert(not GS.stand_has_pending_unveil("triceratops"), "ribbon is gone after unveil")
	var money_after: int = int(GS.money)
	GS.install_find("triceratops_skull", "Triceratops Skull", 1.0, true)
	_assert(not GS.stand_has_pending_unveil("triceratops"), "duplicate does not re-ribbon")
	_assert(int(GS.money) > money_after, "duplicate still sells")


func _test_empty_stand_cannot_be_featured() -> void:
	_reset()
	_assert(not bool(GS.set_featured_stand("t_rex")), "empty stand cannot be featured")
	_assert(str(GS.featured_stand_id) == "", "featured stays empty")


func _test_filled_stand_can_be_featured() -> void:
	_reset()
	GS.install_find("triceratops_skull", "Triceratops Skull", 1.0, true)
	_assert(bool(GS.set_featured_stand("triceratops")), "filled stand can be featured")
	_assert(str(GS.featured_stand_id) == "triceratops", "featured id is stored")


func _test_featuring_again_keeps_featured() -> void:
	_reset()
	GS.install_find("triceratops_skull", "Triceratops Skull", 1.0, true)
	GS.set_featured_stand("triceratops")
	_assert(bool(GS.set_featured_stand("triceratops")), "clicking featured again stays featured")
	_assert(str(GS.featured_stand_id) == "triceratops", "featured is not toggled off")


func _test_empty_stand_does_not_steal_spotlight() -> void:
	_reset()
	GS.install_find("triceratops_skull", "Triceratops Skull", 1.0, true)
	GS.set_featured_stand("triceratops")
	_assert(not bool(GS.set_featured_stand("velociraptor")), "empty aisle stands cannot take the light")
	_assert(str(GS.featured_stand_id) == "triceratops", "spotlight stays on the filled bay")


func _test_spotlight_doubles_that_stand_only() -> void:
	_reset()
	GS.install_find("triceratops_skull", "Triceratops Skull", 1.0, true)
	GS.install_find("tooth", "Tooth", 1.0, true)
	GS.unveil_spike_left = 0.0
	var base: float = float(GS.museum_income())
	var skull: float = float(GS.piece_income("triceratops_skull"))
	GS.set_featured_stand("triceratops")
	var featured: float = float(GS.museum_income())
	_assert(is_equal_approx(featured, base + skull), "spotlight adds one extra copy of that stand")
	_assert(is_equal_approx(float(GS.stand_income("triceratops")), skull * 2.0), "featured stand reads as 2x")


func _test_unveil_pays_and_clears_pending() -> void:
	_reset()
	GS.install_find("triceratops_skull", "Triceratops Skull", 1.0, true)
	var paid: int = int(GS.unveil_stand("triceratops"))
	_assert(paid == int(TN.unveil_burst_clean), "clean unveil pays the clean burst")
	_assert(int(GS.money) == paid, "burst comes from the same money bank")
	_assert(not GS.stand_has_pending_unveil("triceratops"), "pending flag is cleared")
	_assert(int(GS.unveil_stand("triceratops")) == 0, "second unveil pays nothing")


func _test_unveil_starts_income_spike() -> void:
	_reset()
	GS.install_find("triceratops_skull", "Triceratops Skull", 1.0, true)
	var base: float = float(GS.museum_income())
	GS.unveil_stand("triceratops")
	_assert(float(GS.unveil_spike_left) > 0.0, "unveil starts a short spike timer")
	_assert(
		is_equal_approx(float(GS.museum_income()), base * float(TN.unveil_spike_mult)),
		"income spikes during the rush"
	)
	GS._process(float(GS.unveil_spike_left) + 0.05)
	_assert(float(GS.unveil_spike_left) <= 0.0, "spike expires")
	_assert(is_equal_approx(float(GS.museum_income()), base), "rate returns to normal")


func _assert(ok: bool, label: String) -> void:
	if ok:
		_passed += 1
		print("PASS  %s" % label)
	else:
		_failed += 1
		print("FAIL  %s" % label)
