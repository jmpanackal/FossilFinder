extends SceneTree

## Title shows before a shift. Start leaves it.
## Run: godot --headless --path <project> -s res://tests/test_title_screen.gd

var _failed: int = 0
var _passed: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_boot_shows_title_before_a_shift()
	_test_start_leaves_title_and_begins_dig()
	_test_title_copy_is_field_site_not_feast()
	_test_settings_from_title_returns_to_title()
	_test_menu_stays_available_after_start()
	_test_title_hides_the_bank()
	print("title_screen %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _test_boot_shows_title_before_a_shift() -> void:
	var main: Node = _boot_main()
	if main == null:
		return
	var title: Node = main.get_node_or_null("Title")
	_assert(title != null, "main has a Title screen")
	if title == null:
		main.free()
		return
	_assert(bool(title.visible), "title is up on boot")
	_assert(str(main.screen) == "title", "boot screen is title, not dig")
	_assert(not bool(main.round_active), "a shift does not start under the title")
	var start: Variant = title.get("_start")
	var settings: Variant = title.get("_settings")
	var exit_btn: Variant = title.get("_exit")
	_assert(start is Button and str(start.text) == "Start", "title offers Start")
	_assert(settings is Button and str(settings.text) == "Settings", "title offers Settings")
	_assert(exit_btn is Button and str(exit_btn.text) == "Exit", "title offers Exit")
	main.free()


func _test_start_leaves_title_and_begins_dig() -> void:
	var main: Node = _boot_main()
	if main == null:
		return
	var title: Node = main.get_node_or_null("Title")
	_assert(title != null, "title exists so Start can leave it")
	if title == null:
		main.free()
		return
	var start: Variant = title.get("_start")
	_assert(start is Button, "Start is a button")
	if start is Button:
		start.pressed.emit()
	_assert(not bool(title.visible), "Start hides the title")
	_assert(str(main.screen) == "dig", "Start enters the dig")
	_assert(bool(main.round_active), "Start begins a shift")
	var hud: Node = main.get_node_or_null("HUD")
	_assert(hud == null or bool(hud.visible), "HUD is available once the shift starts")
	main.free()


func _test_title_copy_is_field_site_not_feast() -> void:
	var main: Node = _boot_main()
	if main == null:
		return
	var title: Node = main.get_node_or_null("Title")
	_assert(title != null, "title screen is present")
	if title == null:
		main.free()
		return
	var name_label: Variant = title.get("_title")
	_assert(name_label is Label, "title has a name label")
	if name_label is Label:
		_assert(str(name_label.text) == "Fossil Finder", "game name is Fossil Finder")
		_assert(str(name_label.text).find("FEAST") < 0, "title does not steal FEAST's name")
	var src: String = FileAccess.get_file_as_string("res://title_screen.gd")
	_assert(src.find("site_backdrop") >= 0 or src.find("SiteBackdrop") >= 0 or src.find("Ui.apply_field") >= 0, "title reuses field-site chrome")
	_assert(src.find("LibreBaskerville") >= 0 or src.find("Ui.apply") >= 0, "title uses the catalog type")
	_assert(src.find("FEAST") < 0, "title script does not mention FEAST")
	main.free()


func _test_settings_from_title_returns_to_title() -> void:
	var main: Node = _boot_main()
	if main == null:
		return
	var title: Node = main.get_node_or_null("Title")
	var settings: Node = root.get_node("Settings")
	_assert(title != null, "title is present for Settings")
	if title == null:
		main.free()
		return
	var settings_btn: Variant = title.get("_settings")
	_assert(settings_btn is Button, "Settings is a title button")
	if settings_btn is Button:
		settings_btn.pressed.emit()
	_assert(bool(settings.is_open()), "title Settings opens the existing overlay")
	_assert(bool(title.visible), "title stays up under Settings")
	settings.close_menu()
	_assert(not bool(settings.is_open()), "closing Settings leaves the overlay")
	_assert(bool(title.visible), "closing Settings returns to title")
	_assert(not bool(main.round_active), "Settings from title does not start a shift")
	main.free()


func _test_menu_stays_available_after_start() -> void:
	var main: Node = _boot_main()
	if main == null:
		return
	var title: Node = main.get_node_or_null("Title")
	var settings: Node = root.get_node("Settings")
	if title != null:
		var start: Variant = title.get("_start")
		if start is Button:
			start.pressed.emit()
	var hud: Node = main.get_node_or_null("HUD")
	_assert(hud == null or hud.get("_menu_btn") == null, "the dig HUD does not host a second Menu")
	var settings_menu: Variant = settings.get("_menu_btn")
	_assert(settings_menu is Button, "Menu sits on the shared header after Start")
	if settings_menu is Button:
		_assert(bool(settings_menu.visible), "Menu stays available after Start")
		_assert(str(settings_menu.text) == "Menu", "in-game chrome is still Menu")
	var settings_back: Variant = settings.get("_back_btn")
	_assert(settings_back is Button and bool(settings_back.visible), "Back stays available after Start")
	main.free()


func _test_title_hides_the_bank() -> void:
	var main: Node = _boot_main()
	if main == null:
		return
	var settings: Node = root.get_node("Settings")
	var wallet: CanvasItem = settings.get("_wallet") as CanvasItem
	_assert(wallet != null, "Settings hosts the one bank")
	if wallet != null:
		_assert(not bool(wallet.visible), "title hides the bank")
	_assert(not bool((settings.get("_menu_btn") as CanvasItem).visible) if settings.get("_menu_btn") != null else true, "title hides Menu")
	_assert(not bool((settings.get("_back_btn") as CanvasItem).visible) if settings.get("_back_btn") != null else true, "title hides Back")
	main.free()


func _boot_main() -> Node:
	var packed: PackedScene = load("res://main.tscn") as PackedScene
	_assert(packed != null, "main.tscn loads")
	if packed == null:
		return null
	var main: Node = packed.instantiate()
	root.add_child(main)
	return main


func _assert(ok: bool, label: String) -> void:
	if ok:
		_passed += 1
		print("PASS  %s" % label)
	else:
		_failed += 1
		print("FAIL  %s" % label)
