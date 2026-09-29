extends SceneTree

## Teach-as-you-play tips: each shows once, in order, only when enabled, and is
## remembered in the save.
## Run: godot --headless --path <project> -s res://tests/test_hints.gd

var _failed: int = 0
var _passed: int = 0
var GS: Node
var H: Node
var ST: Node


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	GS = root.get_node("GameState")
	H = root.get_node("Hints")
	ST = root.get_node("Settings")
	var was_enabled: bool = bool(ST.tips_enabled)
	_test_tip_list_is_well_formed()
	_test_tip_wording_stays_short_everywhere()
	_test_teach_queues_once_and_in_order()
	_test_text_can_be_overridden()
	_test_unknown_and_disabled_tips_do_nothing()
	_test_reset_brings_tips_back()
	_test_seen_tips_are_saved()
	_test_setting_is_saved(was_enabled)
	_test_ribbon_holds_a_tip_long_enough_to_read()
	ST.tips_enabled = was_enabled
	_reset()
	print("hints %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _reset() -> void:
	H.pending.clear()
	for key in GS.hints_seen.keys():
		if str(key).begins_with("tip_"):
			GS.hints_seen.erase(key)
	ST.tips_enabled = true


func _test_tip_list_is_well_formed() -> void:
	var ids: Dictionary = {}
	var ok: bool = true
	var long_one: String = ""
	for tip in H.TIPS:
		var id: String = str(tip.get("id", ""))
		if id.is_empty() or ids.has(id) or str(tip.get("title", "")).is_empty() or str(tip.get("text", "")).is_empty():
			ok = false
		if not _fits_one_line(str(tip.get("text", ""))):
			long_one = id
		ids[id] = true
	_assert(ok, "every tip has a unique id, a title and text")
	_assert(long_one.is_empty(), "every tip fits on one line of the ribbon (%s)" % long_one)
	_assert(H.TIPS.size() >= 10, "there are tips for the main ideas")
	for id in ["dig", "sifted", "pocket", "collect", "shop", "museum", "ribbon", "complete", "cart"]:
		_assert(not H.tip_data(id).is_empty(), "there is a '%s' tip" % id)


## One line of the ribbon (it wraps at RewardRibbon.SUB_MAX_W at 13pt).
func _fits_one_line(text: String) -> bool:
	var font: Font = (load("res://ui_style.gd") as GDScript).call("display_font")
	var consts: Dictionary = (load("res://reward_ribbon.gd") as GDScript).get_script_constant_map()
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(consts["SUB_SIZE"])).x <= float(consts["SUB_MAX_W"]) - 20.0


func _test_tip_wording_stays_short_everywhere() -> void:
	## The wording that depends on what you own lives in main.gd: check it too.
	var main_src: String = FileAccess.get_file_as_string("res://main.gd")
	var found: int = 0
	var too_long: String = ""
	var pattern: RegEx = RegEx.create_from_string("Hints\\.teach\\(\"\\w+\", \"([^\"]+)\"\\)")
	for hit in pattern.search_all(main_src):
		found += 1
		if not _fits_one_line(hit.get_string(1)):
			too_long = hit.get_string(1)
	_assert(found >= 2, "the owned-item tip wordings are found in main.gd")
	_assert(too_long.is_empty(), "they fit on one line too (%s)" % too_long)
	var main_hold: RegEx = RegEx.create_from_string("const HINT_HOLD := ([0-9.]+)")
	var hold: RegExMatch = main_hold.search(main_src)
	_assert(hold != null and float(hold.get_string(1)) >= 10.0, "tips stay up long enough to read")


func _test_teach_queues_once_and_in_order() -> void:
	_reset()
	_assert(bool(H.teach("dig")), "a new tip is queued")
	_assert(not bool(H.teach("dig")), "asking again while it waits does nothing")
	_assert(bool(H.teach("shop")), "another tip queues behind it")
	_assert(H.pending.size() == 2, "two tips are waiting")
	var first: Dictionary = H.next_tip()
	_assert(str(first["id"]) == "dig" and not str(first["title"]).is_empty() and not str(first["text"]).is_empty(), "tips come out in the order they were asked for")
	_assert(bool(H.seen("dig")), "a shown tip is marked seen")
	_assert(not bool(H.teach("dig")), "a shown tip never comes back")
	_assert(str(H.next_tip()["id"]) == "shop", "the next one follows")
	_assert(H.next_tip().is_empty(), "nothing left")
	_assert(not bool(H.seen("museum")), "a tip that was never asked for is not seen")


func _test_text_can_be_overridden() -> void:
	_reset()
	H.teach("dirty", "Custom wording")
	_assert(str(H.next_tip()["text"]) == "Custom wording", "a tip can use text that fits what the player owns")
	H.teach("museum")
	_assert(str(H.next_tip()["text"]) == str(H.tip_data("museum")["text"]), "without an override the default text is used")


func _test_unknown_and_disabled_tips_do_nothing() -> void:
	_reset()
	_assert(not bool(H.teach("no_such_tip")), "an unknown tip is ignored")
	ST.tips_enabled = false
	_assert(not bool(H.teach("dig")), "nothing is queued while tips are off")
	_assert(H.pending.is_empty(), "the queue stays empty")
	_assert(not bool(H.seen("dig")), "and it is not marked seen, so it can still show later")
	ST.tips_enabled = true
	_assert(bool(H.teach("dig")), "turning tips back on lets it through")
	_reset()


func _test_reset_brings_tips_back() -> void:
	_reset()
	H.teach("dig")
	H.next_tip()
	H.teach("shop")
	_assert(bool(H.seen("dig")) and not H.pending.is_empty(), "one seen, one waiting")
	H.reset_seen()
	_assert(not bool(H.seen("dig")) and H.pending.is_empty(), "'show tips again' clears both")
	_assert(bool(H.teach("dig")), "a reset tip can be taught again")
	_reset()


func _test_seen_tips_are_saved() -> void:
	_reset()
	H.teach("dig")
	H.next_tip()
	var path: String = "user://test_hints_save.json"
	GS.save_game(path)
	_reset()
	_assert(not bool(H.seen("dig")), "cleared before loading")
	GS.load_game(path)
	_assert(bool(H.seen("dig")), "a tip that was shown stays shown after loading")
	_assert(not bool(H.teach("dig")), "so it is not taught twice")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_reset()


func _test_setting_is_saved(original: bool) -> void:
	ST.tips_enabled = not original
	ST.save_settings()
	ST.tips_enabled = original
	ST.load_settings()
	_assert(bool(ST.tips_enabled) == (not original), "the Show tips setting is saved and loaded")
	ST.tips_enabled = original
	ST.save_settings()


func _test_ribbon_holds_a_tip_long_enough_to_read() -> void:
	var ribbon: Control = (load("res://reward_ribbon.gd") as GDScript).new()
	root.add_child(ribbon)
	ribbon.show_reward("Tip", "Some helpful words", 0, 1, Vector2(640, 600))
	var short_life: float = float(ribbon.get("_life"))
	ribbon.set("_life", 0.0)
	ribbon.visible = false
	ribbon.show_reward("Tip", "Some helpful words", 0, 1, Vector2(640, 600), -1, 8.0)
	_assert(float(ribbon.get("_life")) >= 8.0 and float(ribbon.get("_life")) > short_life, "a tip stays up longer than a normal ribbon")
	ribbon.queue_free()


func _assert(ok: bool, label: String) -> void:
	if ok:
		_passed += 1
		print("PASS  %s" % label)
	else:
		_failed += 1
		print("FAIL  %s" % label)
