extends SceneTree

## Fragile and opal bones crumble in open air; a Plaster Cast (Hands
## upgrade) wraps a dug-out bone so it stops crumbling and is collected.
## Run: godot --headless --path <project> -s res://tests/test_crumble_cast.gd

var _failed: int = 0
var _passed: int = 0
var GS: Node
var TN: Node


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	GS = root.get_node("GameState")
	TN = root.get_node("Tuning")
	_test_kinds_roll_mostly_solid()
	_test_solid_bones_never_crumble()
	_test_fragile_bone_crumbles_in_open_air()
	_test_buried_bones_do_not_crumble()
	_test_gold_crumbles_faster_and_is_worth_more()
	_test_crumbling_stops_at_poor()
	_test_cast_needs_the_upgrade()
	_test_cast_stops_crumbling_and_collects()
	_test_cast_upgrade_is_faster_per_rank()
	_test_plain_names_and_hints()
	_reset()
	print("crumble_cast %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _reset() -> void:
	GS.pieces.clear()
	GS.money = 0
	for item in GS.catalog:
		GS.levels[item["id"]] = 0
	GS.apply_upgrades()


func _site_with(kind: int, condition: int = 4) -> Node2D:
	var script: GDScript = load("res://dig_site.gd") as GDScript
	var site: Node2D = script.new()
	root.add_child(site)
	var find: Dictionary = site.finds[0]
	find["kind"] = kind
	find["condition"] = condition
	return site


func _expose_all(site: Node2D) -> void:
	for cell in (site.finds[0]["cells"] as Dictionary).keys():
		site.call("_reveal_fossil_cell", cell)


func _test_kinds_roll_mostly_solid() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var counts := [0, 0, 0]
	for i in 3000:
		counts[int(TN.roll_bone_kind(rng))] += 1
	_assert(counts[0] > counts[1] and counts[1] > counts[2], "solid > fragile > opal")
	_assert(counts[2] > 0, "opal does turn up")


func _test_solid_bones_never_crumble() -> void:
	_reset()
	var site := _site_with(TN.BONE_SOLID)
	_expose_all(site)
	site.call("tick_crumble", 120.0)
	_assert(int(site.finds[0]["condition"]) == 4, "solid bones keep their condition in open air")
	_assert(float(site.call("crumble_in", site.finds[0])) == INF, "solid bones show no timer")
	site.queue_free()


func _test_fragile_bone_crumbles_in_open_air() -> void:
	_reset()
	var site := _site_with(TN.BONE_FRAGILE, 5)
	var events: Array = []
	site.bone_crumbled.connect(func(i: int, c: int, _p: Vector2) -> void: events.append(c))
	site.call("_reveal_fossil_cell", (site.finds[0]["cells"] as Dictionary).keys()[0])
	var first: float = float(TN.crumble_first[TN.BONE_FRAGILE])
	_assert(absf(float(site.call("crumble_in", site.finds[0])) - first) < 0.01, "timer starts at the first-crumble delay")
	site.call("tick_crumble", first - 0.5)
	_assert(int(site.finds[0]["condition"]) == 5, "no crumble before the delay")
	site.call("tick_crumble", 1.0)
	_assert(int(site.finds[0]["condition"]) == 4, "one step lost after the delay")
	site.call("tick_crumble", float(TN.crumble_step[TN.BONE_FRAGILE]))
	_assert(int(site.finds[0]["condition"]) == 3, "another step after each interval")
	_assert(events == [4, 3], "each crumble is announced")
	site.queue_free()


func _test_buried_bones_do_not_crumble() -> void:
	_reset()
	var site := _site_with(TN.BONE_FRAGILE, 5)
	site.call("tick_crumble", 200.0)
	_assert(int(site.finds[0]["condition"]) == 5, "bones still in the ground are safe")
	site.queue_free()


func _test_gold_crumbles_faster_and_is_worth_more() -> void:
	_assert(float(TN.crumble_first[TN.BONE_OPAL]) < float(TN.crumble_first[TN.BONE_FRAGILE]), "opal crumbles sooner than fragile bone")
	_reset()
	var site := _site_with(TN.BONE_SOLID, 3)
	var solid: int = int(site.call("_find_preview_value", site.finds[0]))
	site.finds[0]["kind"] = TN.BONE_OPAL
	var gold: int = int(site.call("_find_preview_value", site.finds[0]))
	_assert(gold >= solid * 2, "opal is worth at least double")
	site.queue_free()


func _test_crumbling_stops_at_poor() -> void:
	_reset()
	var site := _site_with(TN.BONE_OPAL, 2)
	_expose_all(site)
	site.call("tick_crumble", 500.0)
	_assert(int(site.finds[0]["condition"]) == 1, "crumbling bottoms out at Poor")
	_assert(float(site.call("crumble_in", site.finds[0])) == INF, "a Poor bone shows no timer")
	site.queue_free()


func _test_cast_needs_the_upgrade() -> void:
	_reset()
	_assert(not bool(TN.cast_owned()), "no Plaster Cast without the upgrade")
	var site2 := _site_with(TN.BONE_FRAGILE)
	_expose_all(site2)
	site2.set("current_tool", TN.TOOL_HANDS)
	var cell: Vector2i = (site2.finds[0]["cells"] as Dictionary).keys()[0]
	site2.call("_tick_cast", 5.0, true, cell)
	_assert(not bool(site2.finds[0]["cast"]), "holding Hands does nothing without the upgrade")
	site2.queue_free()


func _test_cast_stops_crumbling_and_collects() -> void:
	_reset()
	GS.levels["hands_cast"] = 1
	GS.apply_upgrades()
	var site := _site_with(TN.BONE_FRAGILE, 5)
	var cast_events: Array = []
	site.bone_cast.connect(func(i: int, _p: Vector2) -> void: cast_events.append(i))
	var cell: Vector2i = (site.finds[0]["cells"] as Dictionary).keys()[0]
	site.call("_reveal_fossil_cell", cell)
	site.set("current_tool", TN.TOOL_HANDS)
	if (site.finds[0]["cells"] as Dictionary).size() > 1:
		site.call("_tick_cast", 5.0, true, cell)
		_assert(not bool(site.finds[0]["cast"]), "a half-dug bone cannot be cast")
	_expose_all(site)
	site.call("_tick_cast", float(TN.cast_hold_seconds()) * 0.5, true, cell)
	_assert(float(site.call("cast_progress")) > 0.3, "holding fills the cast ring")
	site.set("current_tool", TN.TOOL_SHOVEL)
	site.call("_tick_cast", 0.1, true, cell)
	_assert(float(site.call("cast_progress")) == 0.0, "only Hands can wrap a cast")
	site.set("current_tool", TN.TOOL_HANDS)
	site.call("_tick_cast", float(TN.cast_hold_seconds()) + 0.1, true, cell)
	_assert(bool(site.finds[0]["cast"]), "holding long enough wraps the bone")
	_assert(bool(site.finds[0]["extracted"]), "a cast bone is collected right away")
	_assert(cast_events == [0], "the cast is announced")
	site.call("tick_crumble", 300.0)
	_assert(int(site.finds[0]["condition"]) == 5, "a cast bone never crumbles")
	site.queue_free()


func _test_cast_upgrade_is_faster_per_rank() -> void:
	_reset()
	GS.levels["hands_cast"] = 1
	GS.apply_upgrades()
	var slow: float = float(TN.cast_hold_seconds())
	GS.levels["hands_cast"] = 3
	GS.apply_upgrades()
	_assert(float(TN.cast_hold_seconds()) < slow, "more ranks wrap faster")
	GS.levels["hands_cast"] = 0
	GS.apply_upgrades()
	_assert(str(GS.shop_effect_line("hands_cast")).contains("Wrap"), "shop line explains the wrap in plain words")


func _test_plain_names_and_hints() -> void:
	_assert(str(TN.bone_kind_name(TN.BONE_FRAGILE)) == "Fragile", "fragile bones are just called Fragile")
	_assert(str(TN.bone_kind_name(TN.BONE_OPAL)) == "Opal", "gem bones are called Opal")
	_assert(str(TN.BONE_KIND_HINTS[TN.BONE_FRAGILE]).contains("loses a star"), "the fragile hint says it loses stars")
	var item: Dictionary = {}
	for entry in GS.catalog:
		if str(entry["id"]) == "hands_cast":
			item = entry
	_assert(str(item.get("unlock_desc", "")).contains("broken arm"), "Plaster Cast is explained with an everyday comparison")


func _assert(ok: bool, label: String) -> void:
	if ok:
		_passed += 1
		print("PASS  %s" % label)
	else:
		_failed += 1
		print("FAIL  %s" % label)
