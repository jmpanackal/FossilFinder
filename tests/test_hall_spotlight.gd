extends SceneTree

## Spotlight + Unveiling with Small Finds on a side wall.
## Skull unveils on Triceratops. Tooth/vertebra unveil in the wall case.

var _failed: int = 0
var _passed: int = 0
var GS: Node
var TN: Node


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	GS = root.get_node("GameState")
	TN = root.get_node("Tuning")
	_test_empty_aisle_layout()
	_test_new_skull_is_pending_unveil()
	_test_scraps_mount_in_small_finds()
	_test_museum_click_unveils_then_spotlights()
	_test_museum_click_unveils_small_finds()
	_test_hall_title_is_a_wall_board()
	_test_header_shows_visitors_each_rate_as_separate_fields()
	_test_wall_board_is_title_and_featured()
	_test_empty_display_sits_at_screen_bottom()
	_test_featured_mount_hides_empty_display()
	_test_board_does_not_own_visitor_rate_numbers()
	_test_header_cluster_stays_in_bar_and_clear_of_nav()
	_test_header_shows_featured_name_and_income()
	_test_header_names_a_mounted_tooth()
	_test_featured_small_finds_income_is_readable()
	_test_dusty_featured_case_header_is_not_zero()
	_test_old_save_piece_is_not_pending()
	_test_empty_stands_never_pending()
	_test_duplicate_does_not_reflag_after_unveil()
	_test_empty_stand_cannot_be_featured()
	_test_filled_stand_can_be_featured()
	_test_featuring_again_keeps_featured()
	_test_empty_stand_does_not_steal_spotlight()
	_test_spotlight_does_not_multiply_without_ranks()
	_test_spotlight_rank_one_is_2x()
	_test_spotlight_rank_two_is_3x()
	_test_spotlight_rank_three_is_4x()
	_test_blockbuster_featured_reaches_five_or_six()
	_test_click_still_features_without_ranks()
	_test_plaque_hides_mult_until_bought()
	_test_plaque_shows_owned_mult()
	_test_spotlight_beam_scales_with_rank()
	_test_spotlight_is_one_cone_on_the_featured_stand()
	_test_featured_spotlight_circle_centers_on_the_dino()
	_test_non_featured_stand_has_no_glow_disc()
	_test_unveil_pays_and_clears_pending()
	_test_unveil_starts_income_spike()
	_test_header_leads_with_rush_rate_not_cash()
	_test_header_splits_rush_waiting_and_featured()
	_test_header_counts_pending_unveils()
	_test_header_copy_keeps_word_spaces()
	_test_header_cluster_is_centered_in_the_bar()
	_test_ribbon_shows_full_tail_above_plaque()
	_test_ribbon_names_one_pending_piece()
	_test_ribbon_counts_several_pending_on_stand()
	_test_zoomed_out_labels_stay_readable()
	_test_toast_names_the_new_piece()
	_test_wheel_zooms_instead_of_panning()
	_test_default_zoom_fits_hall_width()
	_test_min_zoom_fits_hall_width()
	_test_cannot_zoom_out_past_hall_width()
	_test_max_zoom_is_close_on_a_stand()
	_test_click_after_zoom_still_hits_the_stand()
	_test_drag_pans_while_zoomed()
	_test_pan_cannot_leave_the_hall()
	print("hall_spotlight %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _reset() -> void:
	GS.pieces.clear()
	GS.money = 0
	GS.featured_stand_id = ""
	GS.pending_unveils.clear()
	GS.unveil_spike_left = 0.0
	if "unveil_rush_stacks" in GS:
		GS.unveil_rush_stacks = 0
	if "unveil_rush_unit" in GS:
		GS.unveil_rush_unit = 0.0
	GS._income_accum = 0.0
	for item in GS.catalog:
		GS.levels[item["id"]] = 0
	GS.apply_upgrades()


func _test_empty_aisle_layout() -> void:
	var exhibit: Node2D = Node2D.new()
	exhibit.set_script(load("res://museum_exhibit.gd"))
	root.add_child(exhibit)
	var layout: Dictionary = exhibit.STAND_LAYOUT
	_assert(layout.size() == 7, "hall has seven stands")
	_assert(layout.has("small_finds"), "Small Finds case exists")
	_assert(str(layout["small_finds"]["title"]) == "Small Finds", "case plaque says Small Finds")
	_assert(layout.has("plant_fossils"), "Plant Fossils case exists")
	_assert(str(layout["plant_fossils"]["title"]) == "Plant Fossils", "plant plaque says Plant Fossils")
	_assert(layout.has("t_rex") and layout.has("triceratops") and layout.has("velociraptor"), "far and left stands exist")
	_assert(layout.has("brachiosaurus") and layout.has("stegosaurus"), "right stands exist")
	_assert(str(layout["brachiosaurus"]["title"]) == "Brachiosaurus", "sauropod plaque says Brachiosaurus")
	var t_rex: Rect2 = exhibit.stand_rect("t_rex")
	var case_stand: Rect2 = exhibit.stand_rect("small_finds")
	var plants: Rect2 = exhibit.stand_rect("plant_fossils")
	var left_a: Rect2 = exhibit.stand_rect("triceratops")
	var left_b: Rect2 = exhibit.stand_rect("velociraptor")
	var right_a: Rect2 = exhibit.stand_rect("brachiosaurus")
	var right_b: Rect2 = exhibit.stand_rect("stegosaurus")
	_assert(t_rex.position.y < left_a.position.y and t_rex.position.y < right_a.position.y, "T. rex stands at the far end")
	_assert(left_a.position.x < 400.0 and left_b.position.x < 400.0, "Triceratops and Velociraptor stay left")
	_assert(right_a.position.x > 1400.0 and right_b.position.x > 1400.0, "Brachiosaurus and Stegosaurus stay right")
	_assert(case_stand.position.x < 400.0, "Small Finds sits on a side or end wall")
	_assert(case_stand.position.y < 480.0, "Small Finds is an end bay, not down the aisle")
	_assert(plants.position.x > 1400.0, "Plant Fossils sits on the opposite end wall")
	_assert(plants.position.y < 480.0, "Plant Fossils is an end bay, not down the aisle")
	_assert(is_equal_approx(plants.position.y, case_stand.position.y), "both end cases share the north wall")
	_assert(left_a.position.y >= case_stand.end.y + 100.0, "Small Finds has aisle space above Triceratops")
	_assert(right_a.position.y >= plants.end.y + 100.0, "Plant Fossils has aisle space above Brachiosaurus")
	_assert(not case_stand.intersects(t_rex), "Small Finds does not cover T. rex")
	_assert(not plants.intersects(t_rex), "Plant Fossils does not cover T. rex")
	_assert(not plants.intersects(right_a), "Plant Fossils does not sit on Brachiosaurus")
	var aisle: Rect2 = Rect2(920.0, 500.0, 160.0, 900.0)
	_assert(not aisle.intersects(case_stand), "Small Finds leaves the aisle open")
	_assert(not aisle.intersects(plants), "Plant Fossils leaves the aisle open")
	_assert(not aisle.intersects(left_a) and not aisle.intersects(left_b), "left stands leave the aisle open")
	_assert(not aisle.intersects(right_a) and not aisle.intersects(right_b), "right stands leave the aisle open")
	_assert(exhibit.stand_id_at(case_stand.get_center()) == "small_finds", "clicking the case hits Small Finds")
	_assert(exhibit.stand_id_at(plants.get_center()) == "plant_fossils", "clicking the plant case hits Plant Fossils")
	exhibit.free()


func _test_museum_click_unveils_then_spotlights() -> void:
	_reset()
	GS.install_find("triceratops_skull", "Triceratops Skull", 1.0, true)
	var mus: Node = (load("res://museum.gd") as GDScript).new()
	root.add_child(mus)
	var pad_pos: Vector2 = _pad_pos_for_stand(mus, "triceratops")
	mus._click_hall(pad_pos)
	_assert(not GS.stand_has_pending_unveil("triceratops"), "click unveils the ribboned bay")
	_assert(int(GS.money) == 0, "click starts a crowd surge, not a cash burst")
	_assert(float(GS.unveil_spike_left) > 0.0, "click starts the income spike")
	mus._click_hall(pad_pos)
	_assert(str(GS.featured_stand_id) == "triceratops", "second click spotlights the filled stand")
	mus.free()


func _test_museum_click_unveils_small_finds() -> void:
	_reset()
	GS.install_find("tooth", "Tooth", 1.0, true)
	var mus: Node = (load("res://museum.gd") as GDScript).new()
	root.add_child(mus)
	var pad_pos: Vector2 = _pad_pos_for_stand(mus, "small_finds")
	mus._click_hall(pad_pos)
	_assert(not GS.stand_has_pending_unveil("small_finds"), "click unveils the ribboned case")
	_assert(int(GS.money) == 0, "click starts a crowd surge, not a cash burst")
	mus._click_hall(pad_pos)
	_assert(str(GS.featured_stand_id) == "small_finds", "second click spotlights the case")
	mus.free()


func _hall_board(mus: Node) -> Dictionary:
	if mus == null:
		return {}
	var exhibit: Node = mus.get("_canvas") as Node
	if exhibit != null and exhibit.has_method("hall_board"):
		return exhibit.call("hall_board")
	return {}


func _header_stats(mus: Node) -> Dictionary:
	if mus != null and mus.has_method("header_stats"):
		return mus.call("header_stats")
	return {}


func _header_cluster_rect(mus: Node) -> Rect2:
	if mus != null and mus.has_method("header_cluster_rect"):
		return mus.call("header_cluster_rect")
	return Rect2()


func _header_label(mus: Node, name: String) -> Label:
	if mus == null:
		return null
	return mus.get(name) as Label


func _header_rate(line: String) -> float:
	var amount: String = _header_amount(line)
	if amount.is_empty():
		return -1.0
	return float(amount)


func _header_amount(line: String) -> String:
	var start: int = line.find("$")
	if start < 0:
		return ""
	var rest: String = line.substr(start + 1)
	var cut: int = rest.find(" ")
	if cut >= 0:
		rest = rest.substr(0, cut)
	return rest.strip_edges()


func _test_featured_small_finds_income_is_readable() -> void:
	_reset()
	GS.install_find("tooth", "Tooth", 1.0, true)
	GS.install_find("vertebra", "Vertebra", 0.4, false)
	GS.unveil_stand("small_finds")
	GS.unveil_spike_left = 0.0
	var dusty: float = float(GS.piece_income("vertebra"))
	var clean: float = float(GS.piece_income("tooth"))
	_assert(dusty > 0.0, "dusty vertebra still pays")
	_assert(dusty < clean, "dusty scrap pays less than a clean scrap")
	var base: float = float(GS.museum_income())
	_assert(bool(GS.set_featured_stand("small_finds")), "Small Finds can take the light")
	var featured: float = float(GS.museum_income())
	_assert(is_equal_approx(featured, base), "featuring without ranks does not multiply the case")
	_assert(featured >= 0.10, "featured Small Finds ticks at least ten cents a second")
	_set_spotlight_rank(1)
	_assert(is_equal_approx(float(GS.museum_income()), base * 2.0), "rank 1 doubles the featured case")
	var mus: Node = (load("res://museum.gd") as GDScript).new()
	root.add_child(mus)
	mus.visible = true
	mus._refresh()
	var line: String = str(_header_stats(mus).get("rate", ""))
	_assert(line.find("$0.0") < 0 or line.find("$0.00") < 0, "header does not show $0.0 while the case earns")
	_assert(_header_rate(line) >= 0.10, "the header prints the featured case rate")
	var cents: PackedStringArray = _header_amount(line).split(".")
	_assert(cents.size() == 2 and cents[1].length() == 2, "the header shows hundredths so a live tick cannot hide")
	mus.free()


func _test_dusty_featured_case_header_is_not_zero() -> void:
	_reset()
	GS.install_find("tooth", "Tooth", 0.0, false)
	GS.install_find("vertebra", "Vertebra", 0.2, false)
	GS.unveil_stand("small_finds")
	GS.unveil_spike_left = 0.0
	GS.set_featured_stand("small_finds")
	_assert(float(GS.museum_income()) >= 0.05, "two dusty scraps featured still tick")
	var mus: Node = (load("res://museum.gd") as GDScript).new()
	root.add_child(mus)
	mus.visible = true
	mus._refresh()
	var line: String = str(_header_stats(mus).get("rate", ""))
	_assert(line.find("$0.00") < 0, "dusty featured header is not $0.00")
	_assert(_header_rate(line) >= 0.05, "dusty featured header still reads as a tick")
	mus.free()


func _test_hall_title_is_a_wall_board() -> void:
	_reset()
	GS.install_find("triceratops_skull", "Triceratops Skull", 1.0, true)
	GS.unveil_stand("triceratops")
	GS.set_featured_stand("triceratops")
	var mus: Node = (load("res://museum.gd") as GDScript).new()
	root.add_child(mus)
	mus.visible = true
	mus._refresh()
	var exhibit: Node2D = mus._canvas
	_assert(exhibit.has_method("hall_board"), "the hall exposes a title board")
	_assert(exhibit.has_method("hall_board_rect"), "the title board has a wall rect")
	if not exhibit.has_method("hall_board") or not exhibit.has_method("hall_board_rect"):
		mus.free()
		return
	var card: Dictionary = exhibit.call("hall_board")
	_assert(str(card.get("title", "")) == "FOSSIL HALL", "the board still says FOSSIL HALL")
	_assert(str(card.get("featured_label", "")) == "Featured", "Featured is a caption")
	_assert(str(card.get("featured", "")) == "Triceratops", "featured name is only the stand")
	_assert(str(card.get("featured", "")).find("featured") < 0, "name is not Small Finds featured")
	_assert(str(card.get("visitors", "")).is_empty(), "visitor count left the wall board")
	_assert(str(card.get("rate", "")).is_empty(), "hall rate left the wall board")
	var board: Rect2 = exhibit.call("hall_board_rect")
	_assert(board.end.y <= 220.0, "the board stays on the north wall")
	_assert(not board.intersects(exhibit.stand_rect("t_rex")), "the board does not cover T. rex")
	_assert(not board.intersects(exhibit.stand_rect("small_finds")), "the board does not cover Small Finds")
	_assert(not board.intersects(exhibit.stand_rect("plant_fossils")), "the board does not cover Plant Fossils")
	_assert(exhibit.has_method("hall_board_featured_rect"), "the board has a featured box")
	if exhibit.has_method("hall_board_featured_rect"):
		var feat: Rect2 = exhibit.call("hall_board_featured_rect")
		_assert(feat.size.y >= board.size.y * 0.5, "featured grows to fill the board")
		_assert(feat.size.x >= board.size.x - 40.0, "featured spans the board")
		_assert(feat.position.y <= board.position.y + 50.0, "featured starts under the title")
	var stats: Dictionary = _header_stats(mus)
	_assert(str(stats.get("visitors", "")).is_valid_int(), "header visitor count is a bare number")
	_assert(str(stats.get("visitors_label", "")) == "visitors", "header visitors sits under the count")
	_assert(str(stats.get("each_value", "")).begins_with("$"), "header donation is its own $ amount")
	_assert(str(stats.get("each_label", "")) == "each", "header each is a caption, not glued to the $")
	_assert(str(stats.get("rate", "")).begins_with("$"), "header hall rate is its own $ amount")
	_assert(str(stats.get("rate_label", "")) == "/ sec", "header / sec sits under the rate")
	mus.free()


func _test_header_shows_visitors_each_rate_as_separate_fields() -> void:
	_reset()
	GS.install_find("triceratops_skull", "Triceratops Skull", 1.0, true)
	GS.unveil_stand("triceratops")
	GS.set_featured_stand("triceratops")
	var mus: Node = (load("res://museum.gd") as GDScript).new()
	root.add_child(mus)
	mus.visible = true
	mus._refresh()
	_assert(mus.has_method("header_stats"), "museum exposes header stats")
	var stats: Dictionary = _header_stats(mus)
	_assert(str(stats.get("visitors", "")).is_valid_int(), "visitor count is its own field")
	_assert(str(stats.get("visitors_label", "")) == "visitors", "visitors is a caption, not jammed onto the count")
	_assert(str(stats.get("each_value", "")).begins_with("$"), "donation is its own $ field")
	_assert(str(stats.get("each_label", "")) == "each", "each is its own caption")
	_assert(str(stats.get("rate", "")).begins_with("$"), "hall rate is its own $ field")
	_assert(str(stats.get("rate_label", "")) == "/ sec", "/ sec is its own caption")
	_assert(str(stats.get("rate", "")).find("visitors") < 0, "rate is not a jammed crowd sentence")
	_assert(str(stats.get("rate", "")).find("each") < 0, "rate does not swallow each")
	var visitors: Label = _header_label(mus, "_visitors")
	var visitors_cap: Label = _header_label(mus, "_visitors_cap")
	var each: Label = _header_label(mus, "_each")
	var each_cap: Label = _header_label(mus, "_each_cap")
	var rate: Label = _header_label(mus, "_rate")
	var rate_cap: Label = _header_label(mus, "_rate_cap")
	_assert(visitors != null and visitors.visible, "visitor count is its own header label")
	_assert(visitors_cap != null and visitors_cap.visible, "visitors caption is its own header label")
	_assert(each != null and each.visible, "donation is its own header label")
	_assert(each_cap != null and each_cap.visible, "each caption is its own header label")
	_assert(rate != null and rate.visible, "hall rate is its own header label")
	_assert(rate_cap != null and rate_cap.visible, "/ sec caption is its own header label")
	if visitors != null:
		_assert(str(visitors.text).find("visitors") < 0, "count label is not jammed with visitors")
		_assert(str(visitors.text).find("each") < 0, "count label is not a run-on gold sentence")
	if rate != null:
		_assert(str(rate.text).find("/ sec") < 0, "rate $ is not jammed with / sec")
		_assert(str(rate.text).find("visitors") < 0, "rate label is not 166visitors")
	mus.free()


func _test_wall_board_is_title_and_featured() -> void:
	_reset()
	GS.install_find("triceratops_skull", "Triceratops Skull", 1.0, true)
	GS.unveil_stand("triceratops")
	GS.set_featured_stand("triceratops")
	var mus: Node = (load("res://museum.gd") as GDScript).new()
	root.add_child(mus)
	mus.visible = true
	mus._refresh()
	var exhibit: Node2D = mus._canvas
	var card: Dictionary = _hall_board(mus)
	_assert(str(card.get("title", "")) == "FOSSIL HALL", "the wall board keeps the hall title")
	_assert(str(card.get("featured_label", "")) == "Featured", "the wall board keeps a Featured caption")
	_assert(str(card.get("featured", "")) == "Triceratops", "the wall board names the featured stand")
	_assert(exhibit.has_method("hall_board_featured_rect"), "featured has a wall box")
	if exhibit.has_method("hall_board_featured_rect"):
		var board: Rect2 = exhibit.call("hall_board_rect")
		var feat: Rect2 = exhibit.call("hall_board_featured_rect")
		_assert(feat.size.y >= board.size.y * 0.5, "featured grows to fill the wall box")
		_assert(feat.size.x >= board.size.x - 40.0, "featured fills the board width")
		_assert(feat.position.y >= board.position.y + 20.0, "featured sits under the title")
		_assert(feat.end.y <= board.end.y + 0.5, "featured stays inside the board")
	mus.free()


func _hall_to_screen(mus: Node, hall: Rect2) -> Rect2:
	var exhibit: Node2D = mus.get("_canvas") as Node2D
	if exhibit == null:
		return Rect2()
	return Rect2(exhibit.position + hall.position * exhibit.scale, hall.size * exhibit.scale)


func _test_empty_display_sits_at_screen_bottom() -> void:
	_reset()
	var mus: Node = (load("res://museum.gd") as GDScript).new()
	root.add_child(mus)
	mus.visible = true
	mus._refresh()
	_assert(mus.has_method("empty_display_rect"), "museum exposes the empty-display rect")
	if not mus.has_method("empty_display_rect"):
		mus.free()
		return
	var status: Rect2 = mus.call("empty_display_rect")
	var view: Vector2 = mus._view()
	var exhibit: Node2D = mus._canvas
	var board: Rect2 = exhibit.call("hall_board_rect")
	_assert(status.size.x > 1.0 and status.size.y > 1.0, "empty display has size")
	_assert(status.position.y >= view.y * 0.75, "empty display sits in the lower quarter of the museum view")
	_assert(status.end.y <= view.y + 0.5, "empty display stays on the museum view")
	_assert(status.position.y > float(mus.HEADER_H), "empty display stays under the header")
	_assert(absf(status.get_center().x - view.x * 0.5) <= 24.0, "empty display is centered on the view")
	_assert(not status.intersects(board), "empty display is not painted on the FOSSIL HALL board")
	_assert(not status.intersects(_hall_to_screen(mus, board)), "empty display does not cover Featured")
	_assert(not status.intersects(_hall_to_screen(mus, exhibit.stand_rect("t_rex"))), "empty display does not cover T. rex")
	for bench in exhibit.call("hall_bench_rects"):
		_assert(not status.intersects(_hall_to_screen(mus, bench)), "empty display does not cover a bench")
	_assert(mus.has_method("empty_display_line"), "museum exposes the empty-display line")
	var line: String = str(mus.call("empty_display_line")) if mus.has_method("empty_display_line") else ""
	_assert(line.find("Nothing") >= 0 and line.find("on display") >= 0 and line.find("yet") >= 0, "empty display says Nothing on display yet")
	_assert(str(_hall_board(mus).get("status", "")).find("Nothing on display") < 0, "the wall board does not own the bottom line")
	var words: PackedStringArray = PackedStringArray()
	for name in ["_empty_lead", "_empty_mid", "_empty_tail"]:
		var label: Label = mus.get(name) as Label
		if label != null and label.visible and not str(label.text).is_empty():
			words.append(str(label.text))
	_assert(words.size() >= 2, "empty display keeps words on separate labels")
	if words.size() >= 2:
		_assert(" ".join(words).find("Nothing") >= 0, "split labels still say Nothing")
		_assert(" ".join(words).find("yet") >= 0, "split labels still say yet")
	mus.free()


func _test_featured_mount_hides_empty_display() -> void:
	_reset()
	GS.install_find("triceratops_skull", "Triceratops Skull", 1.0, true)
	GS.unveil_stand("triceratops")
	GS.set_featured_stand("triceratops")
	var mus: Node = (load("res://museum.gd") as GDScript).new()
	root.add_child(mus)
	mus.visible = true
	mus._refresh()
	_assert(mus.has_method("empty_display_rect"), "museum still exposes the empty-display rect")
	var status: Rect2 = mus.call("empty_display_rect") if mus.has_method("empty_display_rect") else Rect2()
	_assert(status.size == Vector2.ZERO, "featured mount hides Nothing on display yet")
	var card: Dictionary = _hall_board(mus)
	_assert(str(card.get("featured_label", "")) == "Featured", "board keeps Featured")
	_assert(str(card.get("featured", "")) == "Triceratops", "board names Triceratops")
	_assert(str(card.get("status", "")).find("Nothing") < 0, "board does not also say Nothing on display yet")
	var exhibit: Node2D = mus._canvas
	_assert(exhibit.call("hall_hours_rect").size == Vector2.ZERO, "Hours stays off the board")
	mus._click_hall(_pad_pos_for_stand(mus, "velociraptor"))
	var after: Rect2 = mus.call("empty_display_rect") if mus.has_method("empty_display_rect") else Rect2()
	_assert(after.size == Vector2.ZERO, "empty-stand click does not summon the line over Featured")
	var banner: Label = mus.get("_banner") as Label
	if banner != null and banner.visible:
		_assert(str(banner.text).find("Nothing on display") < 0, "toast does not reprint Nothing on display yet over Featured")
	mus.free()


func _test_board_does_not_own_visitor_rate_numbers() -> void:
	_reset()
	GS.install_find("triceratops_skull", "Triceratops Skull", 1.0, true)
	GS.unveil_stand("triceratops")
	GS.set_featured_stand("triceratops")
	var mus: Node = (load("res://museum.gd") as GDScript).new()
	root.add_child(mus)
	mus.visible = true
	mus._refresh()
	var card: Dictionary = _hall_board(mus)
	_assert(str(card.get("visitors", "")).is_empty(), "the wall board does not own the visitor count")
	_assert(str(card.get("visitors_label", "")).is_empty(), "the wall board does not own the visitors caption")
	_assert(str(card.get("each_value", "")).is_empty(), "the wall board does not own $ each")
	_assert(str(card.get("each_label", "")).is_empty(), "the wall board does not own the each caption")
	_assert(str(card.get("rate", "")).is_empty(), "the wall board does not own hall $/sec")
	_assert(str(card.get("rate_label", "")).is_empty(), "the wall board does not own / sec")
	_assert(str(card.get("rush", "")).is_empty(), "crowd surge left the wall board")
	var stats: Dictionary = _header_stats(mus)
	_assert(str(stats.get("visitors", "")).is_valid_int(), "the header owns the visitor count")
	_assert(str(stats.get("rate", "")).begins_with("$"), "the header owns hall $/sec")
	mus.free()


func _test_header_cluster_stays_in_bar_and_clear_of_nav() -> void:
	_reset()
	GS.install_find("triceratops_skull", "Triceratops Skull", 1.0, true)
	GS.unveil_stand("triceratops")
	GS.set_featured_stand("triceratops")
	var mus: Node = (load("res://museum.gd") as GDScript).new()
	root.add_child(mus)
	mus.visible = true
	var settings: Node = root.get_node_or_null("Settings")
	if settings != null:
		if settings.has_method("set_nav_visible"):
			settings.call("set_nav_visible", true)
		if settings.has_method("set_nav_context"):
			settings.call("set_nav_context", "museum")
		if settings.has_method("_layout_nav_chrome"):
			settings.call("_layout_nav_chrome")
	mus._refresh()
	_assert(mus.has_method("header_cluster_rect"), "museum exposes the header cluster")
	var cluster: Rect2 = _header_cluster_rect(mus)
	_assert(cluster.size.x > 1.0 and cluster.size.y > 1.0, "header cluster has size")
	_assert(cluster.position.y >= 0.0, "header cluster starts in the bar")
	_assert(cluster.end.y <= float(mus.HEADER_H) + 0.5, "header cluster stays in HEADER_H")
	_assert(is_equal_approx(float(mus.HEADER_H), 86.0), "museum header stays 86px")
	if settings != null:
		if settings.has_method("overlay_content_left"):
			_assert(cluster.position.x >= float(settings.call("overlay_content_left")) - 0.5, "cluster stays right of the wallet")
		if settings.has_method("overlay_content_right"):
			_assert(cluster.end.x <= float(settings.call("overlay_content_right")) + 0.5, "cluster stays left of Dig/Upgrades/Menu")
		var nav: Control = settings.get("_nav_bar") as Control
		_assert(nav != null, "hall nav lives in the shared header")
		if nav != null:
			var nav_r: Rect2 = Rect2(nav.global_position, nav.size)
			_assert(cluster.end.x <= nav_r.position.x - 4.0, "header cluster stays clear of Dig/Upgrades/Menu")
			_assert(not cluster.intersects(nav_r), "header cluster does not cover the overlay nav")
		var back: Control = settings.get("_back_btn") as Control
		_assert(back == null or not back.visible, "hall overlay drops Back")
	mus.free()


func _test_header_names_a_mounted_tooth() -> void:
	_reset()
	GS.install_find("tooth", "Tooth", 0.0, false)
	GS.unveil_stand("small_finds")
	var mus: Node = (load("res://museum.gd") as GDScript).new()
	root.add_child(mus)
	mus.visible = true
	mus._refresh()
	var card: Dictionary = _hall_board(mus)
	_assert(str(card.get("status", "")).find("waiting") < 0, "a mounted tooth is not an empty hall")
	_assert(str(card.get("status", "")).find("dusty") >= 0, "the title board admits the tooth is dusty")
	mus.free()


func _test_header_shows_featured_name_and_income() -> void:
	_reset()
	GS.install_find("triceratops_skull", "Triceratops Skull", 1.0, true)
	GS.unveil_stand("triceratops")
	GS.set_featured_stand("triceratops")
	var mus: Node = (load("res://museum.gd") as GDScript).new()
	root.add_child(mus)
	mus.visible = true
	mus._refresh()
	var card: Dictionary = _hall_board(mus)
	var stats: Dictionary = _header_stats(mus)
	_assert(str(card.get("featured", "")).find("Triceratops") >= 0, "the title board names the featured stand")
	_assert(str(stats.get("rate", "")).find("$") >= 0, "the header shows exhibit income")
	mus.free()


func _pad_pos_for_stand(mus: Node, stand_id: String) -> Vector2:
	var exhibit: Node2D = mus._canvas
	var stand: Rect2 = exhibit.stand_rect(stand_id)
	var zoom: float = exhibit.scale.x
	return stand.get_center() * zoom - Vector2(0.0, mus.HEADER_H) + mus._pan


func _wheel_hall(mus: Node, button: MouseButton, times: int = 1) -> void:
	for _i in times:
		var mb := InputEventMouseButton.new()
		mb.button_index = button
		mb.pressed = true
		mb.factor = 1.0
		mb.position = Vector2(400.0, 220.0)
		mus._on_hall_gui_input(mb)


func _test_wheel_zooms_instead_of_panning() -> void:
	var mus: Node = (load("res://museum.gd") as GDScript).new()
	root.add_child(mus)
	mus.visible = true
	_wheel_hall(mus, MOUSE_BUTTON_WHEEL_UP, 4)
	var pan_before: Vector2 = mus._pan
	var scale_before: float = mus._canvas.scale.x
	_wheel_hall(mus, MOUSE_BUTTON_WHEEL_DOWN, 1)
	_assert(mus._canvas.scale.x < scale_before - 0.01, "wheel down zooms the hall out")
	_assert(not is_equal_approx(absf(mus._pan.y - pan_before.y), 72.0), "wheel does not aisle-pan 72px")
	var out_scale: float = mus._canvas.scale.x
	_wheel_hall(mus, MOUSE_BUTTON_WHEEL_UP, 1)
	_assert(mus._canvas.scale.x > out_scale + 0.01, "wheel up zooms the hall in")
	mus.free()


func _wide_museum() -> Node:
	root.get_viewport().size = Vector2i(1280, 720)
	var mus: Node = (load("res://museum.gd") as GDScript).new()
	root.add_child(mus)
	mus.visible = true
	mus._on_view_resized()
	return mus


func _hall_width_fit(mus: Node) -> float:
	return mus._view().x / 2000.0


func _test_default_zoom_fits_hall_width() -> void:
	var mus: Node = _wide_museum()
	var width_fit: float = _hall_width_fit(mus)
	_assert(is_equal_approx(mus._zoom, mus._zoom_min()), "default zoom equals min zoom")
	_assert(is_equal_approx(mus._zoom, width_fit), "default zoom is the hall-width fit")
	var hall_w: float = 2000.0 * mus._canvas.scale.x
	_assert(absf(hall_w - mus._view().x) <= 1.0, "opening the hall fills the window width")
	mus.free()


func _test_min_zoom_fits_hall_width() -> void:
	var mus: Node = _wide_museum()
	_wheel_hall(mus, MOUSE_BUTTON_WHEEL_DOWN, 24)
	var zoom: float = mus._canvas.scale.x
	var view: Vector2 = mus._view()
	var hall_px: Vector2 = Vector2(2000.0, 1480.0) * zoom
	_assert(is_equal_approx(zoom, mus._zoom_min()), "wheel-out stops at min zoom")
	_assert(is_equal_approx(zoom, _hall_width_fit(mus)), "min zoom is viewport width over hall width")
	_assert(hall_px.x <= view.x + 1.0, "zoomed-out hall fits the window width")
	_assert(hall_px.x >= view.x - 1.0, "zoomed-out hall fills the window width")
	_assert(hall_px.y > view.y + 1.0, "zoomed-out hall is taller than the window")
	mus.free()


func _test_cannot_zoom_out_past_hall_width() -> void:
	var mus: Node = _wide_museum()
	_wheel_hall(mus, MOUSE_BUTTON_WHEEL_UP, 6)
	_assert(mus._zoom > mus._zoom_min() + 0.01, "wheel still zooms in from the width fit")
	_wheel_hall(mus, MOUSE_BUTTON_WHEEL_DOWN, 24)
	_assert(mus._zoom >= _hall_width_fit(mus) - 0.001, "cannot zoom out past the hall width")
	_assert(is_equal_approx(mus._zoom, mus._zoom_min()), "zoom-out clamp matches min zoom")
	mus.free()


func _test_max_zoom_is_close_on_a_stand() -> void:
	var mus: Node = (load("res://museum.gd") as GDScript).new()
	root.add_child(mus)
	mus.visible = true
	_wheel_hall(mus, MOUSE_BUTTON_WHEEL_UP, 24)
	var zoom: float = mus._canvas.scale.x
	_assert(zoom >= 1.6, "max zoom is closer than a wide hall shot")
	var stand_w: float = 480.0 * zoom
	_assert(stand_w >= 700.0, "a T. rex bay fills the view when zoomed in")
	_assert(2000.0 * zoom > mus._view().x, "max zoom is tighter than the full hall")
	mus.free()


func _test_click_after_zoom_still_hits_the_stand() -> void:
	_reset()
	GS.install_find("triceratops_skull", "Triceratops Skull", 1.0, true)
	var mus: Node = (load("res://museum.gd") as GDScript).new()
	root.add_child(mus)
	mus.visible = true
	_wheel_hall(mus, MOUSE_BUTTON_WHEEL_UP, 8)
	var pad_pos: Vector2 = _pad_pos_for_stand(mus, "triceratops")
	mus._click_hall(pad_pos)
	_assert(not GS.stand_has_pending_unveil("triceratops"), "zoomed click still unveils the stand under the cursor")
	mus._click_hall(pad_pos)
	_assert(str(GS.featured_stand_id) == "triceratops", "zoomed click still spotlights that stand")
	mus.free()


func _test_drag_pans_while_zoomed() -> void:
	var mus: Node = (load("res://museum.gd") as GDScript).new()
	root.add_child(mus)
	mus.visible = true
	_wheel_hall(mus, MOUSE_BUTTON_WHEEL_UP, 8)
	var pan_before: Vector2 = mus._pan
	mus._pressing = true
	mus._dragging = true
	var mm := InputEventMouseMotion.new()
	mm.relative = Vector2(-80.0, 40.0)
	mus._input(mm)
	_assert(mus._pan != pan_before, "click-drag still pans after zoom")
	mus.free()


func _test_pan_cannot_leave_the_hall() -> void:
	var mus: Node = (load("res://museum.gd") as GDScript).new()
	root.add_child(mus)
	mus.visible = true
	_wheel_hall(mus, MOUSE_BUTTON_WHEEL_UP, 8)
	var zoom: float = mus._canvas.scale.x
	var clamped: Vector2 = mus._clamp_pan(Vector2(8000.0, -8000.0))
	var hall := Rect2(clamped, Vector2(2000.0, 1480.0) * zoom)
	var view: Vector2 = mus._view()
	var pad := Rect2(0.0, 0.0, view.x, view.y)
	_assert(hall.intersects(pad), "clamped pan still keeps the hall on screen")
	mus.free()


func _test_new_skull_is_pending_unveil() -> void:
	_reset()
	GS.install_find("triceratops_skull", "Triceratops Skull", 1.0, true)
	_assert(GS.stand_for_piece("triceratops_skull") == "triceratops", "skull maps to Triceratops bay")
	_assert(GS.stand_has_pending_unveil("triceratops"), "new skull waits under a ribbon")
	_assert(not GS.stand_has_pending_unveil("t_rex"), "other bays stay uncovered")


func _test_scraps_mount_in_small_finds() -> void:
	_reset()
	GS.install_find("tooth", "Tooth", 1.0, true)
	GS.install_find("vertebra", "Vertebra", 0.4, false)
	_assert(GS.stand_for_piece("tooth") == "small_finds", "tooth maps to the Small Finds case")
	_assert(GS.stand_for_piece("vertebra") == "small_finds", "vertebra maps to the Small Finds case")
	_assert(GS.stand_has_pending_unveil("small_finds"), "scraps raise a ribbon on the case")
	_assert(bool(GS.set_featured_stand("small_finds")), "filled Small Finds can be featured")
	_assert(float(GS.piece_income("tooth")) > 0.0, "tooth still earns")
	_assert(float(GS.piece_income("vertebra")) > 0.0, "vertebra still earns")


func _test_old_save_piece_is_not_pending() -> void:
	_reset()
	GS.pieces["triceratops_skull"] = {
		"name": "Triceratops Skull",
		"cleanliness": 1.0,
		"clean": true,
	}
	_assert(GS.stand_is_filled("triceratops"), "old skull still fills the bay")
	_assert(not GS.stand_has_pending_unveil("triceratops"), "old saves are not ribboned")


func _test_empty_stands_never_pending() -> void:
	_reset()
	_assert(not GS.stand_is_filled("t_rex"), "T. rex starts empty")
	_assert(not GS.stand_has_pending_unveil("t_rex"), "empty stands never have ribbons")
	_assert(not GS.stand_has_pending_unveil("brachiosaurus"), "empty sauropod has no ribbon")


func _test_duplicate_does_not_reflag_after_unveil() -> void:
	_reset()
	GS.install_find("triceratops_skull", "Triceratops Skull", 1.0, true)
	GS.unveil_stand("triceratops")
	_assert(int(GS.call("surge_visitors")) > 0, "first unveil packs a crowd")
	_assert(not GS.stand_has_pending_unveil("triceratops"), "ribbon is gone after unveil")
	var money_after: int = int(GS.money)
	GS.install_find("triceratops_skull", "Triceratops Skull", 1.0, true)
	_assert(not GS.stand_has_pending_unveil("triceratops"), "duplicate does not re-ribbon")
	_assert(int(GS.money) > money_after, "duplicate still sells")


func _test_empty_stand_cannot_be_featured() -> void:
	_reset()
	_assert(not bool(GS.set_featured_stand("t_rex")), "empty stand cannot be featured")
	_assert(str(GS.featured_stand_id) == "", "featured stays empty")


func _test_filled_stand_can_be_featured() -> void:
	_reset()
	GS.install_find("triceratops_skull", "Triceratops Skull", 1.0, true)
	_assert(bool(GS.set_featured_stand("triceratops")), "filled stand can be featured")
	_assert(str(GS.featured_stand_id) == "triceratops", "featured id is stored")


func _test_featuring_again_keeps_featured() -> void:
	_reset()
	GS.install_find("triceratops_skull", "Triceratops Skull", 1.0, true)
	GS.set_featured_stand("triceratops")
	_assert(bool(GS.set_featured_stand("triceratops")), "clicking featured again stays featured")
	_assert(str(GS.featured_stand_id) == "triceratops", "featured is not toggled off")


func _test_empty_stand_does_not_steal_spotlight() -> void:
	_reset()
	GS.install_find("triceratops_skull", "Triceratops Skull", 1.0, true)
	GS.set_featured_stand("triceratops")
	_assert(not bool(GS.set_featured_stand("velociraptor")), "empty aisle stands cannot take the light")
	_assert(str(GS.featured_stand_id) == "triceratops", "spotlight stays on the filled bay")


func _test_spotlight_does_not_multiply_without_ranks() -> void:
	_reset()
	GS.install_find("triceratops_skull", "Triceratops Skull", 1.0, true)
	GS.install_find("tooth", "Tooth", 1.0, true)
	GS.unveil_spike_left = 0.0
	var base: float = float(GS.museum_income())
	var skull: float = float(GS.piece_income("triceratops_skull"))
	GS.set_featured_stand("triceratops")
	var featured: float = float(GS.museum_income())
	_assert(is_equal_approx(featured, base), "0 ranks keep featured income at 1x")
	_assert(is_equal_approx(float(GS.stand_income("triceratops")), skull), "featured stand stays 1x until bought")
	_assert(is_equal_approx(float(TN.spotlight_mult), 1.0), "unbought spotlight multiplier is 1x")


func _test_spotlight_rank_one_is_2x() -> void:
	_reset()
	GS.install_find("triceratops_skull", "Triceratops Skull", 1.0, true)
	GS.install_find("tooth", "Tooth", 1.0, true)
	GS.unveil_spike_left = 0.0
	var base: float = float(GS.museum_income())
	var skull: float = float(GS.piece_income("triceratops_skull"))
	_set_spotlight_rank(1)
	GS.set_featured_stand("triceratops")
	var featured: float = float(GS.museum_income())
	_assert(is_equal_approx(featured, base + skull), "rank 1 adds one extra copy of that stand")
	_assert(is_equal_approx(float(GS.stand_income("triceratops")), skull * 2.0), "rank 1 featured stand reads as 2x")
	_assert(is_equal_approx(float(GS.stand_income("small_finds")), float(GS.piece_income("tooth"))), "other stands stay 1x")


func _test_spotlight_rank_two_is_3x() -> void:
	_reset()
	GS.install_find("triceratops_skull", "Triceratops Skull", 1.0, true)
	GS.unveil_spike_left = 0.0
	var skull: float = float(GS.piece_income("triceratops_skull"))
	_set_spotlight_rank(2)
	GS.set_featured_stand("triceratops")
	_assert(is_equal_approx(float(GS.stand_income("triceratops")), skull * 3.0), "rank 2 featured stand reads as 3x")


func _test_spotlight_rank_three_is_4x() -> void:
	_reset()
	GS.install_find("triceratops_skull", "Triceratops Skull", 1.0, true)
	GS.unveil_spike_left = 0.0
	var skull: float = float(GS.piece_income("triceratops_skull"))
	_set_spotlight_rank(3)
	GS.set_featured_stand("triceratops")
	_assert(is_equal_approx(float(GS.stand_income("triceratops")), skull * 4.0), "rank 3 featured stand reads as 4x")


func _test_blockbuster_featured_reaches_five_or_six() -> void:
	_reset()
	GS.install_find("triceratops_skull", "Triceratops Skull", 1.0, true)
	GS.unveil_spike_left = 0.0
	var skull: float = float(GS.piece_income("triceratops_skull"))
	_set_spotlight_rank(3)
	GS.levels["blockbuster_feature"] = 2
	GS.apply_upgrades()
	GS.set_featured_stand("triceratops")
	_assert(float(TN.spotlight_mult) >= 5.0, "Blockbuster featured ranks reach at least 5x")
	_assert(float(TN.spotlight_mult) <= 6.0, "Blockbuster featured ranks stay at or under 6x")
	_assert(float(GS.stand_income("triceratops")) >= skull * 5.0 - 0.0001, "featured stand pays at least 5x after Blockbuster")


func _test_click_still_features_without_ranks() -> void:
	_reset()
	GS.install_find("triceratops_skull", "Triceratops Skull", 1.0, true)
	var mus: Node = (load("res://museum.gd") as GDScript).new()
	root.add_child(mus)
	var pad_pos: Vector2 = _pad_pos_for_stand(mus, "triceratops")
	mus._click_hall(pad_pos)
	mus._click_hall(pad_pos)
	_assert(str(GS.featured_stand_id) == "triceratops", "click still picks the featured stand with 0 ranks")
	mus.free()


func _test_plaque_hides_mult_until_bought() -> void:
	_reset()
	GS.install_find("t_rex_tail", "T. rex Tail", 1.0, true)
	GS.set_featured_stand("t_rex")
	var exhibit: Node2D = Node2D.new()
	exhibit.set_script(load("res://museum_exhibit.gd"))
	root.add_child(exhibit)
	_assert(exhibit.has_method("plaque_title_for"), "exhibit names the plaque")
	if exhibit.has_method("plaque_title_for"):
		var title: String = str(exhibit.call("plaque_title_for", "t_rex"))
		_assert(title == "T. rex", "0-rank plaque is just the stand name")
		_assert(title.find("2x") < 0 and title.find("3x") < 0 and title.find("4x") < 0, "0-rank plaque hides the multiplier")
	exhibit.free()


func _test_plaque_shows_owned_mult() -> void:
	_reset()
	GS.install_find("t_rex_tail", "T. rex Tail", 1.0, true)
	GS.set_featured_stand("t_rex")
	_set_spotlight_rank(2)
	var exhibit: Node2D = Node2D.new()
	exhibit.set_script(load("res://museum_exhibit.gd"))
	root.add_child(exhibit)
	if exhibit.has_method("plaque_title_for"):
		var title: String = str(exhibit.call("plaque_title_for", "t_rex"))
		_assert(title.find("T. rex") >= 0, "owned-rank plaque still names the stand")
		_assert(title.find("3x") >= 0, "owned-rank plaque shows 3x")
	exhibit.free()


func _test_spotlight_beam_scales_with_rank() -> void:
	var exhibit: Node2D = Node2D.new()
	exhibit.set_script(load("res://museum_exhibit.gd"))
	root.add_child(exhibit)
	_assert(exhibit.has_method("spotlight_beam_scale"), "exhibit exposes beam scale")
	if not exhibit.has_method("spotlight_beam_scale"):
		exhibit.free()
		return
	_reset()
	var dim: float = float(exhibit.call("spotlight_beam_scale"))
	_set_spotlight_rank(1)
	var two: float = float(exhibit.call("spotlight_beam_scale"))
	_set_spotlight_rank(2)
	var three: float = float(exhibit.call("spotlight_beam_scale"))
	_set_spotlight_rank(3)
	var four: float = float(exhibit.call("spotlight_beam_scale"))
	_assert(two > dim, "2x beam is stronger than an unbought light")
	_assert(three > two, "3x beam is stronger than 2x")
	_assert(four > three, "4x beam is stronger than 3x")
	exhibit.free()


func _test_spotlight_is_one_cone_on_the_featured_stand() -> void:
	_reset()
	GS.install_find("brachiosaurus_skull", "Brachiosaurus Skull", 1.0, true)
	GS.unveil_stand("brachiosaurus")
	GS.set_featured_stand("brachiosaurus")
	_set_spotlight_rank(3)
	GS.levels["lighting"] = 5
	GS.apply_upgrades()
	var exhibit: Node2D = Node2D.new()
	exhibit.set_script(load("res://museum_exhibit.gd"))
	root.add_child(exhibit)
	_assert(exhibit.has_method("hall_spotlight_cones"), "exhibit exposes spotlight cones")
	_assert(exhibit.has_method("hall_spotlight_discs"), "exhibit exposes spotlight discs")
	if not exhibit.has_method("hall_spotlight_cones") or not exhibit.has_method("hall_spotlight_discs"):
		exhibit.free()
		return
	var cones: Array = exhibit.call("hall_spotlight_cones")
	var discs: Array = exhibit.call("hall_spotlight_discs")
	_assert(cones.size() == 1, "featured stand gets one spotlight cone")
	_assert(discs.size() == 1, "featured stand gets one spotlight disc")
	var board: Rect2 = exhibit.call("hall_board_rect")
	var feat: Rect2 = exhibit.call("hall_board_featured_rect")
	var stand: Rect2 = exhibit.stand_rect("brachiosaurus")
	var cone: PackedVector2Array = cones[0]
	_assert(cone.size() == 3, "the spotlight cone is a single triangle")
	var cone_box: Rect2 = _poly_bbox(cone)
	_assert(cone_box.intersects(stand), "the spotlight cone hits the featured stand")
	_assert(not cone_box.intersects(board), "the spotlight cone stays off the FOSSIL HALL board")
	_assert(not cone_box.intersects(feat), "the spotlight cone stays off the Featured name")
	if exhibit.has_method("hall_lamp_discs"):
		for glow in exhibit.call("hall_lamp_discs"):
			_assert(not feat.intersects(glow), "lamp glow stays off the Featured name while a stand is lit")
			_assert(not board.encloses(glow), "no lamp blob sits on the FOSSIL HALL board")
	GS.install_find("t_rex_skull", "T. rex Skull", 1.0, true)
	GS.unveil_stand("t_rex")
	GS.set_featured_stand("t_rex")
	var rex_cones: Array = exhibit.call("hall_spotlight_cones")
	_assert(rex_cones.size() == 1, "T. rex still gets one spotlight cone")
	var rex_box: Rect2 = _poly_bbox(rex_cones[0])
	_assert(rex_box.intersects(exhibit.stand_rect("t_rex")), "T. rex cone still hits its stand")
	_assert(not rex_box.intersects(board), "T. rex cone does not wash the hall board")
	exhibit.free()


func _test_featured_spotlight_circle_centers_on_the_dino() -> void:
	_reset()
	GS.install_find("stegosaurus_skull", "Stegosaurus Skull", 1.0, true)
	GS.unveil_stand("stegosaurus")
	GS.set_featured_stand("stegosaurus")
	_set_spotlight_rank(3)
	GS.levels["lighting"] = 5
	GS.apply_upgrades()
	var exhibit: Node2D = Node2D.new()
	exhibit.set_script(load("res://museum_exhibit.gd"))
	root.add_child(exhibit)
	_assert(exhibit.has_method("hall_spotlight_discs"), "exhibit exposes spotlight discs")
	_assert(exhibit.has_method("hall_spotlight_cones"), "exhibit exposes spotlight cones")
	if not exhibit.has_method("hall_spotlight_discs") or not exhibit.has_method("hall_spotlight_cones"):
		exhibit.free()
		return
	var discs: Array = exhibit.call("hall_spotlight_discs")
	var cones: Array = exhibit.call("hall_spotlight_cones")
	_assert(discs.size() == 1, "fully upgraded featured stand gets exactly one spotlight disc")
	_assert(cones.size() == 1, "fully upgraded featured stand still gets one cone")
	if discs.is_empty() or cones.is_empty():
		exhibit.free()
		return
	var mount: Rect2 = _stand_mount_rect(exhibit, "stegosaurus")
	var content: Vector2 = mount.get_center()
	var disc: Rect2 = discs[0]
	_assert(disc.get_center().distance_to(content) <= 16.0, "spotlight disc is centered on the dinosaur")
	_assert(mount.has_point(disc.get_center()), "spotlight disc sits on the silhouette, not the plaque or top frame")
	_assert(not exhibit.call("plaque_rect", "stegosaurus").has_point(disc.get_center()), "spotlight disc is not parked on the plaque")
	var board: Rect2 = exhibit.call("hall_board_rect")
	var feat: Rect2 = exhibit.call("hall_board_featured_rect")
	_assert(not disc.intersects(board), "spotlight disc stays off the FOSSIL HALL board")
	_assert(not feat.intersects(disc), "spotlight disc stays off the Featured name")
	var cone: PackedVector2Array = cones[0]
	_assert(cone.size() == 3, "the spotlight cone is a single triangle")
	_assert(absf(cone[0].x - content.x) <= 8.0, "cone apex is aimed at the dinosaur")
	_assert(cone[0].y < mount.position.y, "cone apex sits above the stand")
	_assert(_point_in_triangle(content, cone), "cone covers the dinosaur center")
	_assert(cone[1].distance_to(content) <= 100.0, "cone left base aims at the dinosaur, not the stand rim")
	_assert(cone[2].distance_to(content) <= 100.0, "cone right base aims at the dinosaur, not the stand rim")
	GS.install_find("t_rex_skull", "T. rex Skull", 1.0, true)
	GS.unveil_stand("t_rex")
	_assert(exhibit.call("hall_spotlight_discs").size() == 1, "4x does not spawn extra discs on other stands")
	_assert_no_glow_disc_on_stand(exhibit, "t_rex")
	GS.set_featured_stand("t_rex")
	var rex_discs: Array = exhibit.call("hall_spotlight_discs")
	_assert(rex_discs.size() == 1, "featuring T. rex still yields one disc")
	if not rex_discs.is_empty():
		var rex_content: Vector2 = _stand_mount_rect(exhibit, "t_rex").get_center()
		_assert((rex_discs[0] as Rect2).get_center().distance_to(rex_content) <= 16.0, "T. rex disc is centered on its silhouette")
	_assert_no_glow_disc_on_stand(exhibit, "stegosaurus")
	exhibit.free()


func _stand_mount_rect(exhibit: Node2D, stand_id: String) -> Rect2:
	if exhibit.has_method("stand_mount_rect"):
		return exhibit.call("stand_mount_rect", stand_id)
	var stand: Rect2 = exhibit.stand_rect(stand_id)
	return Rect2(stand.position + Vector2(22.0, 16.0), stand.size - Vector2(44.0, 54.0))


func _point_in_triangle(pt: Vector2, tri: PackedVector2Array) -> bool:
	if tri.size() < 3:
		return false
	var v0: Vector2 = tri[2] - tri[0]
	var v1: Vector2 = tri[1] - tri[0]
	var v2: Vector2 = pt - tri[0]
	var dot00: float = v0.dot(v0)
	var dot01: float = v0.dot(v1)
	var dot02: float = v0.dot(v2)
	var dot11: float = v1.dot(v1)
	var dot12: float = v1.dot(v2)
	var inv: float = 1.0 / (dot00 * dot11 - dot01 * dot01)
	var u: float = (dot11 * dot02 - dot01 * dot12) * inv
	var v: float = (dot00 * dot12 - dot01 * dot02) * inv
	return u >= -0.02 and v >= -0.02 and (u + v) <= 1.02


func _test_non_featured_stand_has_no_glow_disc() -> void:
	_reset()
	GS.install_find("brachiosaurus_skull", "Brachiosaurus Skull", 1.0, true)
	GS.unveil_stand("brachiosaurus")
	GS.install_find("t_rex_skull", "T. rex Skull", 1.0, true)
	GS.unveil_stand("t_rex")
	GS.set_featured_stand("t_rex")
	_set_spotlight_rank(3)
	GS.levels["lighting"] = 5
	GS.apply_upgrades()
	var exhibit: Node2D = Node2D.new()
	exhibit.set_script(load("res://museum_exhibit.gd"))
	root.add_child(exhibit)
	_assert(str(exhibit.call("plaque_title_for", "brachiosaurus")) == "Brachiosaurus", "non-featured plaque is Brachiosaurus with no multiplier")
	_assert(exhibit.has_method("hall_platform_glow_discs"), "exhibit exposes platform glow discs")
	if not exhibit.has_method("hall_platform_glow_discs"):
		exhibit.free()
		return
	var cones: Array = exhibit.call("hall_spotlight_cones")
	_assert(cones.size() == 1, "featured T. rex still gets exactly one spotlight cone")
	var rex_box: Rect2 = _poly_bbox(cones[0])
	_assert(rex_box.intersects(exhibit.stand_rect("t_rex")), "featured cone still hits T. rex")
	_assert_no_glow_disc_on_stand(exhibit, "brachiosaurus")
	GS.featured_stand_id = ""
	_assert(exhibit.call("hall_spotlight_cones").is_empty(), "empty featured list draws no cone")
	_assert_no_glow_disc_on_stand(exhibit, "brachiosaurus")
	_assert_no_glow_disc_on_stand(exhibit, "t_rex")
	exhibit.free()


func _assert_no_glow_disc_on_stand(exhibit: Node2D, stand_id: String) -> void:
	var interior: Rect2 = exhibit.stand_rect(stand_id).grow(-24.0)
	_assert(interior.size.x > 40.0 and interior.size.y > 40.0, "%s stand interior is large enough to test" % stand_id)
	var hits: int = 0
	for disc in _stand_glow_discs(exhibit):
		if interior.intersects(disc):
			hits += 1
	_assert(hits == 0, "non-featured %s has no spotlight/glow disc on the mount" % stand_id)


func _stand_glow_discs(exhibit: Node2D) -> Array:
	var discs: Array = []
	if exhibit.has_method("hall_spotlight_discs"):
		discs.append_array(exhibit.call("hall_spotlight_discs"))
	if exhibit.has_method("hall_platform_glow_discs"):
		discs.append_array(exhibit.call("hall_platform_glow_discs"))
	if exhibit.has_method("hall_lamp_discs"):
		discs.append_array(exhibit.call("hall_lamp_discs"))
	if exhibit.has_method("hall_lamp_pools"):
		discs.append_array(exhibit.call("hall_lamp_pools"))
	return discs


func _poly_bbox(pts: PackedVector2Array) -> Rect2:
	if pts.is_empty():
		return Rect2()
	var box := Rect2(pts[0], Vector2.ZERO)
	for pt in pts:
		box = box.expand(pt)
	return box


func _set_spotlight_rank(rank: int) -> void:
	if GS._item("spotlight").is_empty():
		return
	GS.levels["spotlight"] = rank
	GS.apply_upgrades()


func _test_unveil_pays_and_clears_pending() -> void:
	_reset()
	GS.install_find("triceratops_skull", "Triceratops Skull", 1.0, true)
	var paid: int = int(GS.unveil_stand("triceratops"))
	_assert(paid == 0, "unveil does not drop a cash burst")
	_assert(int(GS.money) == 0, "the bank stays on the visitor tick")
	_assert(not GS.stand_has_pending_unveil("triceratops"), "pending flag is cleared")
	_assert(int(GS.unveil_stand("triceratops")) == 0, "second unveil pays nothing")


func _test_unveil_starts_income_spike() -> void:
	_reset()
	GS.install_find("triceratops_skull", "Triceratops Skull", 1.0, true)
	var base: float = float(GS.museum_income())
	GS.unveil_stand("triceratops")
	_assert(float(GS.unveil_spike_left) >= 20.0, "unveil starts a 20s+ rush timer")
	var rush: float = float(GS.call("unveil_rush_rate")) if GS.has_method("unveil_rush_rate") else 0.0
	if not GS.has_method("unveil_rush_rate"):
		rush = 0.0
	_assert(rush > 0.0, "unveil adds a $/sec rush")
	_assert(is_equal_approx(float(GS.museum_income()), base + rush), "income applies the rush $/sec")
	GS._process(float(GS.unveil_spike_left) + 0.05)
	_assert(float(GS.unveil_spike_left) <= 0.0, "spike expires")
	_assert(is_equal_approx(float(GS.museum_income()), base), "rate returns to normal")


func _test_header_leads_with_rush_rate_not_cash() -> void:
	_reset()
	GS.install_find("triceratops_skull", "Triceratops Skull", 1.0, true)
	GS.unveil_stand("triceratops")
	GS.install_find("t_rex_tail", "T. rex Tail", 1.0, true)
	GS.unveil_stand("t_rex")
	var mus: Node = (load("res://museum.gd") as GDScript).new()
	root.add_child(mus)
	mus.visible = true
	mus._refresh()
	var line: String = _header_rush_text(mus)
	_assert(line.find("visitor") >= 0, "header leads with the extra visitors")
	_assert(line.find("×2") >= 0 or line.find("x2") >= 0, "header shows stacked rush")
	_assert(line.find("s") >= 0, "header shows the rush timer")
	_assert(line.find("+$40") < 0, "header does not lead with the cash burst")
	mus.free()


func _header_rush_text(mus: Node) -> String:
	return str(_header_stats(mus).get("rush", ""))


func _test_header_splits_rush_waiting_and_featured() -> void:
	_reset()
	GS.install_find("velociraptor_skull", "Velociraptor Skull", 1.0, true)
	GS.unveil_stand("velociraptor")
	GS.set_featured_stand("velociraptor")
	GS.install_find("t_rex_tail", "T. rex Tail", 1.0, true)
	var mus: Node = (load("res://museum.gd") as GDScript).new()
	root.add_child(mus)
	mus.visible = true
	mus._refresh()
	var card: Dictionary = _hall_board(mus)
	var stats: Dictionary = _header_stats(mus)
	var exhibit: Node2D = mus._canvas
	_assert(str(stats.get("visitors_label", "")) == "visitors", "the header names visitors")
	_assert(str(stats.get("rate_label", "")) == "/ sec", "the header names / sec")
	_assert(str(stats.get("rate", "")).find("Unveil") < 0, "the rate does not swallow the rush")
	_assert(str(stats.get("rate", "")).find("waiting") < 0, "the rate does not swallow the waiting hint")
	_assert(str(stats.get("rate", "")).find("featured") < 0, "the rate does not swallow the featured name")
	_assert(str(stats.get("rush", "")).find("Crowd surge") >= 0, "rush sits in the header cluster")
	_assert(str(stats.get("rush", "")).find("visitor") >= 0 and str(stats.get("rush", "")).find("s") >= 0, "rush keeps the extra crowd and timer")
	_assert(str(card.get("featured", "")).find("Velociraptor") >= 0, "featured name stays on the board")
	_assert(str(card.get("featured_label", "")) == "Featured", "Featured is a caption on the wall board")
	_assert(str(card.get("featured", "")).find("featured") < 0, "the stand name is not jammed into featured")
	_assert(str(exhibit.call("ribbon_prompt", "t_rex")).find("Tail") >= 0, "waiting bones stay on the stand ribbon")
	_assert(mus.get("_money") == null, "the hall does not host a second bank")
	mus.free()


func _test_header_counts_pending_unveils() -> void:
	_reset()
	GS.install_find("brachiosaurus_skull", "Brachiosaurus Skull", 1.0, true)
	GS.install_find("stegosaurus_foot", "Stegosaurus Foot", 1.0, true)
	GS.install_find("stegosaurus_plate", "Stegosaurus Plate", 1.0, true)
	GS.install_find("triceratops_tooth", "Triceratops Tooth", 1.0, true)
	GS.install_find("triceratops_vertebra", "Triceratops Vertebra", 1.0, true)
	GS.set_featured_stand("triceratops")
	_assert(str(GS.pending_unveil_waiting_line()) == "5 unveils waiting", "waiting line is a count, not a comma list")
	var mus: Node = (load("res://museum.gd") as GDScript).new()
	root.add_child(mus)
	mus.visible = true
	mus._refresh()
	var card: Dictionary = _hall_board(mus)
	_assert(str(card.get("featured", "")).find("Triceratops") >= 0, "the board names the featured stand")
	_assert(str(card.get("featured", "")).find("Brachiosaurus") < 0, "the board does not list Brachiosaurus Skull")
	_assert(str(card.get("featured", "")).find("Stegosaurus") < 0, "the board does not list Stegosaurus pieces")
	_assert(str(card.get("featured", "")).find("Tooth") < 0 and str(card.get("featured", "")).find("Vertebra") < 0, "the board does not list Triceratops bones")
	_assert(str(card.get("featured_label", "")) == "Featured", "Featured stays its own caption")
	_assert(str(GS.pending_unveil_waiting_line()) == "5 unveils waiting", "waiting count still exists for ribbons")
	var exhibit: Node2D = mus._canvas
	if exhibit.has_method("ribbon_prompt"):
		var ribbon: String = str(exhibit.call("ribbon_prompt", "brachiosaurus"))
		_assert(ribbon.find("Unveil") >= 0 and ribbon.find("Skull") >= 0, "stand ribbon still names Unveil Brachiosaurus Skull")
	mus.free()


func _test_header_copy_keeps_word_spaces() -> void:
	_reset()
	GS.install_find("triceratops_skull", "Triceratops Skull", 1.0, true)
	GS.unveil_stand("triceratops")
	GS.set_featured_stand("triceratops")
	GS.money = 388276
	var mus: Node = (load("res://museum.gd") as GDScript).new()
	root.add_child(mus)
	mus.visible = true
	mus._refresh()
	var card: Dictionary = _hall_board(mus)
	var stats: Dictionary = _header_stats(mus)
	_assert(mus.get("_money") == null, "the hall does not print a second bank $")
	_assert(str(stats.get("rate", "")).begins_with("$"), "rate is a $ amount")
	_assert(str(stats.get("rate_label", "")) == "/ sec", " / sec is a caption, not jammed onto the $")
	_assert(str(card.get("featured", "")) == "Triceratops", "featured name is only the stand")
	_assert(str(card.get("featured_label", "")) == "Featured", "Featured is not jammed into Triceratopsfeatured")
	_assert(str(stats.get("visitors", "")).is_valid_int(), "visitor count is not glued to the word visitors")
	_assert(str(stats.get("visitors_label", "")) == "visitors", "visitors is its own word")
	mus.free()


func _test_header_cluster_is_centered_in_the_bar() -> void:
	_reset()
	GS.install_find("triceratops_skull", "Triceratops Skull", 1.0, true)
	GS.unveil_stand("triceratops")
	GS.set_featured_stand("triceratops")
	GS.money = 388276
	var mus: Node = (load("res://museum.gd") as GDScript).new()
	root.add_child(mus)
	mus.visible = true
	var settings: Node = root.get_node_or_null("Settings")
	if settings != null:
		if settings.has_method("set_nav_visible"):
			settings.call("set_nav_visible", true)
		if settings.has_method("set_nav_context"):
			settings.call("set_nav_context", "museum")
		if settings.has_method("_layout_nav_chrome"):
			settings.call("_layout_nav_chrome")
	mus._refresh()
	var view: Vector2 = mus._view()
	var exhibit: Node2D = mus._canvas
	var board: Rect2 = exhibit.call("hall_board_rect")
	var cluster: Rect2 = _header_cluster_rect(mus)
	_assert(mus.get("_money") == null, "header cluster has no second bank $")
	_assert(mus.get("_back") == null, "the hall does not host its own Back")
	_assert(is_equal_approx(board.get_center().x, 1000.0), "the title board stays on the hall axis")
	_assert(board.end.y <= 220.0, "the title board stays on the north wall")
	_assert(cluster.size.x > 1.0, "header cluster is in the chrome bar")
	_assert(cluster.end.y <= float(mus.HEADER_H) + 0.5, "header cluster stays in HEADER_H")
	if settings != null:
		var nav: Control = settings.get("_nav_bar") as Control
		_assert(nav != null, "hall overlay nav lives in the shared header")
		if nav != null:
			var nav_r: Rect2 = Rect2(nav.global_position, nav.size)
			_assert(nav_r.position.x >= view.x * 0.45, "hall overlay nav sits on the right")
			_assert(nav_r.position.y <= 16.0, "hall overlay nav sits in the header")
			_assert(cluster.end.x <= nav_r.position.x - 4.0, "header cluster stays clear of Dig/Upgrades/Menu")
		if settings.has_method("overlay_content_right"):
			_assert(cluster.end.x <= float(settings.call("overlay_content_right")) + 0.5, "overlay_content_right reserves the wider nav cluster")
		_assert_header_stats_centered_in_gutter(mus, settings)
	_assert(str(_header_stats(mus).get("rate_label", "")) == "/ sec", "header rate caption keeps the space")
	_assert(str(_hall_board(mus).get("featured", "")) == "Triceratops", "board featured keeps its own word")
	mus.free()


func _assert_header_stats_centered_in_gutter(mus: Node, settings: Node) -> void:
	var left: float = 16.0
	var right: float = mus._view().x - 16.0
	if settings != null and settings.has_method("overlay_content_left"):
		left = float(settings.call("overlay_content_left"))
	if settings != null and settings.has_method("overlay_content_right"):
		right = float(settings.call("overlay_content_right"))
	var header_mid: float = mus._view().x * 0.5
	var text_cluster := Rect2()
	var started := false
	var pairs: Array = [
		["_visitors", "_visitors_cap", "visitors"],
		["_each", "_each_cap", "each"],
		["_rate", "_rate_cap", "rate"],
	]
	for pair in pairs:
		var value: Label = _header_label(mus, str(pair[0]))
		var caption: Label = _header_label(mus, str(pair[1]))
		var name: String = str(pair[2])
		_assert(value != null and caption != null, "%s pair exists in the header" % name)
		if value == null or caption == null:
			continue
		var value_text: Rect2 = _header_text_rect(value)
		var cap_text: Rect2 = _header_text_rect(caption)
		_assert(value_text.size.x > 1.0 and cap_text.size.x > 1.0, "%s number and word have text" % name)
		_assert(int(value.horizontal_alignment) == HORIZONTAL_ALIGNMENT_CENTER, "%s number is center-aligned" % name)
		_assert(int(caption.horizontal_alignment) == HORIZONTAL_ALIGNMENT_CENTER, "%s word is center-aligned" % name)
		_assert(value.size.x + 0.5 >= maxf(value_text.size.x, cap_text.size.x), "%s column is wide enough to center the shorter line" % name)
		_assert(caption.size.x + 0.5 >= maxf(value_text.size.x, cap_text.size.x), "%s word box matches the column so it can center" % name)
		_assert(absf(value.position.x - caption.position.x) <= 0.5, "%s number and word share a column left" % name)
		_assert(absf(value.size.x - caption.size.x) <= 0.5, "%s number and word share a column width" % name)
		_assert(absf(value_text.get_center().x - cap_text.get_center().x) <= 2.0, "%s number and word are centered as a unit" % name)
		var pair_text: Rect2 = value_text.merge(cap_text)
		if not started:
			text_cluster = pair_text
			started = true
		else:
			text_cluster = text_cluster.merge(pair_text)
	_assert(started, "visitor and money text sit in the header gutter")
	if started:
		_assert(text_cluster.position.x >= left - 0.5, "header stats stay right of the wallet")
		_assert(text_cluster.end.x <= right + 0.5, "header stats stay left of Dig/Upgrades/Menu")
		var ideal_left: float = header_mid - text_cluster.size.x * 0.5
		var placed_left: float = clampf(ideal_left, left, right - text_cluster.size.x)
		_assert(absf(text_cluster.get_center().x - (placed_left + text_cluster.size.x * 0.5)) <= 8.0, "visitor and money text are centered in the museum header")


func _header_text_rect(label: Label) -> Rect2:
	if label == null:
		return Rect2()
	var font: Font = label.get_theme_font("font")
	var sized: int = label.get_theme_font_size("font_size")
	var text: String = str(label.text)
	var width: float = 0.0
	var lines: int = 0
	for line in text.split("\n"):
		lines += 1
		if font != null:
			width = maxf(width, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, sized).x)
	var height: float = maxf(label.size.y, float(maxi(1, lines) * (sized + 4)))
	var x: float = label.position.x
	if int(label.horizontal_alignment) == HORIZONTAL_ALIGNMENT_RIGHT:
		x = label.position.x + label.size.x - width
	elif int(label.horizontal_alignment) == HORIZONTAL_ALIGNMENT_CENTER:
		x = label.position.x + (label.size.x - width) * 0.5
	return Rect2(x, label.position.y, width, height)


func _test_ribbon_shows_full_tail_above_plaque() -> void:
	_reset()
	GS.install_find("t_rex_tail", "T. rex Tail", 1.0, true)
	var exhibit: Node2D = Node2D.new()
	exhibit.set_script(load("res://museum_exhibit.gd"))
	root.add_child(exhibit)
	_assert(exhibit.has_method("ribbon_prompt"), "exhibit names the ribbon copy")
	_assert(exhibit.has_method("plaque_rect"), "exhibit exposes the plaque box")
	_assert(exhibit.has_method("ribbon_label_rect"), "exhibit exposes the ribbon label box")
	_assert(exhibit.has_method("ribbon_vertical_rect"), "exhibit exposes the vertical ribbon")
	if not exhibit.has_method("ribbon_prompt"):
		exhibit.free()
		return
	var prompt: String = str(exhibit.call("ribbon_prompt", "t_rex"))
	_assert(prompt.find("Tail") >= 0, "ribbon copy keeps the full Tail word")
	_assert(prompt.find("Unveil") >= 0, "ribbon copy is a CTA")
	_assert(prompt.find("waiting") < 0, "ribbon copy does not say waiting")
	_assert(prompt.find("T waiting") < 0, "ribbon copy is not T. rex T waiting")
	var plaque: Rect2 = exhibit.call("plaque_rect", "t_rex")
	var label_box: Rect2 = exhibit.call("ribbon_label_rect", "t_rex")
	var band: Rect2 = exhibit.call("ribbon_vertical_rect", "t_rex")
	_assert(plaque.size.x > 1.0 and label_box.size.x > 1.0, "plaque and ribbon label have size")
	_assert(not plaque.intersects(label_box), "ribbon copy does not cover the gold plaque")
	_assert(not plaque.intersects(band), "vertical ribbon does not cover the gold plaque")
	exhibit.free()


func _test_ribbon_names_one_pending_piece() -> void:
	_reset()
	GS.install_find("triceratops_tooth", "Triceratops Tooth", 1.0, true)
	var exhibit: Node2D = Node2D.new()
	exhibit.set_script(load("res://museum_exhibit.gd"))
	root.add_child(exhibit)
	var prompt: String = str(exhibit.call("ribbon_prompt", "triceratops"))
	_assert(prompt == "Unveil Triceratops Tooth", "one pending piece is Unveil Triceratops Tooth")
	_assert_ribbon_stays_on_stand(exhibit, "triceratops")
	exhibit.free()


func _test_ribbon_counts_several_pending_on_stand() -> void:
	_reset()
	GS.install_find("triceratops_tooth", "Triceratops Tooth", 1.0, true)
	GS.install_find("triceratops_vertebra", "Triceratops Vertebra", 1.0, true)
	GS.install_find("trilobite", "Trilobite", 1.0, true)
	GS.install_find("amber_insect", "Amber Insect", 1.0, true)
	GS.install_find("tooth", "Tooth", 1.0, true)
	GS.install_find("vertebra", "Vertebra", 1.0, true)
	var exhibit: Node2D = Node2D.new()
	exhibit.set_script(load("res://museum_exhibit.gd"))
	root.add_child(exhibit)
	var trike: String = str(exhibit.call("ribbon_prompt", "triceratops"))
	_assert(trike == "Unveil 2 finds", "several pending pieces are Unveil 2 finds")
	_assert(trike.find("Tooth") < 0 and trike.find("Vertebra") < 0, "stand ribbon is not a bone name list")
	_assert(trike.find(" and ") < 0, "stand ribbon does not join full names")
	var scraps: String = str(exhibit.call("ribbon_prompt", "small_finds"))
	_assert(scraps == "Unveil 4 finds", "several Small Finds are Unveil 4 finds")
	_assert(scraps.find("Trilobite") < 0 and scraps.find("Amber") < 0, "case ribbon is not a scrap name list")
	_assert_ribbon_stays_on_stand(exhibit, "triceratops")
	_assert_ribbon_stays_on_stand(exhibit, "small_finds")
	var aisle: Rect2 = Rect2(920.0, 500.0, 160.0, 900.0)
	var chip: Rect2 = exhibit.call("ribbon_label_rect", "triceratops")
	_assert(not aisle.intersects(chip), "trike ribbon stays out of the aisle")
	exhibit.free()


func _assert_ribbon_stays_on_stand(exhibit: Node2D, stand_id: String) -> void:
	var stand: Rect2 = exhibit.call("stand_rect", stand_id)
	var plaque: Rect2 = exhibit.call("plaque_rect", stand_id)
	var chip: Rect2 = exhibit.call("ribbon_label_rect", stand_id)
	_assert(chip.size.x > 1.0 and chip.size.y > 1.0, "%s ribbon chip has size" % stand_id)
	_assert(chip.position.x >= stand.position.x and chip.end.x <= stand.end.x + 0.01, "%s ribbon stays inside stand width" % stand_id)
	_assert(chip.position.y >= stand.position.y and chip.end.y <= stand.end.y + 0.01, "%s ribbon stays inside stand height" % stand_id)
	_assert(not plaque.intersects(chip), "%s ribbon does not cover the gold plaque" % stand_id)
	var font: Font = preload("res://ui_style.gd").display_font()
	var font_size: int = int(exhibit.call("ribbon_font_size", stand_id)) if exhibit.has_method("ribbon_font_size") else int(exhibit.call("label_font_size", 12))
	var lines: PackedStringArray = exhibit.call("ribbon_prompt_lines", stand_id)
	var max_w: float = 0.0
	for line in lines:
		max_w = maxf(max_w, font.get_string_size(str(line), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
	_assert(max_w <= chip.size.x - 8.0 + 0.01, "%s ribbon type fits the chip" % stand_id)


func _test_zoomed_out_labels_stay_readable() -> void:
	var mus: Node = (load("res://museum.gd") as GDScript).new()
	root.add_child(mus)
	mus.visible = true
	_wheel_hall(mus, MOUSE_BUTTON_WHEEL_DOWN, 24)
	var exhibit: Node2D = mus._canvas
	var zoom: float = exhibit.scale.x
	_assert(exhibit.has_method("label_font_size"), "exhibit can enlarge labels when zoomed out")
	if exhibit.has_method("label_font_size"):
		var font_size: int = int(exhibit.call("label_font_size", 14))
		_assert(float(font_size) * zoom >= 10.0, "stand labels stay at least 10px on screen when zoomed out")
	mus.free()


func _test_toast_names_the_new_piece() -> void:
	_reset()
	GS.install_find("t_rex_tooth", "T. rex Tooth", 1.0, true)
	GS.unveil_stand("t_rex")
	GS.install_find("t_rex_tail", "T. rex Tail", 1.0, true)
	var mus: Node = (load("res://museum.gd") as GDScript).new()
	root.add_child(mus)
	mus.visible = true
	mus._unveil_stand("t_rex")
	var banner: String = str(mus._banner.text)
	_assert(banner.to_lower().find("tail") >= 0, "toast names the tail, not the whole T. rex")
	_assert(banner.to_lower().find("unveil") >= 0, "toast says they are unveiling that fossil")
	_assert(banner.find("+$40") < 0, "toast does not lead with the cash burst")
	_assert(banner.find("visitor") >= 0, "toast shows the extra visitors")
	mus.free()


func _assert(ok: bool, label: String) -> void:
	if ok:
		_passed += 1
		print("PASS  %s" % label)
	else:
		_failed += 1
		print("FAIL  %s" % label)
