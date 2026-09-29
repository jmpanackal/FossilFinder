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
	_test_ground_fills_the_window()
	_test_pit_cutout_matches_chunk()
	_test_site_matches_the_pit_camera()
	_test_chunk_hole_matches_the_cutout()
	_test_deeper_cells_sit_lower()
	_test_drawn_step_wall_is_a_visible_stair()
	_test_section_walls_only_on_real_steps()
	_test_front_rim_has_no_chocolate_slab()
	_test_pit_rim_is_a_thin_inset()
	_test_north_edge_recedes_into_the_ground()
	_test_north_face_fill_is_darker_than_field()
	_test_north_pad_is_shaft_dark_not_field()
	_test_chunk_is_not_a_floating_sticker()
	_test_props_stay_off_cells()
	_test_backdrop_does_not_eat_clicks()
	_test_clicks_still_hit_dirt()
	_test_tool_pointer_only_over_pit()
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


func _test_ground_fills_the_window() -> void:
	if Site == null:
		_assert(Site != null, "site_backdrop.gd exists")
		return
	_layout()
	_assert(Site.has_method("horizon_y"), "backdrop still reports the old sky edge")
	if Site.has_method("horizon_y"):
		_assert(is_equal_approx(float(Site.horizon_y()), 0.0), "ground starts at y = 0 — no sky strip")
	var src: String = FileAccess.get_file_as_string("res://site_backdrop.gd")
	_assert(src.find("func _draw_sky") < 0, "no sky-band painter")
	_assert(src.find("SKY_TOP") < 0, "no blue-gray sky swatch")
	_assert(src.find("SKY_WASH") < 0, "no pale horizon wash swatch")
	_assert(src.find("_draw_sky(") < 0, "draw path does not wash the top")
	if Site.has_method("sky_color"):
		var sky: Color = Site.sky_color()
		_assert(sky.is_equal_approx(Site.ground_color()), "sky helper, if kept, is just the field tan")


func _test_pit_cutout_matches_chunk() -> void:
	if Site == null or not Site.has_method("pit_cutout"):
		_assert(Site != null and Site.has_method("pit_cutout"), "backdrop exposes the pit cutout")
		return
	_layout()
	var cut: Rect2 = Site.pit_cutout()
	var pad: float = float(TN.chunk_pad)
	var cells_top: float = float(TN.grid_origin.y)
	var cells_h: float = float(TN.grid_h) * TN.cell_h
	_assert(cut.position.x <= TN.grid_origin.x - pad + 0.5, "cutout still includes the west pad")
	_assert(cut.end.x >= TN.grid_origin.x + float(TN.grid_w) * TN.cell_w + pad - 0.5, "cutout still includes the east pad")
	_assert(cut.position.y < cells_top - pad + 0.5, "cutout starts at or above the north pad")
	_assert(is_equal_approx(cut.end.y, cells_top + cells_h), "cutout south edge still meets the grid")
	_assert(is_equal_approx(float(TN.grid_w) * TN.cell_w, TN.fitted_pit_size().x), "cutout uses the fitted pit")
	_assert(Site.has_method("horizon_y"), "backdrop still exposes horizon_y")
	if Site.has_method("horizon_y"):
		_assert(is_equal_approx(float(Site.horizon_y()), 0.0), "no far-edge sky wash — ground fills the window")
		_assert(float(Site.horizon_y()) < cut.position.y - 40.0, "ground continues around the pit, not a landscape taped above it")


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


func _test_deeper_cells_sit_lower() -> void:
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
	var grid: Array = site.get("_top_layer")
	_assert(grid.size() > 2 and grid[1].size() > 1 and grid[2].size() > 1, "pit has a mid-row pair")
	if grid.size() <= 2 or grid[1].size() <= 1:
		site.free()
		return
	grid[1][1] = 0
	grid[2][1] = 6
	var shallow: Rect2 = site.call("_top_rect", 1, 1)
	var deep: Rect2 = site.call("_top_rect", 2, 1)
	var plan_deep: float = float(TN.grid_origin.y) + 1.0 * float(TN.cell_h)
	var sink: float = deep.position.y - plan_deep
	var min_step: float = maxf(8.0, 6.0 * float(TN.wall_per_layer) * 0.8)
	_assert(deep.position.y - shallow.position.y >= min_step, "a mid-pit layer-6 top sits visibly lower than layer 0")
	_assert(sink >= min_step, "layer 6 is offset below its plan row, not a flat stamp")
	_assert(not is_equal_approx(shallow.position.y, deep.position.y), "same-row cells at different depth are not coplanar")
	var src: String = FileAccess.get_file_as_string("res://dig_site.gd")
	var top_fn: String = _func_body(src, "_top_rect")
	_assert(top_fn.find("wall_per_layer") >= 0 or top_fn.find("_depth_offset") >= 0, "_top_rect still applies a depth sink")
	_assert(top_fn.find("Plan-top only") < 0, "_top_rect is not the flattened plan-only helper")
	site.free()


func _test_drawn_step_wall_is_a_visible_stair() -> void:
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
	var grid: Array = site.get("_top_layer")
	_assert(grid.size() > 1 and grid[1].size() > 2, "pit has a mid-pit south neighbor")
	if grid.size() <= 1 or grid[1].size() <= 2:
		site.free()
		return
	grid[1][1] = 0
	grid[1][2] = 6
	var shallow: Rect2 = site.call("_top_rect", 1, 1)
	var deep: Rect2 = site.call("_top_rect", 1, 2)
	var drop: float = deep.position.y - shallow.end.y
	var min_wall: float = maxf(8.0, 6.0 * float(TN.wall_per_layer) * 0.8)
	_assert(drop >= min_wall, "the drawn gap between tops is the stair, not the 3px cell gap")
	var src: String = FileAccess.get_file_as_string("res://dig_site.gd")
	var sides: String = _func_body(src, "_draw_cell_sides")
	_assert(not sides.is_empty(), "pit still paints drop-between-rows cell sides")
	_assert(sides.find("below") >= 0 and sides.find("drop") >= 0, "_draw_cell_sides fills the Y gap to the next row")
	_assert(sides.find("_draw_east_section") < 0, "_draw_cell_sides does not paint an east section column")
	_assert(sides.find("_draw_south_section") < 0, "_draw_cell_sides is the original row-drop, not a section-wall helper")
	site.free()


func _test_section_walls_only_on_real_steps() -> void:
	var src: String = FileAccess.get_file_as_string("res://dig_site.gd")
	_assert(not src.is_empty(), "dig_site.gd loads")
	_assert(src.find("func east_section_h") < 0, "pit has no east_section_h side-slab API")
	_assert(src.find("func _draw_east_section") < 0, "pit does not paint per-cell east section walls")
	_assert(src.find("func _draw_south_section") < 0, "pit does not paint a south-section wall system")
	_assert(src.find("func _draw_unit_lips") < 0, "pit does not paint balk lips on every cell edge")
	_assert(src.find("func south_section_h") < 0, "pit does not expose a south-section height API")
	var sides: String = _func_body(src, "_draw_cell_sides")
	_assert(not sides.is_empty(), "original _draw_cell_sides is still the side painter")
	_assert(sides.find("if y + 1 >= Tuning.grid_h") >= 0, "last row has no extra south lip")
	_assert(sides.find("Rect2(top.end.x") < 0, "_draw_cell_sides does not grow a horizontal side column")


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
	_assert(site.has_method("_top_rect"), "pit can measure the last-row top")
	if not site.has_method("_top_rect"):
		site.free()
		return
	var last_y: int = int(TN.grid_h) - 1
	var grid: Array = site.get("_top_layer")
	if grid.size() > 1 and grid[1].size() > last_y:
		grid[1][last_y] = 8
	var top: Rect2 = site.call("_top_rect", 1, last_y)
	var hole_bottom: float = float(TN.pit_face_bottom()) + float(TN.chunk_front)
	_assert(top.end.y <= hole_bottom - 2.0, "last-row cell stays in the hole, above Finds")
	_assert(top.end.y <= float(TN.footer_find_top()) - 2.0, "last-row depth does not paint over Finds")
	if grid.size() > 1 and last_y >= 1:
		grid[1][last_y - 1] = 0
		grid[1][last_y] = 6
		var shallow: Rect2 = site.call("_top_rect", 1, last_y - 1)
		var deep: Rect2 = site.call("_top_rect", 1, last_y)
		_assert(deep.position.y - shallow.end.y > 1.0, "a hole just inside the last row still shows a south drop")
		_assert(deep.end.y <= hole_bottom - 2.0, "that interior stair still stays off Finds")
	var src: String = FileAccess.get_file_as_string("res://dig_site.gd")
	var sides: String = _func_body(src, "_draw_cell_sides")
	_assert(sides.find("if y + 1 >= Tuning.grid_h") >= 0, "last row skips a south lip instead of a chocolate slab")
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
	_assert(pit.find("func _draw_east_section") < 0, "the pit does not paint per-cell east side slabs")
	_assert(pit.find("func _draw_unit_lips") < 0, "the pit does not paint decorative balk lips")


func _test_north_edge_recedes_into_the_ground() -> void:
	_layout()
	var script: Script = load("res://dig_site.gd") as Script
	_assert(script != null, "dig site still loads for the north wall")
	if script == null:
		return
	var site: Node = script.new()
	root.add_child(site)
	if site.has_method("start_round"):
		site.call("start_round")
	_assert(site.has_method("north_face_h"), "pit exposes north face height")
	if not site.has_method("north_face_h"):
		site.free()
		return
	var face_h: float = float(site.call("north_face_h"))
	_assert(face_h > 0.0, "north face has height so the pit recedes at the top")
	_assert(face_h >= float(TN.chunk_pad) - 0.5, "north wall is at least the pad high")
	var cells_top: float = float(TN.grid_origin.y)
	var face_top: float = cells_top - face_h
	var cut: Rect2 = Site.pit_cutout()
	_assert(face_top >= cut.position.y - 0.5, "north wall stays in the existing pit hole")
	var header_bottom: float = (float(TN.hud_h) - 36.0) * 0.5 + 36.0
	_assert(face_top + 0.5 >= header_bottom, "north wall stays under the header actions")
	if site.has_method("north_face_rect"):
		var face: Rect2 = site.call("north_face_rect")
		_assert(face.size.y > 0.0, "north face draw rect has height")
		_assert(is_equal_approx(face.size.y, face_h), "north face rect matches the exposed height")
		_assert(face.end.y <= cells_top + 0.5, "north wall meets the first row, it does not cover the play grid")
		_assert(is_equal_approx(face.size.x, cut.size.x), "north wall spans the hole, not a center stripe")
	_assert(site.has_method("east_face_rect") and site.has_method("west_face_rect"), "pit exposes east and west interior walls")
	if site.has_method("east_face_rect") and site.has_method("west_face_rect"):
		var east: Rect2 = site.call("east_face_rect")
		var west: Rect2 = site.call("west_face_rect")
		var pad: float = float(TN.chunk_pad)
		_assert(is_equal_approx(east.size.x, pad), "east wall uses the existing pad, not a HUD gutter")
		_assert(is_equal_approx(west.size.x, pad), "west wall uses the existing pad, not a HUD gutter")
		_assert(east.size.y >= float(TN.grid_h) * TN.cell_h - 0.5, "east wall runs the pit, not a top stripe")
		_assert(west.size.y >= float(TN.grid_h) * TN.cell_h - 0.5, "west wall runs the pit, not a top stripe")
		_assert(east.end.x <= cut.end.x + 0.5, "east wall stays in the pit hole")
		_assert(west.position.x >= cut.position.x - 0.5, "west wall stays in the pit hole")
		_assert(east.position.x >= float(TN.grid_origin.x) + float(TN.grid_w) * TN.cell_w - 0.5, "east wall sits in the east pad")
		_assert(west.end.x <= float(TN.grid_origin.x) + 0.5, "west wall sits in the west pad")
	if Site.has_method("north_rim_h"):
		_assert(float(Site.north_rim_h()) <= 2.5, "north rim is a crease, not a packed-earth smear")
	var src: String = FileAccess.get_file_as_string("res://dig_site.gd")
	_assert(src.find("func _draw_north_face") >= 0, "pit draws a north interior wall")
	_assert(src.find("_draw_north_face()") >= 0, "the draw path actually paints the north wall")
	_assert(src.find("func _draw_east_face") >= 0 and src.find("func _draw_west_face") >= 0, "pit draws east and west interior walls")
	_assert(src.find("_draw_east_face()") >= 0 and src.find("_draw_west_face()") >= 0, "the draw path paints both side walls")
	_assert(src.find("minf(5.0") < 0, "top-row shade is not a 5px dirty band")
	if site.has_method("_tool_cursor_visible_at"):
		var on_wall := Vector2(float(TN.grid_origin.x) + float(TN.cell_w) * 2.5, face_top + face_h * 0.4)
		_assert(not bool(site.call("_tool_cursor_visible_at", on_wall)), "pointer stays off the north wall")
		if site.has_method("east_face_rect"):
			var east_wall: Rect2 = site.call("east_face_rect")
			var on_east := Vector2(east_wall.get_center().x, cells_top + 24.0)
			_assert(not bool(site.call("_tool_cursor_visible_at", on_east)), "pointer stays off the east wall")
		var on_dirt: Vector2 = site.call("cell_center", Vector2i(2, 0))
		_assert(bool(site.call("_tool_cursor_visible_at", on_dirt)), "pointer still shows on the first dirt row")
	site.free()


func _test_north_face_fill_is_darker_than_field() -> void:
	_layout()
	_assert(TN.has_method("shaft_interior_color"), "tuning exposes the shared in-shadow shaft shade")
	if not TN.has_method("shaft_interior_color"):
		return
	var field: Color = Site.ground_color()
	var top: Color = TN.color_for_layer(0)
	var fill: Color = TN.shaft_interior_color(0)
	_assert_wall_luminance_in_shadow(fill, top, field, "north fill")
	var packed_top: Color = TN.color_for_layer(6)
	var clay_top: Color = TN.color_for_layer(12)
	var packed_wall: Color = TN.shaft_interior_color(6)
	var clay_wall: Color = TN.shaft_interior_color(12)
	_assert_wall_luminance_in_shadow(packed_wall, packed_top, field, "packed shaft")
	_assert_wall_luminance_in_shadow(clay_wall, clay_top, field, "clay shaft")
	_assert(not packed_wall.is_equal_approx(fill), "packed shaft keeps local dirt hue")
	_assert(not clay_wall.is_equal_approx(packed_wall), "clay shaft is not the packed swatch")
	var script: Script = load("res://dig_site.gd") as Script
	_assert(script != null, "dig site still loads for north-face fill")
	if script == null:
		return
	var site: Node = script.new()
	root.add_child(site)
	if site.has_method("start_round"):
		site.call("start_round")
	_assert(site.has_method("north_face_fill_color"), "pit exposes the shared north-face fill")
	_assert(site.has_method("shaft_wall_color"), "pit exposes per-cell shaft wall color")
	if site.has_method("north_face_fill_color"):
		var painted: Color = site.call("north_face_fill_color")
		_assert(painted.is_equal_approx(fill), "north face uses the shared in-shadow shade")
		_assert_wall_luminance_in_shadow(painted, top, field, "painted north fill")
	if site.has_method("shaft_wall_color"):
		var loose_wall: Color = site.call("shaft_wall_color", 0, 0)
		_assert_wall_luminance_in_shadow(loose_wall, top, field, "undug north wall")
		var west_wall: Color = site.call("shaft_wall_color", 0, 1)
		var last_x: int = TN.grid_w - 1
		var east_wall: Color = site.call("shaft_wall_color", last_x, 1)
		_assert_wall_luminance_in_shadow(west_wall, top, field, "undug west interior")
		_assert_wall_luminance_in_shadow(east_wall, top, field, "undug east interior")
		var grid: Array = site.get("_top_layer")
		if grid.size() > 2 and grid[1].size() > 1:
			grid[1][0] = 6
			grid[2][0] = 12
			grid[0][1] = 6
			if grid[last_x].size() > 1:
				grid[last_x][1] = 12
			var dug_packed: Color = site.call("shaft_wall_color", 1, 0)
			var dug_clay: Color = site.call("shaft_wall_color", 2, 0)
			var west_packed: Color = site.call("shaft_wall_color", 0, 1)
			var east_clay: Color = site.call("shaft_wall_color", last_x, 1)
			_assert_wall_luminance_in_shadow(dug_packed, packed_top, field, "dug packed north wall")
			_assert_wall_luminance_in_shadow(dug_clay, clay_top, field, "dug clay north wall")
			_assert_wall_luminance_in_shadow(west_packed, packed_top, field, "packed west interior")
			_assert_wall_luminance_in_shadow(east_clay, clay_top, field, "clay east interior")
	var src: String = FileAccess.get_file_as_string("res://dig_site.gd")
	var north_fn: String = _func_body(src, "_draw_north_face")
	var west_fn: String = _func_body(src, "_draw_west_face")
	var east_fn: String = _func_body(src, "_draw_east_face")
	_assert(north_fn.find("chunk_side_color") < 0, "north painter does not lock chunk_side_color")
	_assert(west_fn.find("chunk_side_color") < 0, "west painter does not lock chunk_side_color")
	_assert(east_fn.find("chunk_side_color") < 0, "east painter does not lock chunk_side_color")
	_assert(north_fn.find("_draw_strata_stack") >= 0 or north_fn.find("shaft_wall_color") >= 0, "north painter paints the remaining dirt stack")
	_assert(west_fn.find("_draw_shaft_face") >= 0 or west_fn.find("_draw_strata_stack") >= 0, "west painter paints the remaining dirt stack")
	_assert(east_fn.find("_draw_shaft_face") >= 0 or east_fn.find("_draw_strata_stack") >= 0, "east painter paints the remaining dirt stack")
	site.free()


func _test_north_pad_is_shaft_dark_not_field() -> void:
	_layout()
	_assert(Site.has_method("north_pad_rect"), "backdrop exposes the north pad strip")
	_assert(Site.has_method("shaft_back_color"), "backdrop exposes the excavation-back fill")
	_assert(Site.has_method("north_lip_y"), "backdrop exposes the field lip above the hole")
	if not Site.has_method("north_pad_rect") or not Site.has_method("shaft_back_color"):
		return
	var field: Color = Site.ground_color()
	var tan := Color("C4A36A")
	var shaft: Color = TN.shaft_interior_color(0)
	var back: Color = Site.shaft_back_color()
	_assert(back.is_equal_approx(shaft), "open hole back is the shared shaft-interior shade")
	_assert(not back.is_equal_approx(field), "open hole back is not field tan")
	_assert(not back.is_equal_approx(tan), "open hole back is not #C4A36A")
	_assert_wall_luminance_in_shadow(back, TN.color_for_layer(0), field, "north pad back")
	var pad: Rect2 = Site.north_pad_rect()
	var lip_y: float = float(Site.north_lip_y()) if Site.has_method("north_lip_y") else pad.position.y
	var cells_top: float = float(TN.grid_origin.y)
	_assert(pad.size.y >= float(TN.chunk_pad) - 0.5, "north pad is the whole gap above row 0, not a hairline")
	_assert(pad.position.y >= lip_y - 0.5, "north pad sits below the field lip")
	_assert(pad.end.y <= cells_top + 0.5, "north pad stops at the first cell tops")
	_assert(pad.position.y < cells_top - 8.0, "north pad has real height between lip and row 0")
	var header_bottom: float = (float(TN.hud_h) - 36.0) * 0.5 + 36.0
	_assert(pad.position.y + 0.5 >= header_bottom, "north pad does not steal the HUD header")
	var src: String = FileAccess.get_file_as_string("res://site_backdrop.gd")
	_assert(src.find("shaft_back_color") >= 0, "backdrop names the excavation-back fill")
	_assert(src.find("draw_rect(hole, shaft_back_color()") >= 0 or src.find("draw_rect(pad") >= 0 and src.find("shaft_back_color") >= 0, "open hole / north pad is painted shaft-dark")
	_assert(src.find("if _cover_hole") >= 0, "covered hole can still plug with field tan")
	var script: Script = load("res://dig_site.gd") as Script
	_assert(script != null, "dig site still loads for the north pad")
	if script == null:
		return
	var site: Node = script.new()
	root.add_child(site)
	if site.has_method("start_round"):
		site.call("start_round")
	if site.has_method("north_face_rect"):
		var face: Rect2 = site.call("north_face_rect")
		_assert(face.position.y <= pad.position.y + 0.5, "north face starts at the pad")
		_assert(face.end.y >= pad.end.y - 0.5, "north face fills down to row 0")
		_assert(is_equal_approx(float(TN.grid_w) * TN.cell_w, TN.fitted_pit_size().x), "play cells fill the fitted width")
		_assert(is_equal_approx(float(TN.grid_h) * TN.cell_h, TN.fitted_pit_size().y), "play cells fill the fitted height")
	site.free()


func _func_body(src: String, name: String) -> String:
	var start: int = src.find("func %s" % name)
	if start < 0:
		return ""
	var next: int = src.find("\nfunc ", start + 1)
	if next < 0:
		return src.substr(start)
	return src.substr(start, next - start)


func _rgb_distance(a: Color, b: Color) -> float:
	return Vector3(a.r, a.g, a.b).distance_to(Vector3(b.r, b.g, b.b))


func _assert_wall_luminance_in_shadow(wall: Color, cell_top: Color, field: Color, label: String) -> void:
	var wall_l: float = wall.get_luminance()
	var top_l: float = cell_top.get_luminance()
	var field_l: float = field.get_luminance()
	## 0.14 darken of tan only drops ~0.09 luminance — almost equal, not a hole.
	_assert(wall_l < top_l * 0.78, "%s is clearly darker than its cell top (not almost equal)" % label)
	_assert(wall_l < field_l * 0.78, "%s is clearly darker than the field tan (not almost equal)" % label)
	_assert(wall_l < field_l - 0.16, "%s luminance is substantially below the field tan" % label)
	_assert(wall_l < top_l - 0.08, "%s luminance is below its cell top" % label)
	_assert(not wall.is_equal_approx(cell_top.darkened(0.14)), "%s is not the weak 0.14 same-fill darken" % label)
	_assert(not wall.is_equal_approx(cell_top) and not wall.is_equal_approx(field), "%s is never the sand swatch" % label)


func _test_chunk_is_not_a_floating_sticker() -> void:
	var src: String = FileAccess.get_file_as_string("res://dig_site.gd")
	_assert(not src.is_empty(), "dig_site.gd loads")
	_assert(src.find("Tuning.chunk_front") < 0 or src.find("_draw_chunk") < 0 or src.find("draw_rect(front") < 0, "pit no longer paints a separate front slab")
	_assert(src.find("func _draw_cell_sides") >= 0, "pit still paints the original row-drop cell sides")
	_assert(src.find("func _draw_unit_lips") < 0, "pit does not draw layered balk lips on the cut")
	_assert(src.find("func _draw_east_section") < 0, "pit does not draw east section side artifacts")
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


func _test_tool_pointer_only_over_pit() -> void:
	_layout()
	var script: Script = load("res://dig_site.gd") as Script
	_assert(script != null, "dig site still loads for the tool pointer")
	if script == null:
		return
	var site: Node = script.new()
	root.add_child(site)
	if site.has_method("start_round"):
		site.call("start_round")
	_assert(site.has_method("_tool_cursor_visible_at"), "dig site exposes tool pointer visibility")
	if not site.has_method("_tool_cursor_visible_at"):
		site.free()
		return
	var on_dirt: Vector2 = site.call("cell_center", Vector2i(2, 1))
	_assert(bool(site.call("_tool_cursor_visible_at", on_dirt)), "pointer shows over a dirt cell")
	var pit: Rect2 = TN.pit_grid_rect()
	var below: Vector2 = Vector2(pit.get_center().x, pit.end.y + 40.0)
	_assert(not bool(site.call("_tool_cursor_visible_at", below)), "pointer hides below the pit")
	var hud_script: Script = load("res://hud.gd") as Script
	_assert(hud_script != null, "HUD loads so the rail can be sampled")
	if hud_script == null:
		site.free()
		return
	var hud: CanvasLayer = hud_script.new() as CanvasLayer
	root.add_child(hud)
	hud.call("refresh", 40.0, 40.0, TN.TOOL_HANDS, true)
	var rail: Control = hud.get("_tool_rail") as Control
	_assert(rail != null and rail.size.x > 1.0, "HUD exposes the tool rail")
	if rail != null and rail.size.x > 1.0:
		var rail_pt: Vector2 = rail.position + rail.size * 0.5
		_assert(not bool(site.call("_tool_cursor_visible_at", rail_pt)), "pointer hides over the HUD rail")
	var src: String = FileAccess.get_file_as_string("res://dig_site.gd")
	_assert(src.find("_draw_tool_cursor") >= 0, "the aim mark still lives on the fx overlay")
	_assert(src.find("if not _tool_cursor_visible_at") >= 0, "cursor draw uses the pit hide rule")
	hud.free()
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
	_assert(not clear.is_equal_approx(Color.BLACK), "clear color is not black")
	_assert(clear.r > 0.45 and clear.g > 0.35 and clear.b < 0.75, "clear color stays dirt-family, not void")
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
