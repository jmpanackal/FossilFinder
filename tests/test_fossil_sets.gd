extends SceneTree

## Teeth and feet collect as playable sets; extras after quota sell for more.
## Run: godot --headless --path <project> -s res://tests/test_fossil_sets.gd

var _failed: int = 0
var _passed: int = 0
var GS: Node
var TN: Node

const QUOTAS := {
	"t_rex_tooth": 6,
	"triceratops_tooth": 5,
	"stegosaurus_foot": 4,
	"stegosaurus_plate": 3,
	"velociraptor_claw": 2,
	"brachiosaurus_tooth": 5,
	"t_rex_skull": 1,
	"triceratops_skull": 1,
}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	GS = root.get_node("GameState")
	TN = root.get_node("Tuning")
	_test_quotas_match_playable_anatomy()
	_test_set_copies_fill_the_hall()
	_test_first_piece_unveils_later_pieces_grow()
	_test_extra_after_quota_sells_for_more()
	_test_unique_extra_stays_the_normal_sale()
	_test_player_is_told_about_sale_and_progress()
	_test_main_find_prefers_missing_quota()
	_test_completed_set_is_not_the_main_find()
	_test_sale_fodder_only_when_no_missing_one_cell()
	_test_stand_complete_needs_full_sets()
	_test_save_keeps_set_counts()
	_test_hall_exposes_each_slot()
	print("fossil_sets %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _reset() -> void:
	GS.pieces.clear()
	GS.money = 0
	GS.featured_stand_id = ""
	GS.pending_unveils.clear()
	GS.unveil_spike_left = 0.0
	for item in GS.catalog:
		GS.levels[item["id"]] = 0
	GS.apply_upgrades()


func _set_site(rank: int, rich_bed: bool) -> void:
	_reset()
	if rank <= 3:
		GS.levels["site_size"] = rank
	else:
		GS.levels["site_size"] = 3
		GS.levels["site_expand"] = rank - 3
	if rich_bed:
		GS.levels["rich_bed"] = 1
	GS.apply_upgrades()


func _need(piece_id: String) -> int:
	if not GS.has_method("piece_need"):
		return 0
	return int(GS.call("piece_need", piece_id))


func _count(piece_id: String) -> int:
	if not GS.has_method("piece_count"):
		return 1 if GS.has_piece(piece_id) else 0
	return int(GS.call("piece_count", piece_id))


func _fill(piece_id: String, display_name: String) -> void:
	if GS.has_method("piece_needs_more"):
		while bool(GS.call("piece_needs_more", piece_id)):
			GS.install_find(piece_id, display_name, 1.0, true)
		return
	var need: int = maxi(1, _need(piece_id))
	for _i in need:
		GS.install_find(piece_id, display_name, 1.0, true)


func _make_site() -> Node:
	var script: Script = load("res://dig_site.gd") as Script
	var site: Node = script.new()
	root.add_child(site)
	return site


func _main_id(site: Node) -> String:
	site.call("start_round")
	var finds: Array = site.get("finds")
	if finds.is_empty():
		return ""
	return str(finds[0].get("piece_id", ""))


func _sale(cleanliness: float, set_bonus: bool) -> int:
	var base: float = 100.0 * float(TN.duplicate_cash) * (0.5 + cleanliness * 0.5) * float(TN.fossil_value_mult)
	if set_bonus:
		var mult: float = 2.0
		if TN.get("set_complete_sale_mult") != null:
			mult = float(TN.set_complete_sale_mult)
		base *= mult
	return int(round(base))


func _test_quotas_match_playable_anatomy() -> void:
	_assert(GS.has_method("piece_need"), "GameState exposes piece_need")
	_assert(GS.has_method("piece_count"), "GameState exposes piece_count")
	if not GS.has_method("piece_need"):
		return
	for piece_id in QUOTAS:
		_assert(_need(str(piece_id)) == int(QUOTAS[piece_id]), "%s need is %d" % [str(piece_id), int(QUOTAS[piece_id])])
	_assert(_need("t_rex_tooth") < 20, "T. rex teeth are a playable mouth, not 60")
	_assert(_need("stegosaurus_plate") <= 4, "Stegosaurus plates are a ridge, not 17")
	var data: Resource = load("res://t_rex_tooth.tres")
	_assert(data != null and int(data.get("set_need")) == 6, "rex tooth resource stores set_need 6")


func _test_set_copies_fill_the_hall() -> void:
	_reset()
	var note: String = str(GS.install_find("t_rex_tooth", "T. rex Tooth", 1.0, true))
	_assert(_count("t_rex_tooth") == 1, "first rex tooth mounts")
	_assert(GS.has_piece("t_rex_tooth"), "first rex tooth counts as owned")
	_assert(note.to_lower().find("sold") < 0, "first rex tooth is not sold")
	GS.install_find("t_rex_tooth", "T. rex Tooth", 1.0, true)
	GS.install_find("t_rex_tooth", "T. rex Tooth", 1.0, true)
	_assert(_count("t_rex_tooth") == 3, "third rex tooth still mounts")
	_assert(int(GS.money) == 0, "mid-set teeth do not sell")
	_assert(bool(GS.call("stand_region_filled", "t_rex", "jaw")), "first tooth still lights the jaw region")


func _test_first_piece_unveils_later_pieces_grow() -> void:
	_reset()
	GS.install_find("stegosaurus_foot", "Stegosaurus Foot", 1.0, true)
	_assert(bool(GS.stand_has_pending_unveil("stegosaurus")), "first foot waits under a ribbon")
	GS.unveil_stand("stegosaurus")
	_assert(not GS.stand_has_pending_unveil("stegosaurus"), "ribbon clears after unveil")
	GS.install_find("stegosaurus_foot", "Stegosaurus Foot", 1.0, true)
	_assert(_count("stegosaurus_foot") == 2, "second foot grows the mount")
	_assert(not GS.stand_has_pending_unveil("stegosaurus"), "later feet do not re-ribbon")
	_assert(bool(GS.stand_is_filled("stegosaurus")), "the stand stays filled while the set grows")


func _test_extra_after_quota_sells_for_more() -> void:
	_reset()
	_fill("t_rex_tooth", "T. rex Tooth")
	_assert(_count("t_rex_tooth") == 6, "six rex teeth fill the mouth")
	var money_before: int = int(GS.money)
	var note: String = str(GS.install_find("t_rex_tooth", "T. rex Tooth", 1.0, true))
	var paid: int = int(GS.money) - money_before
	_assert(_count("t_rex_tooth") == 6, "a seventh tooth does not add a museum slot")
	_assert(paid == _sale(1.0, true), "completed-set extra sells at the fat set bonus")
	_assert(paid > _sale(1.0, false), "set extra pays more than a normal duplicate")
	_assert(note.to_lower().find("sold") >= 0, "extra sale names the sale")
	_assert(note.to_lower().find("complete") >= 0 or note.to_lower().find("already") >= 0, "extra sale says the set is done")


func _test_unique_extra_stays_the_normal_sale() -> void:
	_reset()
	GS.install_find("triceratops_skull", "Triceratops Skull", 1.0, true)
	var money_before: int = int(GS.money)
	GS.install_find("triceratops_skull", "Triceratops Skull", 1.0, true)
	var paid: int = int(GS.money) - money_before
	_assert(paid == _sale(1.0, false), "a second skull still sells at the normal duplicate rate")
	_assert(paid < _sale(1.0, true), "a unique extra is not the fat set bonus")


func _test_player_is_told_about_sale_and_progress() -> void:
	_reset()
	var first: String = str(GS.install_find("triceratops_tooth", "Triceratops Tooth", 1.0, true))
	_assert(first.find("1/5") >= 0 or first.to_lower().find("display") >= 0, "first battery tooth mentions progress")
	var mid: String = str(GS.install_find("triceratops_tooth", "Triceratops Tooth", 1.0, true))
	_assert(mid.find("2/5") >= 0, "second battery tooth reports 2/5")
	var script: GDScript = load("res://summary.gd") as GDScript
	_assert(script.has_method("find_line"), "summary still builds find lines")
	var mounted: String = str(script.call("find_line", "T. rex Tooth", "Well preserved", "", "2/6 on display"))
	var sold: String = str(script.call("find_line", "T. rex Tooth", "Well preserved", "", "sold extra"))
	_assert(mounted.find("2/6") >= 0, "summary can show set progress")
	_assert(sold.find("sold extra") >= 0, "summary names a sold extra")
	_assert(sold.to_lower().find("hall") < 0, "summary sale line stays short")


func _test_main_find_prefers_missing_quota() -> void:
	_set_site(0, false)
	_fill("t_rex_tooth", "T. rex Tooth")
	_fill("triceratops_tooth", "Triceratops Tooth")
	var site: Node = _make_site()
	TN.extra_find_slots = 0
	TN.extra_find_chance = 0.0
	for _i in 8:
		_assert(_main_id(site) == "stegosaurus_foot", "main find prefers the unfinished stego feet")
	site.free()


func _test_completed_set_is_not_the_main_find() -> void:
	_set_site(0, false)
	_fill("t_rex_tooth", "T. rex Tooth")
	var site: Node = _make_site()
	TN.extra_find_slots = 0
	TN.extra_find_chance = 0.0
	for _i in 10:
		var id: String = _main_id(site)
		_assert(id != "t_rex_tooth", "finished rex teeth are not the main find")
		_assert(id == "triceratops_tooth" or id == "stegosaurus_foot", "main find stays on an unfinished starter set")
	site.free()


func _test_sale_fodder_only_when_no_missing_one_cell() -> void:
	_set_site(0, false)
	_fill("t_rex_tooth", "T. rex Tooth")
	_fill("triceratops_tooth", "Triceratops Tooth")
	_fill("stegosaurus_foot", "Stegosaurus Foot")
	var site: Node = _make_site()
	TN.extra_find_slots = 0
	TN.extra_find_chance = 0.0
	var seen: Dictionary = {}
	for _i in 12:
		seen[_main_id(site)] = true
	_assert(seen.has("t_rex_tooth") or seen.has("triceratops_tooth") or seen.has("stegosaurus_foot"), "sale-fodder 1-cells can still hide when nothing else is legal")
	site.free()


func _test_stand_complete_needs_full_sets() -> void:
	_reset()
	GS.install_find("stegosaurus_foot", "Stegosaurus Foot", 1.0, true)
	GS.install_find("stegosaurus_plate", "Stegosaurus Plate", 1.0, true)
	GS.install_find("stegosaurus_femur", "Stegosaurus Femur", 1.0, true)
	GS.install_find("stegosaurus_thagomizer", "Stegosaurus Thagomizer", 1.0, true)
	GS.install_find("stegosaurus_torso", "Stegosaurus Torso", 1.0, true)
	GS.install_find("stegosaurus_skull", "Stegosaurus Skull", 1.0, true)
	_assert(not bool(GS.call("stand_is_complete", "stegosaurus")), "one foot and one plate do not finish Stegosaurus")
	_fill("stegosaurus_foot", "Stegosaurus Foot")
	_fill("stegosaurus_plate", "Stegosaurus Plate")
	_assert(bool(GS.call("stand_is_complete", "stegosaurus")), "full foot and plate sets finish Stegosaurus")


func _test_save_keeps_set_counts() -> void:
	_reset()
	var path: String = "user://test_fossil_sets.json"
	GS.install_find("velociraptor_claw", "Velociraptor Sickle Claw", 1.0, true)
	GS.install_find("velociraptor_claw", "Velociraptor Sickle Claw", 1.0, true)
	_assert(GS.save_game(path), "writes a set save")
	_reset()
	_assert(GS.load_game(path), "loads a set save")
	_assert(_count("velociraptor_claw") == 2, "both sickle claws restore")
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var old_path: String = "user://test_fossil_sets_old.json"
	var data := {
		"version": 1,
		"money": 4,
		"levels": {},
		"pieces": {
			"t_rex_tooth": {"name": "T. rex Tooth", "cleanliness": 1.0, "clean": true},
		},
		"precision_on": false,
		"featured_stand_id": "",
	}
	var file := FileAccess.open(old_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	_assert(GS.load_game(old_path), "loads a pre-count save")
	_assert(_count("t_rex_tooth") == 1, "old saves count as one mounted tooth")
	if FileAccess.file_exists(old_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(old_path))


func _test_hall_exposes_each_slot() -> void:
	_reset()
	var exhibit_script: Script = load("res://museum_exhibit.gd") as Script
	_assert(exhibit_script != null, "museum exhibit script loads")
	if exhibit_script == null:
		return
	var exhibit: Node = exhibit_script.new()
	root.add_child(exhibit)
	_assert(exhibit.has_method("display_slots"), "exhibit reports how many teeth or feet to draw")
	_assert(exhibit.has_method("slot_on"), "exhibit reports which slots are filled")
	if exhibit.has_method("display_slots"):
		_assert(int(exhibit.call("display_slots", "t_rex_tooth")) == 6, "T. rex jaw draws six teeth")
		_assert(int(exhibit.call("display_slots", "stegosaurus_foot")) == 4, "Stegosaurus draws four feet")
		_assert(int(exhibit.call("display_slots", "stegosaurus_plate")) == 3, "Stegosaurus draws three plates")
		_assert(int(exhibit.call("display_slots", "velociraptor_claw")) == 2, "Velociraptor draws two sickle claws")
		_assert(int(exhibit.call("display_slots", "brachiosaurus_tooth")) == 5, "Brachiosaurus draws five peg teeth")
		_assert(int(exhibit.call("display_slots", "triceratops_tooth")) == 5, "Triceratops draws five battery teeth")
	GS.install_find("t_rex_tooth", "T. rex Tooth", 1.0, true)
	GS.install_find("t_rex_tooth", "T. rex Tooth", 1.0, true)
	if exhibit.has_method("slot_on"):
		_assert(bool(exhibit.call("slot_on", "t_rex_tooth", 0)), "first rex tooth is on the mount")
		_assert(bool(exhibit.call("slot_on", "t_rex_tooth", 1)), "second rex tooth is on the mount")
		_assert(not bool(exhibit.call("slot_on", "t_rex_tooth", 2)), "empty tooth slots stay empty")
	exhibit.free()


func _assert(ok: bool, label: String) -> void:
	if ok:
		_passed += 1
		print("PASS  %s" % label)
	else:
		_failed += 1
		print("FAIL  %s" % label)
