extends SceneTree

## The Settings panel hugs its contents: opening and closing the "Erase save?"
## confirmation must not blow it up past the screen.
## Run: godot --headless --path <project> -s res://tests/test_settings_menu.gd

var _failed: int = 0
var _passed: int = 0
var ST: Node


func _init() -> void:
	call_deferred("_run")


func _height(panel: Panel) -> float:
	return panel.offset_bottom - panel.offset_top


func _run() -> void:
	ST = root.get_node("Settings")
	ST.open_menu()
	for _i in 4:
		await process_frame
	var panel: Panel = ST._menu_panel
	var box: VBoxContainer = ST._menu_box
	var closed_h: float = _height(panel)
	_assert(closed_h <= box.get_combined_minimum_size().y + 40.0, "the menu hugs its contents (%.0f for %.0f)" % [closed_h, box.get_combined_minimum_size().y])
	_assert(closed_h < 720.0, "and fits the screen with the tips row in it")
	_assert(ST._tips != null and ST._tips.text == "Show tips", "the menu has a Show tips switch")
	ST._on_new_game_pressed()
	for _i in 4:
		await process_frame
	var confirm_h: float = _height(panel)
	_assert(bool(ST._confirm_wrap.visible), "the erase confirmation is showing")
	_assert(confirm_h <= box.get_combined_minimum_size().y + 40.0, "the confirmation does not blow the panel up (%.0f for %.0f)" % [confirm_h, box.get_combined_minimum_size().y])
	_assert(confirm_h < 720.0, "and it still fits the screen")
	_assert(confirm_h > closed_h - 60.0, "the confirmation adds its rows without collapsing the panel")
	ST._hide_new_game_confirm()
	for _i in 4:
		await process_frame
	_assert(absf(_height(panel) - closed_h) <= 4.0, "cancelling puts the panel back to its size")
	ST.close_menu()
	print("settings_menu %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _assert(ok: bool, label: String) -> void:
	if ok:
		_passed += 1
		print("PASS  %s" % label)
	else:
		_failed += 1
		print("FAIL  %s" % label)
