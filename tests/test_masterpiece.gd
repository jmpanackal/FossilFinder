extends SceneTree

## Repair Workshop fixes bones on display after shifts (up to Great);
## a complete stand with every bone Perfect becomes a Masterpiece.
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
	_test_region_condition_is_the_weakest_bone()
	_test_fame_scales_bone_value_with_income()
	_test_find_card_says_new_or_duplicate()
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
	_assert(bool(GS.stand_is_masterpiece("velociraptor")), "all Perfect makes a Masterpiece")
	_assert(_masters.size() == 1 and str(_masters[0][0]) == "velociraptor", "the Masterpiece is celebrated once")
	_assert(int(_masters[0][1]) > 0 if not _masters.is_empty() else false, "it pays a bonus")
	_assert(int(GS.stand_visitors("velociraptor")) > plain * 2, "a Masterpiece of Perfect bones draws far more")


func _test_workshop_can_finish_a_masterpiece() -> void:
	## Masterpieces need every bone Perfect; the workshop tops out at Great,
	## so it can't finish one on its own.
	_reset()
	_fill_stand("velociraptor", 5)
	await process_frame
	_assert(bool(GS.stand_is_masterpiece("velociraptor")), "all Perfect bones make a Masterpiece")
	_masters.clear()
	var ids: PackedStringArray = GS.stand_piece_ids("velociraptor")
	var piece: Dictionary = GS.pieces[ids[0]]
	piece["condition"] = 4
	GS.pieces[ids[0]] = piece
	_assert(not bool(GS.stand_is_masterpiece("velociraptor")), "one Great bone blocks the Masterpiece")
	GS.levels["workshop"] = 1
	GS.apply_upgrades()
	GS.run_workshop()
	_assert(not bool(GS.stand_is_masterpiece("velociraptor")), "the workshop cannot make a bone Perfect")
	var info: Dictionary = _exhibit_info("velociraptor")
	if not info.is_empty():
		_assert((info["bones"] as Array).size() == ids.size(), "the star card lists every bone")
		_assert(absf(float(info["avg"]) - (5.0 * float(ids.size() - 1) + 4.0) / float(ids.size())) < 0.01, "the star card shows the average")


func _exhibit_info(stand_id: String) -> Dictionary:
	var ex: Node = load("res://museum_exhibit.gd").new()
	var info: Dictionary = ex.call("stand_condition_info", stand_id)
	ex.free()
	return info


func _test_region_condition_is_the_weakest_bone() -> void:
	## The museum colors each part by its weakest bone, so stars have a visible cause.
	_reset()
	GS.install_find("t_rex_skull", "T. rex Skull", 1.0, true, 5)
	var region: String = str(GS.fossil_data_for("t_rex_skull").mount_region)
	_assert(int(GS.stand_region_condition("t_rex", region)) == 5, "a Perfect skull paints its region Perfect")
	for id in GS.stand_piece_ids("t_rex"):
		if id != "t_rex_skull" and str(GS.fossil_data_for(id).mount_region) == region:
			GS.install_find(id, id, 1.0, true, 1)
			_assert(int(GS.stand_region_condition("t_rex", region)) == 1, "a Poor bone in the same region shows as Poor")
			break
	var exhibit_script: GDScript = load("res://museum_exhibit.gd") as GDScript
	var exhibit: Node2D = exhibit_script.new()
	root.add_child(exhibit)
	_reset()
	GS.install_find("t_rex_skull", "T. rex Skull", 1.0, true, 2)
	_assert(str(exhibit.call("stand_condition_note", "t_rex")).contains("below Perfect"), "the stand says how many bones are below Perfect")
	exhibit.queue_free()


func _test_fame_scales_bone_value_with_income() -> void:
	_reset()
	_reset_fame_cache()
	_assert(is_equal_approx(float(GS.fame_mult()), 1.0), "an empty museum pays base price")
	for sid in ["t_rex", "triceratops", "velociraptor"]:
		_fill_stand(sid, 5)
	GS.fame_mult()
	var income: float = float(GS.museum_income_base())
	GS.set("_fame_frame", -1)
	_assert(float(GS.fame_mult()) > 1.0 + income * float(TN.fame_per_income) - 0.01, "fame grows with museum income")
	_assert(str(GS.fame_line()).contains("finds pay x"), "the tray explains the fame bonus in plain words")


func _reset_fame_cache() -> void:
	GS.set("_fame_frame", -1)


func _test_find_card_says_new_or_duplicate() -> void:
	var chip_script: GDScript = load("res://find_chip.gd") as GDScript
	var chip: Control = chip_script.new()
	root.add_child(chip)
	_assert(str(chip.call("_museum_line", "New · 1/6")).begins_with("New for museum"), "a needed bone says New for museum")
	_assert(str(chip.call("_museum_line", "Duplicate · 6/6")).begins_with("Duplicate"), "an extra copy says Duplicate")
	_assert(str(chip.call("_museum_line", "Upgrade · Great")).begins_with("Upgrades exhibit"), "a better copy says it upgrades the exhibit")
	_assert(str(chip.call("_note_line", {"cast": true, "kind": TN.BONE_FRAGILE})).contains("losing stars"), "plaster on a fragile bone says what it saved")
	_assert(str(chip.call("_note_line", {"cast": true, "kind": TN.BONE_SOLID})) == "", "plaster on a solid bone adds no noise")
	chip.queue_free()


func _assert(ok: bool, label: String) -> void:
	if ok:
		_passed += 1
		print("PASS  %s" % label)
	else:
		_failed += 1
		print("FAIL  %s" % label)
