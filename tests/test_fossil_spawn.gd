extends SceneTree

## Named dino scraps in the start pit; skull still waits on rank 3 + Rich Bed.
## Run: godot --headless --path <project> -s res://tests/test_fossil_spawn.gd

var _failed: int = 0
var _passed: int = 0
var GS: Node
var TN: Node
var _rex_tooth: Resource
var _trike_tooth: Resource
var _stego_foot: Resource
var _trike_vertebra: Resource
var _skull: Resource
var _trilobite: Resource
var _amber: Resource


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	GS = root.get_node("GameState")
	TN = root.get_node("Tuning")
	_rex_tooth = load("res://t_rex_tooth.tres")
	_trike_tooth = load("res://triceratops_tooth.tres")
	_stego_foot = load("res://stegosaurus_foot.tres")
	_trike_vertebra = load("res://triceratops_vertebra.tres")
	_skull = load("res://triceratops_skull.tres")
	_trilobite = load("res://trilobite.tres")
	_amber = load("res://amber_insect.tres")
	_test_starter_one_cells_exist()
	_test_rank_caps_match_the_roster()
	_test_start_pit_never_hides_a_skull()
	_test_start_pit_can_be_rex_trike_or_stego()
	_test_starter_parts_light_dino_stands()
	_test_small_finds_are_not_dino_teeth()
	_test_rich_bed_on_start_pit_still_cannot_hide_skull()
	_test_trike_vertebra_only_at_rank_1_plus()
	_test_skull_only_at_rank_3_and_rich_bed()
	_test_extras_stay_scraps()
	print("fossil_spawn %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _reset() -> void:
	GS.pieces.clear()
	GS.money = 0
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


func _can_spawn(data: Resource, rank: int, rich_bed: bool) -> bool:
	if data == null or not TN.has_method("piece_can_spawn"):
		return false
	return bool(TN.call("piece_can_spawn", data, rank, rich_bed))


func _piece_id(find: Dictionary) -> String:
	return str(find.get("piece_id", ""))


func _main_ids(site: Node, rounds: int) -> PackedStringArray:
	var ids: PackedStringArray = PackedStringArray()
	for _i in rounds:
		site.call("start_round")
		var finds: Array = site.get("finds")
		if finds.is_empty():
			ids.append("")
			continue
		ids.append(_piece_id(finds[0]))
	return ids


func _all_ids(site: Node, rounds: int) -> PackedStringArray:
	var ids: PackedStringArray = PackedStringArray()
	for _i in rounds:
		site.call("start_round")
		for find in site.get("finds"):
			ids.append(_piece_id(find))
	return ids


func _make_site() -> Node:
	var script: Script = load("res://dig_site.gd") as Script
	var site: Node = script.new()
	root.add_child(site)
	return site


func _silence_extras() -> void:
	TN.extra_find_slots = 0
	TN.extra_find_chance = 0.0


func _force_extras() -> void:
	TN.extra_find_slots = 6
	TN.extra_find_chance = 1.0


func _is_starter_part(id: String) -> bool:
	return id == "t_rex_tooth" or id == "triceratops_tooth" or id == "stegosaurus_foot"


func _install_full(piece_id: String, display_name: String) -> void:
	if GS.has_method("piece_needs_more"):
		while bool(GS.call("piece_needs_more", piece_id)):
			GS.install_find(piece_id, display_name, 1.0, true)
		return
	GS.install_find(piece_id, display_name, 1.0, true)


func _test_starter_one_cells_exist() -> void:
	_assert(_rex_tooth != null, "T. rex tooth resource exists")
	_assert(_trike_tooth != null, "Triceratops tooth resource exists")
	_assert(_stego_foot != null, "Stegosaurus foot resource exists")
	_assert(_trike_vertebra != null, "Triceratops vertebra resource exists")
	_assert(_trilobite != null, "trilobite resource exists")
	_assert(_amber != null, "amber insect resource exists")
	if _rex_tooth == null or _trike_tooth == null or _stego_foot == null:
		return
	_assert(str(_rex_tooth.get("piece_id")) == "t_rex_tooth", "rex tooth has a named piece id")
	_assert(_rex_tooth.cell_offsets().size() == 1, "rex tooth is one cell")
	_assert(_trike_tooth.cell_offsets().size() == 1, "trike tooth is one cell")
	_assert(_stego_foot.cell_offsets().size() == 1, "stego foot is one cell")
	if _trike_vertebra != null:
		_assert(_trike_vertebra.cell_offsets().size() == 3, "trike vertebra is three cells")
	if _skull != null:
		_assert(_skull.cell_offsets().size() == 8, "triceratops skull is still eight cells")


func _test_rank_caps_match_the_roster() -> void:
	_assert(TN.has_method("spawn_max_cells_for_rank"), "Tuning exposes the cell cap")
	_assert(TN.has_method("spawn_max_box_for_rank"), "Tuning exposes the box cap")
	_assert(TN.has_method("piece_can_spawn"), "Tuning exposes the spawn gates")
	if not TN.has_method("spawn_max_cells_for_rank") or not TN.has_method("spawn_max_box_for_rank"):
		return
	var cells := [
		[0, 1], [1, 3], [2, 6], [3, 8], [4, 10], [5, 12], [6, 14], [7, 18], [8, 18],
	]
	var boxes := [
		[0, Vector2i(1, 1)],
		[1, Vector2i(3, 2)],
		[2, Vector2i(4, 3)],
		[3, Vector2i(5, 4)],
		[4, Vector2i(6, 5)],
		[5, Vector2i(7, 5)],
		[6, Vector2i(8, 6)],
		[7, Vector2i(10, 7)],
		[8, Vector2i(10, 7)],
	]
	for row in cells:
		_assert(int(TN.call("spawn_max_cells_for_rank", int(row[0]))) == int(row[1]), "rank %d cell cap is %d" % [int(row[0]), int(row[1])])
	for row in boxes:
		_assert(TN.call("spawn_max_box_for_rank", int(row[0])) == row[1], "rank %d box cap is %dx%d" % [int(row[0]), (row[1] as Vector2i).x, (row[1] as Vector2i).y])


func _test_start_pit_never_hides_a_skull() -> void:
	_set_site(0, false)
	_assert(not _can_spawn(_skull, 0, false), "skull is gated out of the start pit")
	var site: Node = _make_site()
	_silence_extras()
	var ids: PackedStringArray = _all_ids(site, 16)
	_assert(not ids.is_empty(), "start pit still hides a find")
	for id in ids:
		_assert(id != "triceratops_skull", "5x4 never hides the skull")
		_assert(id != "triceratops_vertebra", "5x4 never hides a 3-cell vertebra")
	site.free()


func _test_start_pit_can_be_rex_trike_or_stego() -> void:
	_set_site(0, false)
	_assert(_can_spawn(_rex_tooth, 0, false), "T. rex tooth may spawn in a 5x4")
	_assert(_can_spawn(_trike_tooth, 0, false), "Triceratops tooth may spawn in a 5x4")
	_assert(_can_spawn(_stego_foot, 0, false), "Stegosaurus foot may spawn in a 5x4")
	var site: Node = _make_site()
	_silence_extras()
	_install_full("t_rex_tooth", "T. rex Tooth")
	_install_full("triceratops_tooth", "Triceratops Tooth")
	for id in _main_ids(site, 10):
		_assert(id == "stegosaurus_foot", "missing stego foot is the 5x4 main find")
	GS.pieces.erase("t_rex_tooth")
	_install_full("stegosaurus_foot", "Stegosaurus Foot")
	for id in _main_ids(site, 10):
		_assert(id == "t_rex_tooth", "missing rex tooth can be the 5x4 main find")
	GS.pieces.erase("triceratops_tooth")
	_install_full("t_rex_tooth", "T. rex Tooth")
	for id in _main_ids(site, 10):
		_assert(id == "triceratops_tooth", "missing trike tooth can be the 5x4 main find")
	site.free()


func _test_starter_parts_light_dino_stands() -> void:
	_reset()
	_assert(str(GS.stand_for_piece("t_rex_tooth")) == "t_rex", "rex tooth mounts on T. rex")
	_assert(str(GS.stand_for_piece("triceratops_tooth")) == "triceratops", "trike tooth mounts on Triceratops")
	_assert(str(GS.stand_for_piece("stegosaurus_foot")) == "stegosaurus", "stego foot mounts on Stegosaurus")
	_assert(str(GS.stand_for_piece("triceratops_vertebra")) == "triceratops", "trike vertebra mounts on Triceratops")
	_assert(str(GS.stand_for_piece("t_rex_tooth")) != "small_finds", "rex tooth is not a Small Find")
	GS.install_find("t_rex_tooth", "T. rex Tooth", 1.0, true)
	_assert(bool(GS.stand_is_filled("t_rex")), "a starter rex tooth lights the T. rex stand")
	_assert(bool(GS.stand_has_pending_unveil("t_rex")), "the T. rex stand waits under a ribbon")
	GS.install_find("triceratops_tooth", "Triceratops Tooth", 1.0, true)
	_assert(bool(GS.stand_is_filled("triceratops")), "a starter trike tooth lights the Triceratops stand")
	GS.install_find("stegosaurus_foot", "Stegosaurus Foot", 1.0, true)
	_assert(bool(GS.stand_is_filled("stegosaurus")), "a starter stego foot lights the Stegosaurus stand")


func _test_small_finds_are_not_dino_teeth() -> void:
	_reset()
	_assert(str(GS.stand_for_piece("trilobite")) == "small_finds", "trilobite mounts in Small Finds")
	_assert(str(GS.stand_for_piece("amber_insect")) == "small_finds", "amber insect mounts in Small Finds")
	_assert(str(GS.stand_for_piece("triceratops_tooth")) != "small_finds", "trike tooth stays off the scrap case")
	if TN.get("extra_fossil_paths") != null:
		for path in TN.extra_fossil_paths:
			var data: Resource = load(str(path))
			if data == null:
				_assert(data != null, "%s extra scrap loads" % str(path))
				continue
			var id: String = str(data.get("piece_id"))
			_assert(id == "trilobite" or id == "amber_insect", "extra slots are trilobite or amber, not %s" % id)
			_assert(str(GS.stand_for_piece(id)) == "small_finds", "%s stays in Small Finds" % id)


func _test_rich_bed_on_start_pit_still_cannot_hide_skull() -> void:
	_set_site(0, true)
	_assert(bool(GS.big_finds_unlocked()), "Rich Bed is bought")
	_assert(int(TN.site_size_rank) == 0, "pit is still the 5x4")
	_assert(_can_spawn(_rex_tooth, 0, true), "Rich Bed still allows a 1-cell dino part")
	_assert(not _can_spawn(_skull, 0, true), "5x4 plus Rich Bed still cannot hide the skull")
	_assert(not _can_spawn(_trike_vertebra, 0, true), "Rich Bed does not unlock a 3-cell vertebra in a 5x4")
	var site: Node = _make_site()
	_force_extras()
	var ids: PackedStringArray = _all_ids(site, 16)
	_assert(not ids.is_empty(), "Rich Bed start pit still hides finds")
	for id in ids:
		_assert(id != "triceratops_skull", "Rich Bed cannot bury the skull in a 5x4")
		_assert(_is_starter_part(id) or id == "trilobite" or id == "amber_insect", "5x4 extras stay 1-cell scraps or starter parts")
	site.free()


func _test_trike_vertebra_only_at_rank_1_plus() -> void:
	_assert(not _can_spawn(_trike_vertebra, 0, false), "trike vertebra waits for rank 1")
	_assert(_can_spawn(_trike_vertebra, 1, false), "trike vertebra may spawn at rank 1")
	_assert(not _can_spawn(_skull, 1, false), "skull still waits past rank 1")
	_set_site(1, false)
	_install_full("t_rex_tooth", "T. rex Tooth")
	_install_full("triceratops_tooth", "Triceratops Tooth")
	_install_full("stegosaurus_foot", "Stegosaurus Foot")
	var site: Node = _make_site()
	_silence_extras()
	for id in _main_ids(site, 10):
		_assert(id == "triceratops_vertebra", "rank 1 prefers the missing trike vertebra")
		_assert(id != "triceratops_skull", "rank 1 never hides the skull")
	site.free()


func _test_skull_only_at_rank_3_and_rich_bed() -> void:
	_assert(not _can_spawn(_skull, 3, false), "rank 3 without Rich Bed cannot hide the skull")
	_assert(not _can_spawn(_skull, 2, true), "Rich Bed on an 8x5 cannot hide the 8-cell skull")
	_assert(not _can_spawn(_skull, 1, true), "Rich Bed on a 6x4 cannot hide the skull")
	_assert(_can_spawn(_skull, 3, true), "rank 3 plus Rich Bed may hide the skull")
	_set_site(3, false)
	var site: Node = _make_site()
	_silence_extras()
	for id in _all_ids(site, 12):
		_assert(id != "triceratops_skull", "a wide pit without Rich Bed never hides the skull")
	site.free()
	_set_site(3, true)
	for path in TN.main_fossil_paths:
		var data: Resource = load(str(path))
		if data == null:
			continue
		var id: String = str(data.get("piece_id"))
		if id == "triceratops_skull":
			continue
		if _can_spawn(data, 3, true):
			_install_full(id, str(data.get("name")))
	site = _make_site()
	_silence_extras()
	var ids: PackedStringArray = _main_ids(site, 10)
	_assert(not ids.is_empty(), "rank 3 plus Rich Bed still hides a main find")
	for id in ids:
		_assert(id == "triceratops_skull", "rank 3 plus Rich Bed prefers the missing skull")
	site.free()


func _test_extras_stay_scraps() -> void:
	_set_site(1, true)
	var site: Node = _make_site()
	_force_extras()
	var extras: PackedStringArray = PackedStringArray()
	for _i in 12:
		site.call("start_round")
		var finds: Array = site.get("finds")
		for i in range(1, finds.size()):
			extras.append(_piece_id(finds[i]))
	_assert(not extras.is_empty(), "Scattered Scraps / Rich Bed extras still appear")
	for id in extras:
		_assert(id != "triceratops_skull", "a 6x4 never hides a skull in an extra slot")
		_assert(not id.ends_with("_skull"), "extra slots never hide a skull")
		_assert(id != "brachiosaurus_neck", "a 6x4 never hides the brach neck")
		_assert(
			id == "trilobite" or id == "amber_insect" or _is_starter_part(id) or id == "triceratops_vertebra",
			"extra slots stay scraps or a small in-season part, not %s" % id
		)
	site.free()


func _assert(ok: bool, label: String) -> void:
	if ok:
		_passed += 1
		print("PASS  %s" % label)
	else:
		_failed += 1
		print("FAIL  %s" % label)
