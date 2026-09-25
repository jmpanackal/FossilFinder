extends SceneTree

## Full museum roster: every dino can be completed in sequence.
## Run: godot --headless --path <project> -s res://tests/test_fossil_roster.gd

var _failed: int = 0
var _passed: int = 0
var GS: Node
var TN: Node

const ROSTER := [
	{"id": "t_rex_tooth", "path": "res://t_rex_tooth.tres", "cells": 1, "rank": 0, "rich": false, "stand": "t_rex", "region": "jaw"},
	{"id": "t_rex_jaw", "path": "res://t_rex_jaw.tres", "cells": 4, "rank": 3, "rich": true, "stand": "t_rex", "region": "jaw"},
	{"id": "t_rex_femur", "path": "res://t_rex_femur.tres", "cells": 4, "rank": 3, "rich": true, "stand": "t_rex", "region": "legs"},
	{"id": "t_rex_ribcage", "path": "res://t_rex_ribcage.tres", "cells": 5, "rank": 3, "rich": false, "stand": "t_rex", "region": "torso"},
	{"id": "t_rex_tail", "path": "res://t_rex_tail.tres", "cells": 3, "rank": 2, "rich": false, "stand": "t_rex", "region": "tail"},
	{"id": "t_rex_skull", "path": "res://t_rex_skull.tres", "cells": 8, "rank": 4, "rich": true, "stand": "t_rex", "region": "head"},
	{"id": "triceratops_tooth", "path": "res://triceratops_tooth.tres", "cells": 1, "rank": 0, "rich": false, "stand": "triceratops", "region": "beak"},
	{"id": "triceratops_vertebra", "path": "res://triceratops_vertebra.tres", "cells": 3, "rank": 1, "rich": false, "stand": "triceratops", "region": "body"},
	{"id": "triceratops_nose_horn", "path": "res://triceratops_nose_horn.tres", "cells": 2, "rank": 2, "rich": false, "stand": "triceratops", "region": "nose"},
	{"id": "triceratops_brow_horns", "path": "res://triceratops_brow_horns.tres", "cells": 3, "rank": 2, "rich": false, "stand": "triceratops", "region": "brow"},
	{"id": "triceratops_hind_limb", "path": "res://triceratops_hind_limb.tres", "cells": 3, "rank": 2, "rich": false, "stand": "triceratops", "region": "legs"},
	{"id": "triceratops_tail", "path": "res://triceratops_tail.tres", "cells": 3, "rank": 2, "rich": false, "stand": "triceratops", "region": "tail"},
	{"id": "triceratops_skull", "path": "res://triceratops_skull.tres", "cells": 8, "rank": 3, "rich": true, "stand": "triceratops", "region": "skull"},
	{"id": "stegosaurus_foot", "path": "res://stegosaurus_foot.tres", "cells": 1, "rank": 0, "rich": false, "stand": "stegosaurus", "region": "foot"},
	{"id": "stegosaurus_plate", "path": "res://stegosaurus_plate.tres", "cells": 2, "rank": 3, "rich": false, "stand": "stegosaurus", "region": "plates"},
	{"id": "stegosaurus_femur", "path": "res://stegosaurus_femur.tres", "cells": 3, "rank": 4, "rich": false, "stand": "stegosaurus", "region": "legs"},
	{"id": "stegosaurus_thagomizer", "path": "res://stegosaurus_thagomizer.tres", "cells": 4, "rank": 4, "rich": true, "stand": "stegosaurus", "region": "tail"},
	{"id": "stegosaurus_torso", "path": "res://stegosaurus_torso.tres", "cells": 5, "rank": 5, "rich": false, "stand": "stegosaurus", "region": "torso"},
	{"id": "stegosaurus_skull", "path": "res://stegosaurus_skull.tres", "cells": 3, "rank": 4, "rich": true, "stand": "stegosaurus", "region": "head"},
	{"id": "velociraptor_claw", "path": "res://velociraptor_claw.tres", "cells": 1, "rank": 4, "rich": false, "stand": "velociraptor", "region": "claw"},
	{"id": "velociraptor_skull", "path": "res://velociraptor_skull.tres", "cells": 2, "rank": 4, "rich": true, "stand": "velociraptor", "region": "head"},
	{"id": "velociraptor_femur", "path": "res://velociraptor_femur.tres", "cells": 2, "rank": 4, "rich": false, "stand": "velociraptor", "region": "legs"},
	{"id": "velociraptor_tail", "path": "res://velociraptor_tail.tres", "cells": 3, "rank": 4, "rich": false, "stand": "velociraptor", "region": "tail"},
	{"id": "velociraptor_ribs", "path": "res://velociraptor_ribs.tres", "cells": 3, "rank": 4, "rich": false, "stand": "velociraptor", "region": "torso"},
	{"id": "brachiosaurus_tooth", "path": "res://brachiosaurus_tooth.tres", "cells": 1, "rank": 2, "rich": false, "stand": "brachiosaurus", "region": "tooth"},
	{"id": "brachiosaurus_tail", "path": "res://brachiosaurus_tail.tres", "cells": 4, "rank": 5, "rich": false, "stand": "brachiosaurus", "region": "tail"},
	{"id": "brachiosaurus_skull", "path": "res://brachiosaurus_skull.tres", "cells": 3, "rank": 6, "rich": true, "stand": "brachiosaurus", "region": "head"},
	{"id": "brachiosaurus_humerus", "path": "res://brachiosaurus_humerus.tres", "cells": 5, "rank": 6, "rich": true, "stand": "brachiosaurus", "region": "arm"},
	{"id": "brachiosaurus_femur", "path": "res://brachiosaurus_femur.tres", "cells": 6, "rank": 6, "rich": true, "stand": "brachiosaurus", "region": "legs"},
	{"id": "brachiosaurus_neck", "path": "res://brachiosaurus_neck.tres", "cells": 10, "rank": 7, "rich": true, "stand": "brachiosaurus", "region": "neck"},
]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	GS = root.get_node("GameState")
	TN = root.get_node("Tuning")
	_test_roster_files_and_shapes()
	_test_catalog_lists_every_playable_part()
	_test_small_finds_stay_trilobite_and_amber()
	_test_spawn_gates_match_roster()
	_test_rank_0_is_only_starter_one_cells()
	_test_late_pit_can_hide_the_big_bones()
	_test_each_dino_completes_in_sequence()
	_test_museum_regions_unveil()
	_test_main_find_prefers_missing_gated_parts()
	_test_extras_are_scraps_or_small_in_season()
	print("fossil_roster %d passed, %d failed" % [_passed, _failed])
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


func _load_row(row: Dictionary) -> Resource:
	return load(str(row["path"]))


func _can_spawn(data: Resource, rank: int, rich_bed: bool) -> bool:
	if data == null or not TN.has_method("piece_can_spawn"):
		return false
	return bool(TN.call("piece_can_spawn", data, rank, rich_bed))


func _piece_id(find: Dictionary) -> String:
	return str(find.get("piece_id", ""))


func _make_site() -> Node:
	var script: Script = load("res://dig_site.gd") as Script
	var site: Node = script.new()
	root.add_child(site)
	return site


func _install_full(piece_id: String, display_name: String) -> void:
	if GS.has_method("piece_needs_more"):
		while bool(GS.call("piece_needs_more", piece_id)):
			GS.install_find(piece_id, display_name, 1.0, true)
		return
	GS.install_find(piece_id, display_name, 1.0, true)


func _row_for_id(piece_id: String) -> Dictionary:
	for row in ROSTER:
		if str(row["id"]) == piece_id:
			return row
	return {}


func _test_roster_files_and_shapes() -> void:
	var shapes := {
		"t_rex_jaw": PackedInt32Array([1, 1, 1, 0, 0, 1]),
		"t_rex_femur": PackedInt32Array([1, 0, 1, 0, 1, 0, 0, 1, 0]),
		"t_rex_ribcage": PackedInt32Array([1, 1, 1, 0, 1, 1]),
		"t_rex_tail": PackedInt32Array([1, 1, 0, 1]),
		"t_rex_skull": PackedInt32Array([0, 1, 1, 1, 1, 1, 1, 1, 1, 0]),
		"triceratops_nose_horn": PackedInt32Array([1, 1]),
		"triceratops_brow_horns": PackedInt32Array([1, 0, 1, 0, 1, 0]),
		"triceratops_hind_limb": PackedInt32Array([1, 0, 1, 1]),
		"triceratops_tail": PackedInt32Array([1, 1, 0, 0, 1, 0]),
		"triceratops_vertebra": PackedInt32Array([0, 1, 0, 1, 0, 1]),
		"stegosaurus_plate": PackedInt32Array([0, 1, 1, 0]),
		"stegosaurus_femur": PackedInt32Array([1, 0, 1, 0, 1, 0]),
		"stegosaurus_thagomizer": PackedInt32Array([1, 0, 1, 1, 1, 0]),
		"stegosaurus_torso": PackedInt32Array([0, 1, 0, 1, 1, 1, 0, 1, 0]),
		"stegosaurus_skull": PackedInt32Array([1, 1, 1, 0]),
		"velociraptor_claw": PackedInt32Array([1]),
		"velociraptor_skull": PackedInt32Array([1, 1]),
		"velociraptor_femur": PackedInt32Array([1, 1]),
		"velociraptor_tail": PackedInt32Array([1, 0, 1, 1]),
		"velociraptor_ribs": PackedInt32Array([1, 1, 1, 0]),
		"brachiosaurus_tooth": PackedInt32Array([1]),
		"brachiosaurus_tail": PackedInt32Array([1, 1, 0, 0, 1, 0, 0, 1, 0]),
		"brachiosaurus_skull": PackedInt32Array([1, 1, 0, 1]),
		"brachiosaurus_humerus": PackedInt32Array([0, 1, 0, 1, 1, 1, 0, 1, 0]),
		"brachiosaurus_femur": PackedInt32Array([0, 1, 0, 1, 1, 1, 0, 1, 0, 0, 1, 0]),
		"brachiosaurus_neck": PackedInt32Array([1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1]),
	}
	for row in ROSTER:
		var data: Resource = _load_row(row)
		_assert(data != null, "%s resource exists" % str(row["id"]))
		if data == null:
			continue
		_assert(str(data.get("piece_id")) == str(row["id"]), "%s piece_id matches" % str(row["id"]))
		_assert(int(data.occupied_cells()) == int(row["cells"]), "%s is %d cells" % [str(row["id"]), int(row["cells"])])
		_assert(str(data.get("stand_id")) == str(row["stand"]), "%s stand is %s" % [str(row["id"]), str(row["stand"])])
		_assert(str(data.get("mount_region")) == str(row["region"]), "%s fills %s" % [str(row["id"]), str(row["region"])])
		var got_rank: Variant = data.get("min_rank")
		_assert(got_rank != null and int(got_rank) == int(row["rank"]), "%s min_rank is %d" % [str(row["id"]), int(row["rank"])])
		if str(row["id"]) in shapes:
			_assert(data.get("shape") == shapes[str(row["id"])], "%s uses the approved cell shape" % str(row["id"]))
		if str(row["id"]).ends_with("_skull"):
			_assert(bool(data.is_skull()), "%s counts as a skull" % str(row["id"]))
	var rex_skull: Resource = load("res://t_rex_skull.tres")
	var trike_skull: Resource = load("res://triceratops_skull.tres")
	if rex_skull != null and trike_skull != null:
		_assert(rex_skull.get("shape") != trike_skull.get("shape"), "T. rex skull is a fat snout, not the trike frill")


func _test_catalog_lists_every_playable_part() -> void:
	var listed: Dictionary = {}
	for path in TN.main_fossil_paths:
		listed[str(path)] = true
	for row in ROSTER:
		_assert(listed.has(str(row["path"])), "%s is in the main find list" % str(row["id"]))
	_assert(not listed.has("res://tooth.tres"), "generic nameless tooth is not a main find")
	_assert(not listed.has("res://vertebra.tres"), "generic vertebra is not a main find")


func _test_small_finds_stay_trilobite_and_amber() -> void:
	_reset()
	_assert(TN.extra_fossil_paths.size() == 2, "Small Finds extras are only two scraps")
	for path in TN.extra_fossil_paths:
		var data: Resource = load(str(path))
		_assert(data != null, "%s extra scrap loads" % str(path))
		if data == null:
			continue
		var id: String = str(data.get("piece_id"))
		_assert(id == "trilobite" or id == "amber_insect", "extra scrap is trilobite or amber, not %s" % id)
		_assert(str(GS.stand_for_piece(id)) == "small_finds", "%s stays in Small Finds" % id)
	_assert(str(GS.stand_for_piece("velociraptor_claw")) == "velociraptor", "raptor claw is not a Small Find")
	_assert(str(GS.stand_for_piece("brachiosaurus_tooth")) == "brachiosaurus", "brach tooth is not a Small Find")


func _test_spawn_gates_match_roster() -> void:
	for row in ROSTER:
		var data: Resource = _load_row(row)
		if data == null:
			_assert(false, "%s loads for spawn gates" % str(row["id"]))
			continue
		var rank: int = int(row["rank"])
		var rich: bool = bool(row["rich"])
		if rank > 0:
			_assert(not _can_spawn(data, rank - 1, true), "%s waits past rank %d even with Rich Bed" % [str(row["id"]), rank - 1])
		if rich:
			_assert(not _can_spawn(data, rank, false), "%s needs Rich Bed at rank %d" % [str(row["id"]), rank])
			_assert(_can_spawn(data, rank, true), "%s may spawn at rank %d with Rich Bed" % [str(row["id"]), rank])
		else:
			_assert(_can_spawn(data, rank, false), "%s may spawn at rank %d" % [str(row["id"]), rank])
			_assert(_can_spawn(data, rank, true), "%s still may spawn at rank %d with Rich Bed" % [str(row["id"]), rank])


func _test_rank_0_is_only_starter_one_cells() -> void:
	_set_site(0, false)
	var allowed: PackedStringArray = PackedStringArray()
	var blocked: PackedStringArray = PackedStringArray()
	for row in ROSTER:
		var data: Resource = _load_row(row)
		if data == null:
			continue
		if _can_spawn(data, 0, false):
			allowed.append(str(row["id"]))
		else:
			blocked.append(str(row["id"]))
	_assert(allowed.has("t_rex_tooth"), "rank 0 can hide a T. rex tooth")
	_assert(allowed.has("triceratops_tooth"), "rank 0 can hide a Triceratops tooth")
	_assert(allowed.has("stegosaurus_foot"), "rank 0 can hide a Stegosaurus foot")
	_assert(allowed.size() == 3, "rank 0 mains are only the three starter 1-cells")
	_assert(blocked.has("velociraptor_claw"), "rank 0 never hides the raptor claw")
	_assert(blocked.has("brachiosaurus_tooth"), "rank 0 never hides a brach tooth")
	_assert(blocked.has("t_rex_skull"), "rank 0 never hides a T. rex skull")
	_assert(blocked.has("brachiosaurus_neck"), "rank 0 never hides the brach neck")
	var site: Node = _make_site()
	TN.extra_find_slots = 6
	TN.extra_find_chance = 1.0
	for _i in 20:
		site.call("start_round")
		for find in site.get("finds"):
			var id: String = _piece_id(find)
			_assert(
				id == "t_rex_tooth" or id == "triceratops_tooth" or id == "stegosaurus_foot" or id == "trilobite" or id == "amber_insect",
				"5x4 never hides %s" % id
			)
			_assert(id != "tooth", "5x4 does not restore the nameless tooth")
	site.free()


func _test_late_pit_can_hide_the_big_bones() -> void:
	_set_site(8, true)
	var late: PackedStringArray = PackedStringArray()
	for row in ROSTER:
		var data: Resource = _load_row(row)
		if data == null:
			continue
		if _can_spawn(data, 8, true):
			late.append(str(row["id"]))
	_assert(late.size() == ROSTER.size(), "rank 8 plus Rich Bed can hide every museum part")
	_assert(late.has("t_rex_skull"), "late pit can hide the T. rex skull")
	_assert(late.has("brachiosaurus_neck"), "late pit can hide the brach neck")
	_assert(late.has("brachiosaurus_femur"), "late pit can hide the 6-cell brach femur")
	_assert(not _can_spawn(load("res://brachiosaurus_neck.tres"), 6, true), "brach neck still waits past a mid pit")
	_assert(not _can_spawn(load("res://t_rex_skull.tres"), 3, true), "T. rex skull still waits past rank 3")


func _test_each_dino_completes_in_sequence() -> void:
	var by_stand: Dictionary = {}
	for row in ROSTER:
		var stand_id: String = str(row["stand"])
		if not by_stand.has(stand_id):
			by_stand[stand_id] = []
		(by_stand[stand_id] as Array).append(row)
	for stand_id in by_stand:
		_reset()
		var rows: Array = by_stand[stand_id]
		var owned: Dictionary = {}
		for rank in range(0, 9):
			for rich in [false, true]:
				for row in rows:
					var id: String = str(row["id"])
					if owned.has(id):
						continue
					var data: Resource = _load_row(row)
					if _can_spawn(data, rank, rich):
						owned[id] = true
						_install_full(id, str(data.get("name")))
		_assert(owned.size() == rows.size(), "%s can be completed in sequence" % str(stand_id))
		if GS.has_method("stand_is_complete"):
			_assert(bool(GS.call("stand_is_complete", stand_id)), "%s stand reads complete" % str(stand_id))
		else:
			_assert(false, "GameState exposes stand_is_complete")


func _test_museum_regions_unveil() -> void:
	_reset()
	_assert(GS.has_method("stand_region_filled"), "GameState exposes stand_region_filled")
	_assert(GS.has_method("stand_regions"), "GameState exposes stand_regions")
	if not GS.has_method("stand_region_filled") or not GS.has_method("stand_regions"):
		return
	var rex_regions: PackedStringArray = GS.call("stand_regions", "t_rex")
	for region in ["jaw", "head", "torso", "legs", "tail"]:
		_assert(rex_regions.has(region), "T. rex mount has a %s region" % region)
		_assert(not bool(GS.call("stand_region_filled", "t_rex", region)), "empty T. rex %s stays silhouette" % region)
	GS.install_find("t_rex_tooth", "T. rex Tooth", 1.0, true)
	_assert(bool(GS.call("stand_region_filled", "t_rex", "jaw")), "rex tooth fills the jaw")
	_assert(bool(GS.stand_has_pending_unveil("t_rex")), "rex tooth waits under a ribbon")
	_assert(not bool(GS.call("stand_region_filled", "t_rex", "head")), "empty rex head stays silhouette")
	GS.install_find("velociraptor_claw", "Sickle Claw", 1.0, true)
	_assert(bool(GS.stand_is_filled("velociraptor")), "raptor claw lights the Velociraptor stand")
	_assert(bool(GS.call("stand_region_filled", "velociraptor", "claw")), "raptor claw fills the claw region")
	GS.install_find("brachiosaurus_tooth", "Brachiosaurus Tooth", 1.0, true)
	_assert(bool(GS.stand_is_filled("brachiosaurus")), "brach tooth lights the sauropod stand before the neck")


func _test_main_find_prefers_missing_gated_parts() -> void:
	_set_site(4, true)
	for row in ROSTER:
		if str(row["id"]) == "t_rex_skull":
			continue
		if int(row["rank"]) > 4:
			continue
		_install_full(str(row["id"]), str(row["id"]))
	var site: Node = _make_site()
	TN.extra_find_slots = 0
	TN.extra_find_chance = 0.0
	for _i in 8:
		site.call("start_round")
		var finds: Array = site.get("finds")
		_assert(not finds.is_empty(), "rank 4 plus Rich Bed still hides a main find")
		if finds.is_empty():
			continue
		_assert(_piece_id(finds[0]) == "t_rex_skull", "main find prefers the missing T. rex skull")
	site.free()


func _test_extras_are_scraps_or_small_in_season() -> void:
	_set_site(1, true)
	var site: Node = _make_site()
	TN.extra_find_slots = 6
	TN.extra_find_chance = 1.0
	var extras: PackedStringArray = PackedStringArray()
	for _i in 16:
		site.call("start_round")
		var finds: Array = site.get("finds")
		for i in range(1, finds.size()):
			extras.append(_piece_id(finds[i]))
	_assert(not extras.is_empty(), "Scattered Scraps extras still appear")
	for id in extras:
		_assert(not id.ends_with("_skull"), "a 6x4 never hides a skull in an extra slot")
		_assert(id != "brachiosaurus_neck", "extras never bury the brach neck early")
		var row: Dictionary = _row_for_id(id)
		if row.is_empty():
			_assert(id == "trilobite" or id == "amber_insect", "unknown extra %s is not a dino part" % id)
			continue
		_assert(int(row["cells"]) <= 3, "in-season extra %s stays small" % id)
		_assert(int(row["rank"]) <= 1, "in-season extra %s is in season at rank 1" % id)
	site.free()
	_set_site(0, true)
	site = _make_site()
	TN.extra_find_slots = 6
	TN.extra_find_chance = 1.0
	for _i in 12:
		site.call("start_round")
		for find in site.get("finds"):
			_assert(_piece_id(find) != "brachiosaurus_neck", "start pit extras never hide the neck")
			_assert(not _piece_id(find).ends_with("_skull"), "start pit extras never hide a skull")
	site.free()


func _assert(ok: bool, label: String) -> void:
	if ok:
		_passed += 1
		print("PASS  %s" % label)
	else:
		_failed += 1
		print("FAIL  %s" % label)
