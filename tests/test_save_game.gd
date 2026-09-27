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
	_test_roundtrip_keeps_unveil_rush()
	_test_old_save_piece_is_not_pending()
	_test_old_save_without_rush_fields_still_loads()
	_test_leftover_fine_point_ranks_do_not_crash()
	_test_missing_file_does_not_load()
	_test_reset_progress_wipes_save_and_keeps_settings()
	_test_menu_chrome_stays_up()
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
	if "unveil_rush_stacks" in GS:
		GS.unveil_rush_stacks = 0
	if "unveil_rush_unit" in GS:
		GS.unveil_rush_unit = 0.0
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


func _test_roundtrip_keeps_unveil_rush() -> void:
	_reset()
	GS.install_find("triceratops_skull", "Triceratops Skull", 1.0, true)
	GS.unveil_stand("triceratops")
	var stacks: int = int(GS.unveil_rush_stacks) if "unveil_rush_stacks" in GS else 0
	var unit: float = float(GS.unveil_rush_unit) if "unveil_rush_unit" in GS else 0.0
	var left: float = float(GS.unveil_spike_left)
	_assert(stacks > 0, "unveil left a rush to save")
	_assert(GS.save_game(PATH), "writes a rush save")
	_reset()
	_assert(GS.load_game(PATH), "loads the rush save")
	_assert(("unveil_rush_stacks" in GS) and int(GS.unveil_rush_stacks) == stacks, "rush stacks restore")
	_assert(("unveil_rush_unit" in GS) and is_equal_approx(float(GS.unveil_rush_unit), unit), "rush unit restores")
	_assert(is_equal_approx(float(GS.unveil_spike_left), left), "rush timer restores")


func _test_old_save_without_rush_fields_still_loads() -> void:
	_reset()
	var data := {
		"version": 1,
		"money": 12,
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
	_assert(GS.load_game(PATH), "loads a save with no rush fields")
	_assert(not ("unveil_rush_stacks" in GS) or int(GS.unveil_rush_stacks) == 0, "missing stacks default to zero")
	_assert(is_equal_approx(float(GS.unveil_spike_left), 0.0), "missing timer defaults to zero")
	_assert(GS.has_piece("triceratops_skull"), "old skull still loads")


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


func _test_leftover_fine_point_ranks_do_not_crash() -> void:
	_reset()
	var data := {
		"version": 1,
		"money": 10,
		"levels": {
			"precision": 5,
			"shovel_click": 1,
		},
		"pieces": {},
		"precision_on": true,
		"featured_stand_id": "",
	}
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	_assert(GS.load_game(PATH), "loads a save that still has Fine Point ranks")
	_assert(GS.money == 10, "money from the leftover save still loads")
	_assert(int(GS.levels.get("shovel_click", 0)) == 1, "real ranks still load")
	_assert(int(GS.levels.get("precision", 0)) == 0, "Fine Point ranks are ignored")


func _test_missing_file_does_not_load() -> void:
	_reset()
	_assert(not GS.has_save("user://missing_fossil_save.json"), "missing save is reported")
	_assert(not GS.load_game("user://missing_fossil_save.json"), "load fails cleanly")


func _test_reset_progress_wipes_save_and_keeps_settings() -> void:
	_reset()
	GS.money = 240
	GS.levels["shovel_click"] = 3
	GS.levels["site_size"] = 2
	GS.install_find("triceratops_skull", "Triceratops Skull", 0.8, false)
	GS.set_featured_stand("triceratops")
	_assert(GS.save_game(PATH), "writes a save to wipe")
	var settings: Node = root.get_node("Settings")
	var volume: float = float(settings.master_volume)
	settings.save_settings()
	var settings_path: String = str(settings.SETTINGS_PATH)
	_assert(FileAccess.file_exists(settings_path), "settings.cfg exists before the wipe")
	var settings_text: String = FileAccess.get_file_as_string(settings_path)
	var fired := {"reset": false}
	var cb := func() -> void: fired["reset"] = true
	GS.progress_reset.connect(cb)
	GS.reset_progress(PATH)
	GS.progress_reset.disconnect(cb)
	_assert(bool(fired["reset"]), "reset emits progress_reset")
	_assert(GS.money == 0, "money is cleared")
	_assert(int(GS.levels.get("shovel_click", 0)) == 0, "upgrades are cleared")
	_assert(int(GS.levels.get("site_size", 0)) == 0, "site ranks are cleared")
	_assert(GS.pieces.is_empty(), "museum finds are cleared")
	_assert(str(GS.featured_stand_id) == "", "spotlight is cleared")
	_assert(GS.pending_unveils.is_empty(), "unveils are cleared")
	_assert(not FileAccess.file_exists(PATH), "save.json for the wipe path is gone")
	_assert(FileAccess.file_exists(settings_path), "settings.cfg is not deleted")
	_assert(FileAccess.get_file_as_string(settings_path) == settings_text, "settings.cfg contents stay")
	_assert(is_equal_approx(float(settings.master_volume), volume), "volume setting is unchanged")
	_assert(int(root.get_node("Tuning").site_size_rank) == 0, "tuning returns to the first pit")


func _test_menu_chrome_stays_up() -> void:
	var settings: Node = root.get_node("Settings")
	_assert(settings.visible, "settings layer stays up so Menu is on every screen")
	_assert(not settings.is_open(), "the pause overlay starts closed")
	var menu: Variant = settings.get("_menu_btn")
	_assert(menu is Button, "shared Menu button lives on the settings layer")
	if menu is Button:
		_assert(str(menu.text) == "Menu", "chrome button is labeled Menu")
		_assert(bool(menu.visible), "Menu stays visible while the overlay is closed")
	var new_game: Variant = settings.get("_new_game")
	_assert(new_game is Button, "New game lives in the pause menu")
	if new_game is Button:
		_assert(str(new_game.text) == "New game", "destructive restart is labeled New game")
	var confirm: Variant = settings.get("_confirm_wrap")
	_assert(confirm is Control, "New game has a confirm step")
	if confirm is Control:
		_assert(not bool(confirm.visible), "confirm stays hidden until asked")


func TN_site_rank() -> int:
	return int(root.get_node("Tuning").site_size_rank)


func _assert(cond: bool, msg: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		push_error("FAIL: " + msg)
