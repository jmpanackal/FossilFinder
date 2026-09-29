extends SceneTree

## A find banner says which bone it is about: the bone's picture and its name,
## not just "Great condition!".
## Run: godot --headless --path <project> -s res://tests/test_condition_banner.gd

var _failed: int = 0
var _passed: int = 0
var TN: Node


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	TN = root.get_node("Tuning")
	var settings: Node = root.get_node("Settings")
	var was_enabled: bool = bool(settings.tips_enabled)
	settings.tips_enabled = false
	await _test_ribbon_shows_a_bone_icon_and_name()
	await _test_real_banners_name_their_bone()
	settings.tips_enabled = was_enabled
	print("condition_banner %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _reset_ribbon(ribbon: Control) -> void:
	ribbon.set("_life", 0.0)
	ribbon.visible = false
	(ribbon.get("_queue") as Array).clear()


func _test_ribbon_shows_a_bone_icon_and_name() -> void:
	var hud: CanvasLayer = (load("res://hud.gd") as GDScript).new()
	root.add_child(hud)
	await process_frame
	var ribbon: Control = hud.call("ribbon")
	hud.call("celebrate", -1, "Great condition!", "", 4, 2)
	await process_frame
	var plain_w: float = ribbon.size.x
	_assert(str(ribbon.get("subject")) == "" and float(ribbon.get("_icon_w")) == 0.0, "a plain banner has no bone picture or name")
	_reset_ribbon(ribbon)
	hud.call("celebrate", -1, "Great condition!", "", 4, 2, 0.0, "T. rex Tooth", "t_rex_tooth")
	await process_frame
	_assert(str(ribbon.get("subject")) == "T. rex Tooth", "the banner carries the bone's name")
	_assert(float(ribbon.get("_icon_w")) > 0.0, "and makes room for its picture")
	_assert(ribbon.size.x > plain_w, "so it is wider than the plain banner")
	_assert(ribbon.size.y >= float(ribbon.get("ICON_H")) + 2.0 * float(ribbon.get("PAD").y) - 0.5, "tall enough for the picture")
	_assert(ribbon.position.x >= 0.0 and ribbon.position.x + ribbon.size.x <= float(TN.view_w), "and still on screen")
	_assert(ribbon.position.y >= float(TN.pit_face_bottom()) + float(TN.pit_front_h()), "and still clear of the pit")
	hud.queue_free()


func _test_real_banners_name_their_bone() -> void:
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main._begin_from_title()
	for _i in 4:
		await process_frame
	var site: Node = main.dig_site
	_assert(site.finds.size() > 0, "the pit hides at least one bone")
	if site.finds.is_empty():
		main.queue_free()
		return
	var ribbon: Control = main.hud.call("ribbon")
	var find: Dictionary = site.finds[0]
	var expected_name: String = str(find["data"].name)
	var expected_id: String = str(find.get("piece_id", ""))
	_reset_ribbon(ribbon)
	main._on_condition_revealed(0, 4, Vector2(600, 300))
	_assert(str(ribbon.get("title")).begins_with("Great"), "the condition banner still leads with the condition")
	_assert(str(ribbon.get("subject")) == expected_name, "the condition banner names the bone (%s)" % expected_name)
	_assert(str(ribbon.get("_piece_id")) == expected_id and not expected_id.is_empty(), "and shows that bone's picture")
	_reset_ribbon(ribbon)
	main._on_bone_kind_seen(0, TN.BONE_FRAGILE, Vector2(600, 300))
	_assert(str(ribbon.get("subject")) == expected_name, "the Fragile/Opal banner names the bone too")
	_reset_ribbon(ribbon)
	main._on_condition_revealed(-1, 3, Vector2(600, 300))
	_assert(str(ribbon.get("subject")) == "" and float(ribbon.get("_icon_w")) == 0.0, "a banner with no bone behind it stays plain")
	main.queue_free()


func _assert(ok: bool, label: String) -> void:
	if ok:
		_passed += 1
		print("PASS  %s" % label)
	else:
		_failed += 1
		print("FAIL  %s" % label)
