extends SceneTree

## Fossils never sit directly behind/in front of another (the pit's
## perspective would hide one), extra fossils are a chain of chances, a
## collected bone reveals the dirt layer under it, and deeper bones come out
## in better shape.
## Run: godot --headless --path <project> -s res://tests/test_fossil_placement.gd

var _failed: int = 0
var _passed: int = 0
var GS: Node
var TN: Node


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	GS = root.get_node("GameState")
	TN = root.get_node("Tuning")
	_reset()
	_test_no_vertical_neighbors()
	_test_extra_fossils_are_a_chance_chain()
	_test_deeper_is_better()
	_test_collected_bone_shows_the_layer_below()
	_reset()
	print("fossil_placement %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _reset() -> void:
	GS.pieces.clear()
	GS.money = 0
	for item in GS.catalog:
		GS.levels[item["id"]] = 0
	GS.apply_upgrades()


func _test_no_vertical_neighbors() -> void:
	GS.levels["scrap_bed"] = 2
	GS.levels["rich_bed"] = 3
	GS.levels["prime_bed"] = 4
	GS.levels["site_size"] = 3
	GS.apply_upgrades()
	var script: GDScript = load("res://dig_site.gd") as GDScript
	var clashes: int = 0
	var multi: int = 0
	for i in 30:
		var site: Node2D = script.new()
		root.add_child(site)
		if site.finds.size() > 1:
			multi += 1
		for raw in site.fossil_cells:
			var cell: Vector2i = raw
			var own: int = int(site.fossil_cells[cell])
			for dy in [-1, 1]:
				var other: Vector2i = cell + Vector2i(0, dy)
				if site.fossil_cells.has(other) and int(site.fossil_cells[other]) != own:
					clashes += 1
		site.free()
	_assert(multi > 0, "sites with extra-fossil upgrades do get several fossils")
	_assert(clashes == 0, "no fossil sits directly above or below another")
	_reset()


func _test_extra_fossils_are_a_chance_chain() -> void:
	_assert(float(TN.extra_find_chance) == 0.0, "no extra fossils before the upgrade")
	GS.levels["scrap_bed"] = 1
	GS.apply_upgrades()
	var low: float = float(TN.extra_find_chance)
	_assert(low > 0.0 and low < 1.0, "the upgrade gives a chance, not a fixed count")
	_assert(int(TN.extra_find_slots) >= 3, "a lucky pit can hold several extras")
	GS.levels["scrap_bed"] = 2
	GS.apply_upgrades()
	_assert(float(TN.extra_find_chance) > low, "more ranks raise the odds")
	_assert(str(GS.shop_effect_line("rich_bed")).contains("odds") or str(GS.shop_effect_line("rich_bed")).contains("large"), "shop line talks about odds")
	_reset()


func _test_deeper_is_better() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var shallow: float = 0.0
	var deep: float = 0.0
	for i in 2000:
		shallow += float(TN.roll_condition(rng, TN.depth_frac(2) * TN.depth_condition_luck))
		deep += float(TN.roll_condition(rng, TN.depth_frac(20) * TN.depth_condition_luck))
	_assert(deep > shallow * 1.05, "bones deep in the pit come out in better shape")


func _test_collected_bone_shows_the_layer_below() -> void:
	var script: GDScript = load("res://dig_site.gd") as GDScript
	var site: Node2D = script.new()
	root.add_child(site)
	var find: Dictionary = site.finds[0]
	for c in find["cells"]:
		site.call("_reveal_fossil_cell", c)
	site.call("extract_now", false)
	var cell: Vector2i = (find["cells"] as Dictionary).keys()[0]
	_assert(bool(find["extracted"]), "the bone was collected")
	_assert(int(site._top_layer[cell.x][cell.y]) == mini(int(find["layer"]) + 1, int(TN.layer_count) - 1), "the dirt layer under it shows")
	var face: Color = site.call("_cell_face_color", cell.x, cell.y)
	_assert(face.is_equal_approx(TN.color_for_layer(int(site._top_layer[cell.x][cell.y])).darkened(0.32)), "its column side is plain dirt, not bone")
	site.free()


func _assert(ok: bool, label: String) -> void:
	if ok:
		_passed += 1
		print("PASS  %s" % label)
	else:
		_failed += 1
		print("FAIL  %s" % label)
