extends SceneTree

## Hands feel for buried bone; the brush rewards back-and-forth scrubbing.
## Run: godot --headless --path <project> -s res://tests/test_hands_brush.gd

var _failed: int = 0
var _passed: int = 0
var GS: Node
var TN: Node


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	GS = root.get_node("GameState")
	TN = root.get_node("Tuning")
	_test_sense_radius_scales_with_hands_upgrades()
	_test_hands_sense_marks_nearby_bone_only()
	_test_shovel_does_not_sense()
	_test_scrub_reversals_build_combo()
	_test_combo_speeds_cleaning()
	_test_bristle_reach_cleans_neighbors()
	_reset()
	print("hands_brush %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _reset() -> void:
	GS.pieces.clear()
	GS.money = 0
	for item in GS.catalog:
		GS.levels[item["id"]] = 0
	GS.apply_upgrades()


func _make_site() -> Node2D:
	var script: GDScript = load("res://dig_site.gd") as GDScript
	var site: Node2D = script.new()
	root.add_child(site)
	return site


func _flatten(site: Node2D, bone: Vector2i) -> void:
	## Sunk bone cells sit behind the row in front; level the pit so aim is exact.
	var layer: int = int(site.finds[int(site.fossil_cells[bone])]["layer"])
	for x in int(TN.grid_w):
		for y in int(TN.grid_h):
			site._top_layer[x][y] = layer


func _first_bone(site: Node2D) -> Vector2i:
	for raw in site.fossil_cells:
		return raw
	return Vector2i(-1, -1)


func _test_sense_radius_scales_with_hands_upgrades() -> void:
	_reset()
	_assert(float(TN.hands_sense_radius) <= 0.0, "bare hands cannot feel for bone")
	GS.levels["hands_click"] = 5
	GS.apply_upgrades()
	_assert(float(TN.hands_sense_radius) <= 0.0, "Calloused Fingers alone does not grant Bone Sense")
	GS.levels["hands_sense"] = 1
	GS.apply_upgrades()
	var base: float = float(TN.hands_sense_radius)
	_assert(base >= 1.0, "Bone Sense rank 1 feels the neighboring cells")
	GS.levels["hands_sense"] = 4
	GS.levels["hands_craft"] = 6
	GS.apply_upgrades()
	_assert(float(TN.hands_sense_radius) >= base + 3.0, "maxed Bone Sense + Fieldcraft survey a wide patch")
	_assert(str(GS.shop_effect_line("hands_sense")).find("cells") >= 0, "Bone Sense shop line names the reach")


func _test_hands_sense_marks_nearby_bone_only() -> void:
	_reset()
	var bare := _make_site()
	bare.call("_sense_bone", _first_bone(bare))
	_assert(bare.sensed_cells.is_empty(), "without Bone Sense, hands mark nothing")
	bare.queue_free()
	GS.levels["hands_sense"] = 1
	GS.apply_upgrades()
	var site := _make_site()
	var bone: Vector2i = _first_bone(site)
	_assert(bone.x >= 0, "the pit hides a bone")
	site.set("current_tool", TN.TOOL_HANDS)
	site.call("_sense_bone", bone)
	_assert(bool(site.call("is_sensed", bone)), "hands over bone feel it")
	var far_hit: bool = false
	for raw in site.sensed_cells:
		var cell: Vector2i = raw
		if Vector2(cell).distance_to(Vector2(bone)) > float(TN.hands_sense_radius) + 0.01:
			far_hit = true
		if not site.fossil_cells.has(cell):
			far_hit = true
	_assert(not far_hit, "sense only marks bone cells inside the radius")
	site.call("_reveal_fossil_cell", bone)
	_assert(not bool(site.call("is_sensed", bone)), "exposed bone drops the sense marker")
	site.call("start_round")
	_assert(site.sensed_cells.is_empty(), "a new shift clears sensed cells")
	site.queue_free()


func _test_shovel_does_not_sense() -> void:
	_reset()
	GS.levels["shovel_click"] = 1
	GS.apply_upgrades()
	var site := _make_site()
	var bone: Vector2i = _first_bone(site)
	site.set("current_tool", TN.TOOL_SHOVEL)
	site.call("_apply_shovel", bone, 1.0, true)
	_assert(site.sensed_cells.is_empty(), "the shovel does not feel for bone")
	site.queue_free()


func _test_scrub_reversals_build_combo() -> void:
	_reset()
	var site := _make_site()
	var bone: Vector2i = _first_bone(site)
	site.call("_reveal_fossil_cell", bone)
	_assert(int(site.call("brush_combo_level")) == 0, "combo starts at zero")
	for i in 3:
		site.call("_track_scrub", Vector2(20, 0))
		site.call("_track_scrub", Vector2(-20, 0))
	_assert(int(site.call("brush_combo_level")) >= 3, "back-and-forth strokes build a combo")
	var cap: int = int(TN.brush_combo_max)
	for i in 20:
		site.call("_track_scrub", Vector2(20, 0))
		site.call("_track_scrub", Vector2(-20, 0))
	_assert(int(site.call("brush_combo_level")) == cap, "combo caps at brush_combo_max")
	_assert(float(site.call("brush_scrub_mult")) > 1.5, "a full combo cleans much faster")
	site.call("_tick_brush_combo", 2.0)
	_assert(int(site.call("brush_combo_level")) == 0, "stopping the scrub lets the combo fade")
	site.queue_free()


func _test_combo_speeds_cleaning() -> void:
	_reset()
	var site := _make_site()
	var bone: Vector2i = _first_bone(site)
	site.call("_reveal_fossil_cell", bone)
	_flatten(site, bone)
	var center: Vector2 = site.call("cell_center", bone)
	site.call("_apply_brush", center, 10.0)
	var slow: float = float(site.cleanliness.get(bone, 0.0))
	site.cleanliness[bone] = 0.0
	for i in 4:
		site.call("_track_scrub", Vector2(20, 0))
		site.call("_track_scrub", Vector2(-20, 0))
	site.call("_apply_brush", center, 10.0)
	var fast: float = float(site.cleanliness.get(bone, 0.0))
	_assert(slow > 0.0, "a brush stroke cleans the bone")
	_assert(fast > slow * 1.5, "a scrub combo cleans faster than a single stroke")
	site.queue_free()


func _test_bristle_reach_cleans_neighbors() -> void:
	_reset()
	var site := _make_site()
	var bone: Vector2i = _first_bone(site)
	var neighbor := bone + Vector2i(1, 0)
	if neighbor.x >= int(TN.grid_w):
		neighbor = bone - Vector2i(1, 0)
	site.fossil_cells[neighbor] = site.fossil_cells[bone]
	site.exposed_cells[bone] = true
	site.exposed_cells[neighbor] = true
	site.cleanliness[bone] = 0.0
	site.cleanliness[neighbor] = 0.0
	_flatten(site, bone)
	var center: Vector2 = site.call("cell_center", bone)
	TN.brush_reach_px = 0.0
	site.call("_apply_brush", center, 10.0)
	_assert(float(site.cleanliness[neighbor]) == 0.0, "base bristles clean one cell")
	GS.levels["brush_speed"] = 3
	GS.apply_upgrades()
	var edge := center.lerp(site.call("cell_center", neighbor), 0.45)
	TN.brush_reach_px = maxf(float(TN.brush_reach_px), 40.0)
	site.call("_apply_brush", edge, 10.0)
	_assert(float(site.cleanliness[neighbor]) > 0.0, "upgraded bristles reach the next bone cell")
	site.queue_free()


func _assert(ok: bool, label: String) -> void:
	if ok:
		_passed += 1
		print("PASS  %s" % label)
	else:
		_failed += 1
		print("FAIL  %s" % label)
