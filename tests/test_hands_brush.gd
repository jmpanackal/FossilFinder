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
	_test_uncovered_bone_starts_caked()
	_test_stroke_wipes_only_along_its_path()
	_test_weak_bristles_need_more_passes()
	_test_wiping_everything_cleans_and_bags_the_bone()
	_test_brush_upgrades_widen_the_bristles()
	_test_deeper_bones_have_more_layers()
	_test_slow_drags_do_not_clean_extra()
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


func _dust_left(site: Node2D, cell: Vector2i) -> float:
	var grid: PackedFloat32Array = site.dust[cell]
	var total: float = 0.0
	for v in grid:
		total += v
	return total


func _test_uncovered_bone_starts_caked() -> void:
	_reset()
	var site := _make_site()
	var bone: Vector2i = _first_bone(site)
	site.call("_reveal_fossil_cell", bone)
	_assert(site.dust.has(bone), "uncovered bone gets a dust layer")
	var layers: int = int(site.call("dust_layers", bone))
	_assert(layers >= 2, "bones are caked in at least two layers of dirt")
	_assert(is_equal_approx(_dust_left(site, bone), float(TN.DUST_COLS * TN.DUST_ROWS * layers)), "fresh bone is fully caked")
	_assert(float(site.cleanliness[bone]) == 0.0, "fresh bone is 0% clean")
	site.queue_free()


func _test_stroke_wipes_only_along_its_path() -> void:
	_reset()
	var site := _make_site()
	var bone: Vector2i = _first_bone(site)
	site.call("_reveal_fossil_cell", bone)
	_flatten(site, bone)
	var rect: Rect2 = site.call("_top_rect", bone.x, bone.y)
	var mid_y: float = rect.get_center().y
	site.call("brush_stroke", Vector2(rect.position.x + 2.0, mid_y), Vector2(rect.end.x - 2.0, mid_y))
	var grid: PackedFloat32Array = site.dust[bone]
	var mid_row: int = int(TN.DUST_ROWS) / 2
	var mid_i: int = mid_row * int(TN.DUST_COLS) + int(TN.DUST_COLS) / 2
	_assert(grid[mid_i] < float(site.call("dust_layers", bone)), "dust under the stroke gets wiped")
	_assert(is_equal_approx(grid[0], float(site.call("dust_layers", bone))), "a far corner the brush never touched stays caked")
	var clean: float = float(site.cleanliness[bone])
	_assert(clean > 0.0 and clean < 1.0, "a single stroke leaves the bone partly clean")
	site.queue_free()


func _test_weak_bristles_need_more_passes() -> void:
	_reset()
	GS.levels["brush_speed"] = 1
	GS.apply_upgrades()
	var site := _make_site()
	_assert(float(site.call("brush_strength")) <= 0.5, "a starter brush lifts half a layer per pass")
	var bone: Vector2i = _first_bone(site)
	site.call("_reveal_fossil_cell", bone)
	_flatten(site, bone)
	var c: Vector2 = site.call("cell_center", bone)
	site.call("brush_stroke", c, c)
	var once: float = _dust_left(site, bone)
	site.call("brush_stroke", c, c)
	var twice: float = _dust_left(site, bone)
	_assert(twice < once, "a second pass lifts more dust")
	site.queue_free()


func _wipe_all(site: Node2D, cell: Vector2i) -> void:
	var rect: Rect2 = site.call("_top_rect", cell.x, cell.y)
	for pass_i in 16:
		for row in int(TN.DUST_ROWS):
			var y: float = rect.position.y + (float(row) + 0.5) * rect.size.y / float(TN.DUST_ROWS)
			site.call("brush_stroke", Vector2(rect.position.x, y), Vector2(rect.end.x, y))


func _test_wiping_everything_cleans_and_bags_the_bone() -> void:
	_reset()
	var site := _make_site()
	var find: Dictionary = site.finds[0]
	var cells: Dictionary = find["cells"]
	for raw in cells:
		site.call("_reveal_fossil_cell", raw)
	var first: Vector2i = cells.keys()[0]
	_flatten(site, first)
	for raw in cells:
		_wipe_all(site, raw)
	_assert(bool(find.get("extracted", false)), "a fully wiped bone is bagged")
	for raw in cells:
		_assert(float(site.cleanliness[raw]) >= 1.0, "bagged bone reads 100% clean")
	site.queue_free()


func _test_slow_drags_do_not_clean_extra() -> void:
	## Cleaning follows distance, not frames: 40 tiny steps == 1 big stroke.
	_reset()
	var site := _make_site()
	var bone: Vector2i = _first_bone(site)
	site.call("_reveal_fossil_cell", bone)
	_flatten(site, bone)
	var rect: Rect2 = site.call("_top_rect", bone.x, bone.y)
	var a := Vector2(rect.position.x, rect.get_center().y)
	var b := Vector2(rect.end.x, rect.get_center().y)
	site.call("brush_stroke", a, b)
	var fast: float = _dust_left(site, bone)
	site.call("_reveal_fossil_cell", bone)
	site.dust.erase(bone)
	site.exposed_cells.erase(bone)
	site.call("_reveal_fossil_cell", bone)
	var steps: int = 40
	for i in steps:
		site.call("brush_stroke", a.lerp(b, float(i) / steps), a.lerp(b, float(i + 1) / steps))
	var slow: float = _dust_left(site, bone)
	_assert(absf(slow - fast) <= fast * 0.25 + 1.0, "a slow drag cleans about the same as one quick sweep")
	site.queue_free()


func _test_deeper_bones_have_more_layers() -> void:
	_assert(int(TN.dust_layers_for(0)) >= 3, "soil bones have at least 3 layers of dirt")
	_assert(int(TN.dust_layers_for(TN.layer_count - 1)) >= 4, "stone bones have at least 4 layers")


func _test_brush_upgrades_widen_the_bristles() -> void:
	_reset()
	GS.levels["brush_speed"] = 1
	GS.apply_upgrades()
	var site := _make_site()
	var base_r: float = float(site.call("brush_radius"))
	var base_s: float = float(site.call("brush_strength"))
	GS.levels["brush_speed"] = 5
	GS.levels["brush_master"] = 6
	GS.apply_upgrades()
	_assert(float(site.call("brush_radius")) > base_r, "brush upgrades widen the bristles")
	_assert(float(site.call("brush_strength")) > base_s, "brush upgrades lift more dust per pass")
	site.queue_free()


func _assert(ok: bool, label: String) -> void:
	if ok:
		_passed += 1
		print("PASS  %s" % label)
	else:
		_failed += 1
		print("FAIL  %s" % label)
