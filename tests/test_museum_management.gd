extends SceneTree

## Headless checks for Spotlight + Unveiling on GameState.
## Run: godot --headless --path <project> -s res://tests/test_museum_management.gd
## Locked design: skull → Triceratops; tooth/vertebra → Small Finds wall case.

var _failed: int = 0
var _passed: int = 0
var GS: Node
var TN: Node


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	GS = root.get_node("GameState")
	TN = root.get_node("Tuning")
	_test_new_skull_is_pending_unveil()
	_test_scraps_mount_in_small_finds()
	_test_amber_speck_never_becomes_an_exhibit()
	_test_every_extractable_has_a_stand()
	_test_old_save_piece_is_not_pending()
	_test_empty_stands_never_pending()
	_test_duplicate_does_not_reflag_after_unveil()
	_test_empty_stand_cannot_be_featured()
	_test_filled_stand_can_be_featured()
	_test_small_finds_can_take_spotlight()
	_test_empty_stand_does_not_steal_spotlight()
	_test_spotlight_does_not_multiply_without_ranks()
	_test_spotlight_rank_one_is_2x()
	_test_spotlight_rank_two_is_3x()
	_test_unveil_pays_and_clears_pending()
	_test_unveil_starts_income_spike()
	_test_unveil_rush_stacks_and_adds_time()
	_test_unveil_rush_caps_at_five_stacks()
	_test_exhibit_upgrades_lengthen_and_strengthen_rush()
	_test_scrap_unveil_pays_and_clears()
	await _test_exhibit_pays_while_the_hall_is_paused()
	print("museum_management %d passed, %d failed" % [_passed, _failed])
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
	_assert(GS.stand_is_filled("small_finds"), "the case is filled once a scrap is collected")
	_assert(GS.stand_has_pending_unveil("small_finds"), "new scraps wait under a ribbon")
	_assert(GS.has_any_pending_unveil(), "scraps raise a hall ribbon")
	_assert(bool(GS.set_featured_stand("small_finds")), "filled Small Finds can be featured")
	_assert(float(GS.piece_income("tooth")) > 0.0, "tooth still earns")
	_assert(float(GS.piece_income("vertebra")) > 0.0, "vertebra still earns")
	_assert(float(GS.piece_income("tooth")) < float(TN.piece_income_exhibit), "a tooth stays on scrap income")


func _test_amber_speck_never_becomes_an_exhibit() -> void:
	## A sifted agate chip is cash only. The Amber Insect exhibit has to be dug up.
	_reset()
	_assert(not GS.has_method("try_mount_matrix_find"), "sifted finds cannot claim a hall cell")
	_assert(not GS.has_piece("amber_insect"), "no Amber Insect without digging one up")
	var main_src: String = FileAccess.get_file_as_string("res://main.gd")
	_assert(main_src.find("try_mount_matrix_find") < 0, "layer juice no longer offers Amber to the hall")


func _test_every_extractable_has_a_stand() -> void:
	_reset()
	var skull: Resource = load("res://triceratops_skull.tres")
	_assert(skull != null, "skull resource exists")
	_assert(GS.stand_for_piece(str(skull.get("piece_id"))) == "triceratops", "skull stays in the Triceratops bay")
	for path in TN.extra_fossil_paths:
		var data: Resource = load(str(path))
		_assert(data != null, "%s loads" % str(path))
		var piece_id: String = str(data.get("piece_id"))
		_assert(not piece_id.is_empty(), "%s has a piece id" % str(path))
		_assert(GS.stand_for_piece(piece_id) == str(data.get("stand_id")), "%s mounts on its own case" % piece_id)
	_assert(GS.stand_for_piece("mystery_scrap") == "small_finds", "unknown extractables still get a case cell")
	_assert(GS.stand_title("small_finds") == "Small Finds", "case plaque is Small Finds")
	_assert(GS.stand_title("plant_fossils") == "Plant Fossils", "plant plaque is Plant Fossils")


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
	GS.unveil_stand("triceratops")
	_assert(int(GS.call("surge_visitors")) > 0, "first unveil packs a crowd")
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


func _test_small_finds_can_take_spotlight() -> void:
	_reset()
	GS.install_find("triceratops_skull", "Triceratops Skull", 1.0, true)
	GS.install_find("tooth", "Tooth", 1.0, true)
	GS.set_featured_stand("triceratops")
	_assert(bool(GS.set_featured_stand("small_finds")), "filled Small Finds can take the light")
	_assert(str(GS.featured_stand_id) == "small_finds", "spotlight moves to the case")


func _test_empty_stand_does_not_steal_spotlight() -> void:
	_reset()
	GS.install_find("triceratops_skull", "Triceratops Skull", 1.0, true)
	GS.set_featured_stand("triceratops")
	_assert(not bool(GS.set_featured_stand("velociraptor")), "empty aisle stands cannot take the light")
	_assert(str(GS.featured_stand_id) == "triceratops", "spotlight stays on the filled bay")


func _test_spotlight_does_not_multiply_without_ranks() -> void:
	_reset()
	GS.install_find("triceratops_skull", "Triceratops Skull", 1.0, true)
	GS.install_find("tooth", "Tooth", 1.0, true)
	GS.unveil_spike_left = 0.0
	var base: float = float(GS.museum_income())
	var skull: float = float(GS.piece_income("triceratops_skull"))
	GS.set_featured_stand("triceratops")
	var featured: float = float(GS.museum_income())
	_assert(is_equal_approx(featured, base), "0 ranks keep featured income at 1x")
	_assert(is_equal_approx(float(GS.stand_income("triceratops")), skull), "featured stand stays 1x until bought")


func _test_spotlight_rank_one_is_2x() -> void:
	_reset()
	GS.install_find("triceratops_skull", "Triceratops Skull", 1.0, true)
	GS.install_find("tooth", "Tooth", 1.0, true)
	GS.unveil_spike_left = 0.0
	var base: float = float(GS.museum_income())
	var skull: float = float(GS.piece_income("triceratops_skull"))
	_set_spotlight_rank(1)
	GS.set_featured_stand("triceratops")
	var featured: float = float(GS.museum_income())
	_assert(is_equal_approx(featured, base + skull), "rank 1 adds one extra copy of that stand")
	_assert(is_equal_approx(float(GS.stand_income("triceratops")), skull * 2.0), "rank 1 featured stand reads as 2x")
	_assert(is_equal_approx(float(GS.stand_income("small_finds")), float(GS.piece_income("tooth"))), "other stands stay 1x")


func _test_spotlight_rank_two_is_3x() -> void:
	_reset()
	GS.install_find("triceratops_skull", "Triceratops Skull", 1.0, true)
	GS.unveil_spike_left = 0.0
	var skull: float = float(GS.piece_income("triceratops_skull"))
	_set_spotlight_rank(2)
	GS.set_featured_stand("triceratops")
	_assert(is_equal_approx(float(GS.stand_income("triceratops")), skull * 3.0), "rank 2 featured stand reads as 3x")


func _set_spotlight_rank(rank: int) -> void:
	if GS._item("spotlight").is_empty():
		return
	GS.levels["spotlight"] = rank
	GS.apply_upgrades()


func _test_unveil_pays_and_clears_pending() -> void:
	_reset()
	GS.install_find("triceratops_skull", "Triceratops Skull", 1.0, true)
	var paid: int = int(GS.unveil_stand("triceratops"))
	_assert(paid == 0, "unveil does not drop a cash burst")
	_assert(int(GS.money) == 0, "the bank stays on the visitor tick")
	_assert(not GS.stand_has_pending_unveil("triceratops"), "pending flag is cleared")
	_assert(int(GS.unveil_stand("triceratops")) == 0, "second unveil pays nothing")


func _test_exhibit_pays_while_the_hall_is_paused() -> void:
	_reset()
	GS.install_find("triceratops_skull", "Triceratops Skull", 1.0, true)
	GS.unveil_stand("triceratops")
	GS.money = 0
	GS._income_accum = 0.0
	_assert(float(GS.museum_income()) > 0.0, "a mounted skull still shows a /sec rate")
	_assert(int(GS.process_mode) == Node.PROCESS_MODE_ALWAYS, "exhibit income keeps ticking while the hall pauses the clock")
	paused = true
	await create_timer(0.4, true, false, true).timeout
	_assert(float(GS._income_accum) > 0.0 or int(GS.money) > 0, "the bank still rises while the hall is open")
	paused = false


func _test_scrap_unveil_pays_and_clears() -> void:
	_reset()
	GS.install_find("tooth", "Tooth", 0.0, false)
	var paid: int = int(GS.unveil_stand("small_finds"))
	_assert(paid == 0, "dusty scrap unveil is a crowd surge")
	_assert(not GS.stand_has_pending_unveil("small_finds"), "case ribbon clears after unveil")
	_assert(int(GS.unveil_stand("small_finds")) == 0, "second case unveil pays nothing")


func _test_unveil_starts_income_spike() -> void:
	_reset()
	GS.install_find("triceratops_skull", "Triceratops Skull", 1.0, true)
	var base: float = float(GS.museum_income())
	GS.unveil_stand("triceratops")
	_assert(float(TN.unveil_spike_seconds) >= 20.0, "default rush lasts longer than the old 5s burst")
	_assert(float(GS.unveil_spike_left) >= 20.0, "unveil starts a 20s+ rush timer")
	_assert(_rush_stacks() == 1, "first unveil is one rush stack")
	var rush: float = _rush_rate()
	_assert(rush > 0.0, "unveil adds a $/sec rush")
	_assert(is_equal_approx(float(GS.museum_income()), base + rush), "income applies the rush $/sec")
	GS._process(float(GS.unveil_spike_left) + 0.05)
	_assert(float(GS.unveil_spike_left) <= 0.0, "spike expires")
	_assert(_rush_stacks() == 0, "expired rush clears stacks")
	_assert(is_equal_approx(float(GS.museum_income()), base), "rate returns to normal")


func _test_unveil_rush_stacks_and_adds_time() -> void:
	_reset()
	GS.install_find("triceratops_skull", "Triceratops Skull", 1.0, true)
	GS.unveil_stand("triceratops")
	var first_rate: float = _rush_rate()
	GS._process(4.0)
	var left_after: float = float(GS.unveil_spike_left)
	GS.install_find("t_rex_tail", "T. rex Tail", 1.0, true)
	GS.unveil_stand("t_rex")
	_assert(_rush_stacks() == 2, "second unveil adds a rush stack")
	var stacked: float = _rush_rate()
	_assert(is_equal_approx(stacked, first_rate * 2.0), "stacked rush is two copies of the same $/sec")
	_assert(float(GS.unveil_spike_left) > left_after + 10.0, "stacking adds duration")
	if GS.has_method("unveil_rush_line"):
		var line: String = str(GS.call("unveil_rush_line"))
		_assert(line.find("×2") >= 0 or line.find("x2") >= 0, "rush line shows the stack count")
		_assert(line.find("visitor") >= 0, "rush line shows the extra visitors")
		_assert(line.find("s") >= 0, "rush line shows the timer")


func _test_unveil_rush_caps_at_five_stacks() -> void:
	_reset()
	var ids: Array[String] = ["triceratops_skull", "t_rex_tail", "stegosaurus_plate", "velociraptor_claw", "brachiosaurus_tooth", "tooth"]
	var stands: Array[String] = ["triceratops", "t_rex", "stegosaurus", "velociraptor", "brachiosaurus", "small_finds"]
	var names: Array[String] = ["Triceratops Skull", "T. rex Tail", "Stegosaurus Plate", "Velociraptor Claw", "Brachiosaurus Tooth", "Tooth"]
	for i in ids.size():
		GS.install_find(ids[i], names[i], 1.0, true)
		GS.unveil_stand(stands[i])
	_assert(_rush_stacks() == 5, "rush stacks cap at 5")
	var capped: float = _rush_rate()
	GS.install_find("vertebra", "Vertebra", 1.0, true)
	GS.unveil_stand("small_finds")
	_assert(_rush_stacks() == 5, "a sixth unveil does not add a sixth stack")
	_assert(is_equal_approx(_rush_rate(), capped), "capped rush keeps the same $/sec")


func _test_exhibit_upgrades_lengthen_and_strengthen_rush() -> void:
	_reset()
	_assert(GS._item("unveil_time").is_empty() == false, "Opening Hours is a Museum upgrade")
	_assert(str(GS._item("unveil_time").get("cat", "")) == "Museum", "duration upgrade sits on the Museum tab")
	_assert(GS._item("unveil_crowd").is_empty() == false, "Opening Crowd is a Museum upgrade")
	_assert(str(GS._item("unveil_crowd").get("cat", "")) == "Museum", "strength upgrade sits on the Museum tab")
	var base_secs: float = float(TN.unveil_spike_seconds)
	GS.levels["unveil_time"] = 1
	GS.levels["unveil_crowd"] = 1
	GS.apply_upgrades()
	_assert(float(TN.unveil_spike_seconds) > base_secs, "Opening Hours lengthens the rush")
	## A small bone: a big one (a skull) now out-earns the fixed unveil surge alone.
	GS.install_find("triceratops_tail", "Triceratops Tail", 1.0, true)
	var base: float = _income_base()
	GS.unveil_stand("triceratops")
	var rush: float = _rush_rate()
	_assert(rush > base + 0.0001, "Opening Crowd makes the rush stronger than one copy of base income")
	_assert(float(GS.unveil_spike_left) > base_secs, "upgraded unveil uses the longer timer")


func _rush_stacks() -> int:
	if not ("unveil_rush_stacks" in GS):
		return 0
	return int(GS.unveil_rush_stacks)


func _rush_rate() -> float:
	if not GS.has_method("unveil_rush_rate"):
		return 0.0
	return float(GS.call("unveil_rush_rate"))


func _income_base() -> float:
	if GS.has_method("museum_income_base"):
		return float(GS.call("museum_income_base"))
	return float(GS.museum_income())


func _assert(ok: bool, label: String) -> void:
	if ok:
		_passed += 1
		print("PASS  %s" % label)
	else:
		_failed += 1
		print("FAIL  %s" % label)
