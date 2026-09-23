extends SceneTree

## Save / load GameState without touching the live user save.
## Run: godot --headless --path <project> -s res://tests/test_save_game.gd

const PATH := "user://test_save.json"

var _failed: int = 0
var _passed: int = 0
var GS: Node


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	GS = root.get_node("GameState")
	_test_roundtrip_keeps_progress()
	_test_old_save_piece_is_not_pending()
	_test_missing_file_does_not_load()
	_cleanup()
	print("save_game %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _reset() -> void:
	GS.pieces.clear()
	GS.money = 0
	GS.featured_stand_id = ""
	GS.pending_unveils.clear()
	GS.pending_notices.clear()
	GS.unveil_spike_left = 0.0
	GS._income_accum = 0.0
	GS.precision_on = false
	for item in GS.catalog:
		GS.levels[item["id"]] = 0
	GS.apply_upgrades()


func _cleanup() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func _test_roundtrip_keeps_progress() -> void:
	_reset()
	GS.money = 240
	GS.levels["shovel_click"] = 1
	GS.levels["site_size"] = 2
	GS.precision_on = true
	GS.install_find("triceratops_skull", "Triceratops Skull", 0.8, false)
	GS.set_featured_stand("triceratops")
	_assert(GS.save_game(PATH), "writes a save file")
	_reset()
	_assert(GS.money == 0, "reset cleared money")
	_assert(GS.load_game(PATH), "loads the save file")
	_assert(GS.money == 240, "money restored")
	_assert(int(GS.levels.get("shovel_click", 0)) == 1, "upgrade ranks restored")
	_assert(int(GS.levels.get("site_size", 0)) == 2, "site rank restored")
	_assert(GS.precision_on, "precision flag restored")
	_assert(GS.has_piece("triceratops_skull"), "museum find restored")
	_assert(GS.featured_stand_id == "triceratops", "spotlight restored")
	_assert(GS.stand_has_pending_unveil("triceratops"), "new find still waits to unveil")
	_assert(int(TN_site_rank()) == 2, "saved site rank applies")


func _test_old_save_piece_is_not_pending() -> void:
	_reset()
	var data := {
		"version": 1,
		"money": 10,
		"levels": {},
		"pieces": {
			"triceratops_skull": {
				"name": "Triceratops Skull",
				"cleanliness": 1.0,
				"clean": true,
			},
		},
		"precision_on": false,
		"featured_stand_id": "",
	}
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	_assert(GS.load_game(PATH), "loads a save with no unveil map")
	_assert(GS.stand_is_filled("triceratops"), "old skull still fills the bay")
	_assert(not GS.stand_has_pending_unveil("triceratops"), "old saves are not ribboned")


func _test_missing_file_does_not_load() -> void:
	_reset()
	_assert(not GS.has_save("user://missing_fossil_save.json"), "missing save is reported")
	_assert(not GS.load_game("user://missing_fossil_save.json"), "load fails cleanly")


func TN_site_rank() -> int:
	return int(root.get_node("Tuning").site_size_rank)


func _assert(cond: bool, msg: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		push_error("FAIL: " + msg)
