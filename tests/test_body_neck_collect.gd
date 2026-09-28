extends SceneTree

## Probe: Triceratops body + Brachiosaurus neck should collect once and fill the mount.
## Run: godot --headless --path <project> -s res://tests/test_body_neck_collect.gd

var _failed: int = 0
var _passed: int = 0
var GS: Node


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	GS = root.get_node("GameState")
	_probe("triceratops_vertebra", "Triceratops Vertebra", "triceratops", "body")
	_probe("brachiosaurus_neck", "Brachiosaurus Neck", "brachiosaurus", "neck")
	_test_pit_does_not_hide_two_unique_bodies()
	print("body_neck_collect %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _reset() -> void:
	GS.pieces.clear()
	GS.pending_unveils.clear()
	GS.money = 0


func _probe(piece_id: String, name: String, stand_id: String, region: String) -> void:
	_reset()
	var data: Resource = GS.fossil_data_for(piece_id)
	_assert(data != null, "%s resource resolves" % piece_id)
	if data != null:
		_assert(str(data.piece_id) == piece_id, "%s piece_id is %s" % [piece_id, data.piece_id])
		_assert(str(data.mount_region) == region, "%s mount_region is %s" % [piece_id, data.mount_region])
		_assert(int(data.set_need) == 1, "%s set_need is 1 (got %d)" % [piece_id, int(data.set_need)])
	_assert(str(GS.collection_status_line(piece_id)).begins_with("New"), "%s starts New" % piece_id)
	_assert(int(GS.piece_count(piece_id)) == 0, "%s is not already owned" % piece_id)
	var fate: String = str(GS.hall_fate_line(piece_id))
	GS.install_find(piece_id, name, 1.0, true)
	_assert(fate.begins_with("New"), "%s extract fate before install is New (was %s)" % [piece_id, fate])
	_assert(GS.has_piece(piece_id), "%s is in the collection after install" % piece_id)
	_assert(bool(GS.stand_region_filled(stand_id, region)), "%s fills the %s region" % [piece_id, region])
	_assert(str(GS.collection_status_line(piece_id)).begins_with("Duplicate"), "%s second copy is a real extra" % piece_id)


func _test_pit_does_not_hide_two_unique_bodies() -> void:
	var TN: Node = root.get_node("Tuning")
	GS.pieces.clear()
	for item in GS.catalog:
		GS.levels[item["id"]] = 0
	GS.apply_upgrades()
	TN.site_size_rank = 1
	TN.big_finds_unlocked = true
	TN.apply_site_layout()
	GS.install_find("t_rex_tooth", "T. rex Tooth", 1.0, true)
	GS.install_find("triceratops_tooth", "Triceratops Tooth", 1.0, true)
	GS.install_find("stegosaurus_foot", "Stegosaurus Foot", 1.0, true)
	var site: Node = (load("res://dig_site.gd") as GDScript).new()
	root.add_child(site)
	TN.extra_find_slots = 6
	TN.extra_find_chance = 1.0
	var saw_body: bool = false
	for _i in 20:
		site.call("start_round")
		var finds: Array = site.get("finds")
		var bodies: int = 0
		for find in finds:
			if str(find.get("piece_id", "")) == "triceratops_vertebra":
				bodies += 1
		if bodies > 0:
			saw_body = true
		_assert(bodies <= 1, "one pit never hides two Triceratops bodies")
	_assert(saw_body, "rank 1 can still hide the Triceratops body")
	site.free()


func _assert(ok: bool, label: String) -> void:
	if ok:
		_passed += 1
		print("PASS  %s" % label)
	else:
		_failed += 1
		print("FAIL  %s" % label)
