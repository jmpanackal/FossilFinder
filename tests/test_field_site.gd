extends SceneTree

## Field site backdrop: the pit sits in the ground, not a void.
## Run: godot --headless --path <project> -s res://tests/test_field_site.gd

var _failed: int = 0
var _passed: int = 0
var TN: Node
var Site: GDScript


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	TN = root.get_node("Tuning")
	Site = load("res://site_backdrop.gd") as GDScript
	_test_script_exists()
	_test_ground_is_dirt_family_not_void()
	_test_sky_is_not_void()
	_test_pit_cutout_matches_chunk()
	_test_site_matches_the_pit_camera()
	_test_chunk_hole_matches_the_cutout()
	_test_cell_tops_stay_flat()
	_test_section_walls_only_on_real_steps()
	_test_front_rim_has_no_chocolate_slab()
	_test_pit_rim_is_a_thin_inset()
	_test_chunk_is_not_a_floating_sticker()
	_test_props_stay_off_cells()
	_test_backdrop_does_not_eat_clicks()
	_test_clicks_still_hit_dirt()
	_test_dig_site_does_not_paint_a_black_void()
	_test_clear_color_is_not_void()
	_test_main_scene_has_backdrop_behind_pit()
	print("field_site %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _layout() -> void:
	TN.view_w = 1280.0
	TN.view_h = 720.0
	TN.site_size_rank = 0
	TN.apply_site_layout()


func _test_script_exists() -> void:
	_assert(Site != null, "site_backdrop.gd exists")


func _test_ground_is_dirt_family_not_void() -> void:
	if Site == null:
		return
	_assert(Site.has_method("ground_color"), "backdrop exposes ground_color")
	if not Site.has_method("ground_color"):
		return
	var dirt: Color = TN.color_for_layer(0)
	var ground: Color = Site.ground_color()
	_assert(not ground.is_equal_approx(Color("140F0C")), "ground is not the old void")
	_assert(not ground.is_equal_approx(Color.BLACK), "ground is not black")
	_assert(ground.r > 0.45 and ground.g > 0.35 and ground.b < 0.55, "ground stays in the tan dirt family")
	var ground_rgb := Vector3(ground.r, ground.g, ground.b)
	var dirt_rgb := Vector3(dirt.r, dirt.g, dirt.b)
	_assert(ground_rgb.distance_to(dirt_rgb) < 0.18, "ground is the same dirt family as cell tops")


func _test_sky_is_not_void() -> void:
	if Site == null or not Site.has_method("sky_color"):
		_assert(Site != null and Site.has_method("sky_color"), "backdrop exposes sky_color")
		return
	var sky: Color = Site.sky_color()
	_assert(not sky.is_equal_approx(Color("140F0C")), "sky is not the old void")
	_assert(sky.v > 0.55, "sky is a wash, not a dark hole")


func _test_pit_cutout_matches_chunk() -> void:
	if Site == null or not Site.has_method("pit_cutout"):
		_assert(Site != null and Site.has_method("pit_cutout"), "backdrop exposes the pit cutout")
		return
	_layout()
	var cut: Rect2 = Site.pit_cutout()
	var pad: float = float(TN.chunk_pad)
	var expected := Rect2(
		TN.grid_origin.x - pad,
		TN.grid_origin.y - pad,
		float(TN.grid_w) * TN.cell_w + pad * 2.0,
		float(TN.grid_h) * TN.cell_h + pad
	)
	_assert(cut.is_equal_approx(expected), "pit hole matches the dirt chunk top")
	_assert(is_equal_approx(float(TN.grid_w) * TN.cell_w, 16.0 * TN.base_cell_w), "cutout still uses the 1024px pit")
	_assert(Site.has_method("horizon_y"), "backdrop exposes a far-edge sky wash")
	if Site.has_method("horizon_y"):
		var horizon: float = float(Site.horizon_y())
		_assert(horizon >= 8.0 and horizon <= 48.0, "sky is a thin wash at the far edge of the ground")
		_assert(horizon < cut.position.y - 40.0, "ground continues around the pit, not a landscape taped above it")


func _test_chunk_hole_matches_the_cutout() -> void:
	if Site == null or not Site.has_method("chunk_hole") or not Site.has_method("pit_cutout"):
		_assert(Site != null and Site.has_method("chunk_hole"), "backdrop exposes the ground hole")
		return
	_layout()
	var cut: Rect2 = Site.pit_cutout()
	var hole: Rect2 = Site.chunk_hole()
	_assert(hole.is_equal_approx(cut), "the field hole is the trench cut, not a bigger 3D chunk")
	_assert(is_equal_approx(hole.size.x, float(TN.grid_w) * TN.cell_w + float(TN.chunk_pad) * 2.0), "hole width matches the pit pad")
	_assert(hole.size.y < cut.size.y + 8.0, "hole does not add a fake front face under the pit")


func _test_cell_tops_stay_flat() -> void:
	_layout()
	var script: Script = load("res://dig_site.gd") as Script
	_assert(script != null, "dig site still loads")
	if script == null:
		return
	var site: Node = script.new()
	root.add_child(site)
	if site.has_method("start_round"):
		site.call("start_round")
	_assert(site.has_method("_top_rect"), "dig site still exposes cell tops")
	if not site.has_method("_top_rect"):
		site.free()
		return
	var shallow: Rect2 = site.call("_top_rect", 1, 1)
	if site.get("_top_layer") != null:
		var grid: Array = site.get("_top_layer")
		if grid.size() > 1 and grid[1].size() > 1:
			grid[1][1] = 6
	var deep: Rect2 = site.call("_top_rect", 1, 1)
	_assert(is_equal_approx(shallow.position.y, deep.position.y), "deeper dirt keeps the same plan-top Y")
	var neighbor: Rect2 = site.call("_top_rect", 1, 2)
	_assert(is_equal_approx(deep.position.y + float(TN.cell_h), neighbor.position.y), "next row sits on the same plan grid, not a stair")
	site.free()


func _test_section_walls_only_on_real_steps() -> void:
	_layout()
	var script: Script = load("res://dig_site.gd") as Script
	_assert(script != null, "dig site still loads")
	if script == null:
		return
	var site: Node = script.new()
	root.add_child(site)
	if site.has_method("start_round"):
		site.call("start_round")
	_assert(site.has_method("south_section_h"), "pit exposes south section height")
	if not site.has_method("south_section_h"):
		site.free()
		return
	var grid: Array = site.get("_top_layer")
	if grid.size() > 1 and grid[1].size() > 2:
		grid[1][1] = 0
		grid[1][2] = 4
	_assert(float(site.call("south_section_h", 1, 1)) > 1.0, "a real step down gets a south section wall")
	_assert(float(site.call("south_section_h", 1, 2)) <= 0.0, "no fake south column on the deeper cell")
	if grid.size() > 1 and grid[1].size() > 2:
		grid[1][1] = 0
		grid[1][2] = int(TN.layer_count)
	_assert(float(site.call("south_section_h", 1, 1)) > 1.0, "an empty neighbor still gets an interior south wall")
	if site.has_method("east_section_h") and grid.size() > 2:
		grid[1][1] = 0
		grid[2][1] = 3
		_assert(float(site.call("east_section_h", 1, 1)) > 1.0, "a real step east gets an east section wall")
		_assert(float(site.call("east_section_h", 2, 1)) <= 0.0, "no fake east column on the deeper cell")
	site.free()


func _test_front_rim_has_no_chocolate_slab() -> void:
	_layout()
	var script: Script = load("res://dig_site.gd") as Script
	_assert(script != null, "dig site still loads")
	if script == null:
		return
	var site: Node = script.new()
	root.add_child(site)
	if site.has_method("start_round"):
		site.call("start_round")
	_assert(site.has_method("south_section_h") and site.has_method("_top_rect"), "pit can measure the front face")
	if not site.has_method("south_section_h") or not site.has_method("_top_rect"):
		site.free()
		return
	var last_y: int = int(TN.grid_h) - 1
	var grid: Array = site.get("_top_layer")
	if grid.size() > 1 and grid[1].size() > last_y:
		grid[1][last_y] = 8
	var front_h: float = float(site.call("south_section_h", 1, last_y))
	var rim: float = float(Site.rim_width()) if Site != null and Site.has_method("rim_width") else 4.0
	_assert(front_h <= rim + 0.5, "last-row south face is a short cut or skip, not a chocolate lip")
	var top: Rect2 = site.call("_top_rect", 1, last_y)
	var cut: Rect2 = Site.pit_cutout()
	_assert(top.end.y + front_h <= cut.end.y + 0.5, "front wall does not hang past the pit rect")
	_assert(top.end.y + front_h <= TN.grid_origin.y + float(TN.grid_h) * TN.cell_h + float(TN.chunk_pad) + 0.5, "no extra slab below the grid")
	if grid.size() > 1 and last_y >= 1:
		grid[1][last_y - 1] = 0
		grid[1][last_y] = 6
		var interior: float = float(site.call("south_section_h", 1, last_y - 1))
		_assert(interior > 1.0, "a hole just inside the last row still shows a south wall")
	site.free()


func _test_pit_rim_is_a_thin_inset() -> void:
	if Site == null:
		_assert(Site != null, "backdrop still loads")
		return
	_assert(Site.has_method("rim_width"), "backdrop exposes rim width")
	_assert(Site.has_method("rim_shadow_color"), "backdrop exposes rim shadow")
	_assert(Site.has_method("rim_rect"), "backdrop exposes the rim around the grid")
	if not Site.has_method("rim_width") or not Site.has_method("rim_shadow_color") or not Site.has_method("rim_rect"):
		return
	_layout()
	var width: float = float(Site.rim_width())
	_assert(width >= 2.0 and width <= 4.0, "rim is a thin inset, not a chocolate wall")
	var shadow: Color = Site.rim_shadow_color()
	var ground: Color = Site.ground_color()
	_assert(shadow.a > 0.08 and shadow.a <= 0.35, "rim is a slight shadow, not a solid shaft wall")
	_assert(shadow.v < ground.v, "rim sits darker than the shared tan plane")
	var rim: Rect2 = Site.rim_rect()
	var cells := Rect2(
		TN.grid_origin,
		Vector2(float(TN.grid_w) * TN.cell_w, float(TN.grid_h) * TN.cell_h)
	)
	_assert(rim.is_equal_approx(cells), "rim hugs the cell grid, not a 3D trench")
	var dirt: Color = TN.color_for_layer(0)
	_assert(ground.is_equal_approx(dirt) or Vector3(ground.r, ground.g, ground.b).distance_to(Vector3(dirt.r, dirt.g, dirt.b)) < 0.04, "pit and field share the same tan plane")
	var back: String = FileAccess.get_file_as_string("res://site_backdrop.gd")
	_assert(back.find("const LIP :=") < 0, "no raised chocolate lip swatch")
	var pit: String = FileAccess.get_file_as_string("res://dig_site.gd")
	_assert(pit.find("func _draw_rim") >= 0 or pit.find("SiteBackdrop.rim_width") >= 0, "the pit paints the inset rim")


func _test_chunk_is_not_a_floating_sticker() -> void:
	var src: String = FileAccess.get_file_as_string("res://dig_site.gd")
	_assert(not src.is_empty(), "dig_site.gd loads")
	_assert(src.find("Tuning.chunk_front") < 0 or src.find("_draw_chunk") < 0 or src.find("draw_rect(front") < 0, "pit no longer paints a separate front slab")
	_assert(src.find("south_section") >= 0 or src.find("_draw_south_section") >= 0, "pit draws south section walls on real steps")
	_assert(src.find("_draw_unit_lips") >= 0 and src.find("_draw_strat_bands") >= 0, "pit draws layered balk lips on the cut")
	var back: String = FileAccess.get_file_as_string("res://site_backdrop.gd")
	_assert(back.find("chunk_front") < 0, "field hole does not reserve a separate chunk front")


func _test_props_stay_off_cells() -> void:
	if Site == null or not Site.has_method("prop_rects"):
		_assert(Site != null and Site.has_method("prop_rects"), "backdrop exposes prop rects")
		return
	_layout()
	var props: Dictionary = Site.prop_rects()
	var cut: Rect2 = Site.pit_cutout()
	_assert(props.size() >= 3 and props.size() <= 6, "site dressing is 3-6 sparse props")
	var cells := Rect2(
		TN.grid_origin,
		Vector2(float(TN.grid_w) * TN.cell_w, float(TN.grid_h) * TN.cell_h)
	)
	for name in props:
		var rect: Rect2 = props[name]
		_assert(not rect.intersects(cells), "%s stays off the dirt cells" % name)
		_assert(rect.size.x > 8.0 and rect.size.y > 8.0, "%s is a readable toy prop" % name)
	for needed in ["spoil", "crate", "tent", "stakes"]:
		_assert(props.has(needed), "site includes a %s" % needed)
	if props.has("tent"):
		var tent: Rect2 = props["tent"]
		_assert(tent.position.y >= cut.position.y - 8.0 or tent.end.y <= cut.position.y + 8.0 or tent.position.x >= cut.end.x or tent.end.x <= cut.position.x, "tent sits on the ground plane beside the pit")
		_assert(tent.size.x >= tent.size.y * 0.85, "tent is a top-down footprint, not an A-frame silhouette")
	if props.has("stakes"):
		var stakes: Rect2 = props["stakes"]
		_assert(stakes.size.x > 20.0 and stakes.size.y > 20.0, "survey stakes ring the cut")


func _test_site_matches_the_pit_camera() -> void:
	if Site == null:
		return
	var src: String = FileAccess.get_file_as_string("res://site_backdrop.gd")
	_assert(not src.is_empty(), "site_backdrop.gd loads")
	_assert(src.find("_draw_hills") < 0, "no planet-horizon hills")
	_assert(src.find("_hill(") < 0, "no eye-level hill silhouettes")
	_assert(src.find("peak") < 0 or src.find("footprint") >= 0, "camp props are top-down, not peaked tents")
	_assert(src.find("func _draw_pit_lips") >= 0 or src.find("_draw_rim") >= 0, "the pit still has a cut rim")


func _test_backdrop_does_not_eat_clicks() -> void:
	if Site == null:
		return
	var node: Node2D = Site.new() as Node2D
	_assert(node != null, "backdrop is a Node2D, not a Control")
	if node == null:
		return
	var src: String = FileAccess.get_file_as_string("res://site_backdrop.gd")
	_assert(src.find("func _unhandled_input") < 0, "backdrop does not steal unhandled clicks")
	_assert(src.find("func _input(") < 0, "backdrop does not steal input")
	_assert(node.z_index <= 0, "backdrop stays behind the pit")
	node.free()


func _test_clicks_still_hit_dirt() -> void:
	_layout()
	var script: Script = load("res://dig_site.gd") as Script
	_assert(script != null, "dig site still loads")
	if script == null:
		return
	var site: Node = script.new()
	root.add_child(site)
	if site.has_method("start_round"):
		site.call("start_round")
	_assert(site.has_method("_cell_at"), "dig site still maps clicks to cells")
	if site.has_method("_cell_at"):
		var cell := Vector2i(2, 1)
		var world: Vector2 = site.call("cell_center", cell)
		var hit: Vector2i = site.call("_cell_at", world)
		_assert(hit == cell, "a click on dirt still hits that cell")
		var left: Vector2 = Vector2(32.0, world.y)
		var miss: Vector2i = site.call("_cell_at", left)
		_assert(miss.x < 0, "a click left of the pit is not a dirt cell")
	site.free()


func _test_dig_site_does_not_paint_a_black_void() -> void:
	var src: String = FileAccess.get_file_as_string("res://dig_site.gd")
	_assert(not src.is_empty(), "dig_site.gd loads")
	_assert(src.find("140F0C") < 0, "dig site no longer fills the window with void brown")
	_assert(src.find("_draw_void") < 0, "dig site no longer paints a full-window void")


func _test_clear_color_is_not_void() -> void:
	if Site == null or not Site.has_method("clear_color"):
		_assert(Site != null and Site.has_method("clear_color"), "backdrop exposes the window clear color")
		return
	var clear: Color = Site.clear_color()
	_assert(not clear.is_equal_approx(Color("140F0C")), "clear color is not the old void")
	_assert(clear.v > 0.45, "letterbox / expand wash is a field color")
	var settings := ConfigFile.new()
	_assert(settings.load("res://project.godot") == OK, "project.godot loads")
	var raw: Color = settings.get_value("rendering", "environment/defaults/default_clear_color", Color("140F0C"))
	_assert(raw.is_equal_approx(clear), "project clear color matches the field wash")


func _test_main_scene_has_backdrop_behind_pit() -> void:
	var packed: PackedScene = load("res://main.tscn") as PackedScene
	_assert(packed != null, "main.tscn loads")
	if packed == null:
		return
	var main: Node = packed.instantiate()
	root.add_child(main)
	var backdrop: Node = main.get_node_or_null("SiteBackdrop")
	var pit: Node = main.get_node_or_null("DigSite")
	_assert(backdrop != null, "main scene has a SiteBackdrop")
	_assert(pit != null, "main scene still has the DigSite")
	if backdrop != null and pit != null:
		_assert(backdrop.get_index() < pit.get_index(), "backdrop draws behind the pit")
		_assert(int(backdrop.get("z_index")) <= int(pit.get("z_index")), "backdrop z stays at or behind the pit")
	main.free()


func _assert(ok: bool, label: String) -> void:
	if ok:
		_passed += 1
		print("PASS  %s" % label)
	else:
		_failed += 1
		print("FAIL  %s" % label)
