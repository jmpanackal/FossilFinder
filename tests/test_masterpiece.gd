extends SceneTree

## Repair Workshop fixes bones on display after shifts (up to Great);
## a complete stand with every bone Great+ becomes a Masterpiece.
## Run: godot --headless --path <project> -s res://tests/test_masterpiece.gd

var _failed: int = 0
var _passed: int = 0
var GS: Node
var TN: Node
var _masters: Array = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	GS = root.get_node("GameState")
	TN = root.get_node("Tuning")
	GS.masterpiece_completed.connect(func(stand_id: String, bonus: int) -> void: _masters.append([stand_id, bonus]))
	_test_workshop_needs_the_upgrade()
	_test_workshop_repairs_the_weakest_bone()
	_test_workshop_never_passes_great()
	_test_workshop_ranks_repair_more()
	await _test_masterpiece_needs_complete_and_great()
	await _test_workshop_can_finish_a_masterpiece()
	_reset()
	print("masterpiece %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _reset() -> void:
	GS.pieces.clear()
	GS.pending_unveils.clear()
	GS.featured_stand_id = ""
	GS.money = 0
	for item in GS.catalog:
		GS.levels[item["id"]] = 0
	GS.apply_upgrades()
	_masters.clear()


func _fill_stand(stand: String, condition: int) -> void:
	for id in GS.stand_piece_ids(stand):
		while bool(GS.piece_needs_more(id)):
			GS.install_find(id, id, 1.0, true, condition)


func _test_workshop_needs_the_upgrade() -> void:
	_reset()
	GS.install_find("t_rex_skull", "T. rex Skull", 1.0, true, 1)
	_assert(GS.run_workshop().is_empty(), "no repairs without the Repair Workshop")
	_assert(int(GS.piece_condition("t_rex_skull")) == 1, "the bone stays Poor")


func _test_workshop_repairs_the_weakest_bone() -> void:
	_reset()
	GS.levels["workshop"] = 1
	GS.apply_upgrades()
	GS.install_find("t_rex_skull", "T. rex Skull", 1.0, true, 3)
	GS.install_find("t_rex_jaw", "T. rex Jaw", 1.0, true, 1)
	var repairs: Array = GS.run_workshop()
	_assert(repairs.size() == 1, "rank 1 repairs one bone per shift")
	_assert(str(repairs[0]["piece_id"]) == "t_rex_jaw", "the weakest bone is repaired first")
	_assert(int(GS.piece_condition("t_rex_jaw")) == 2, "it gains one star")
	_assert(int(GS.piece_condition("t_rex_skull")) == 3, "other bones are untouched")


func _test_workshop_never_passes_great() -> void:
	_reset()
	GS.levels["workshop"] = 3
	GS.apply_upgrades()
	GS.install_find("t_rex_skull", "T. rex Skull", 1.0, true, 4)
	_assert(GS.run_workshop().is_empty(), "Great bones are left alone")
	_assert(int(GS.piece_condition("t_rex_skull")) == 4, "Perfect only comes from the ground")


func _test_workshop_ranks_repair_more() -> void:
	_reset()
	GS.levels["workshop"] = 3
	GS.apply_upgrades()
	GS.install_find("t_rex_skull", "T. rex Skull", 1.0, true, 1)
	var repairs: Array = GS.run_workshop()
	_assert(repairs.size() == 3, "rank 3 makes three repairs per shift")
	_assert(int(GS.piece_condition("t_rex_skull")) == 4, "one bone can climb several stars")
	_assert(str(GS.shop_effect_line("workshop")).contains("Repairs"), "shop line says what it repairs")


func _test_masterpiece_needs_complete_and_great() -> void:
	_reset()
	_fill_stand("velociraptor", 3)
	await process_frame
	_assert(bool(GS.stand_is_complete("velociraptor")), "stand is complete")
	_assert(not bool(GS.stand_is_masterpiece("velociraptor")), "Good bones are not a Masterpiece")
	_assert(_masters.is_empty(), "no masterpiece celebration yet")
	var plain: int = int(GS.stand_visitors("velociraptor"))
	for id in GS.stand_piece_ids("velociraptor"):
		GS.install_find(id, id, 1.0, true, 5)
	await process_frame
	_assert(bool(GS.stand_is_masterpiece("velociraptor")), "all Great+ makes a Masterpiece")
	_assert(_masters.size() == 1 and str(_masters[0][0]) == "velociraptor", "the Masterpiece is celebrated once")
	_assert(int(_masters[0][1]) > 0 if not _masters.is_empty() else false, "it pays a bonus")
	_assert(int(GS.stand_visitors("velociraptor")) > plain * 2, "a Masterpiece of Perfect bones draws far more")


func _test_workshop_can_finish_a_masterpiece() -> void:
	_reset()
	_fill_stand("velociraptor", 4)
	await process_frame
	_masters.clear()
	var ids: PackedStringArray = GS.stand_piece_ids("velociraptor")
	var piece: Dictionary = GS.pieces[ids[0]]
	piece["condition"] = 3
	GS.pieces[ids[0]] = piece
	_assert(not bool(GS.stand_is_masterpiece("velociraptor")), "one Good bone blocks the Masterpiece")
	GS.levels["workshop"] = 1
	GS.apply_upgrades()
	GS.run_workshop()
	_assert(bool(GS.stand_is_masterpiece("velociraptor")), "the workshop repair completes the Masterpiece")
	_assert(_masters.size() == 1, "and it is celebrated")


func _assert(ok: bool, label: String) -> void:
	if ok:
		_passed += 1
		print("PASS  %s" % label)
	else:
		_failed += 1
		print("FAIL  %s" % label)
