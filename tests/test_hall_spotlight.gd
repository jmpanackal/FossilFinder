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
	_test_click_still_features_without_ranks()
	_test_plaque_hides_mult_until_bought()
	_test_plaque_shows_owned_mult()
	_test_spotlight_beam_scales_with_rank()
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
	_assert(layout.size() == 6, "hall has six stands")
	_assert(layout.has("small_finds"), "Small Finds case exists")
	_assert(str(layout["small_finds"]["title"]) == "Small Finds", "case plaque says Small Finds")
	_assert(layout.has("t_rex") and layout.has("triceratops") and layout.has("velociraptor"), "far and left stands exist")
	_assert(layout.has("brachiosaurus") and layout.has("stegosaurus"), "right stands exist")
	_assert(str(layout["brachiosaurus"]["title"]) == "Brachiosaurus", "sauropod plaque says Brachiosaurus")
	var t_rex: Rect2 = exhibit.stand_rect("t_rex")
	var case_stand: Rect2 = exhibit.stand_rect("small_finds")
	var left_a: Rect2 = exhibit.stand_rect("triceratops")
	var left_b: Rect2 = exhibit.stand_rect("velociraptor")
	var right_a: Rect2 = exhibit.stand_rect("brachiosaurus")
	var right_b: Rect2 = exhibit.stand_rect("stegosaurus")
	_assert(t_rex.position.y < left_a.position.y and t_rex.position.y < right_a.position.y, "T. rex stands at the far end")
	_assert(left_a.position.x < 400.0 and left_b.position.x < 400.0, "Triceratops and Velociraptor stay left")
	_assert(right_a.position.x > 1400.0 and right_b.position.x > 1400.0, "Brachiosaurus and Stegosaurus stay right")
	_assert(case_stand.position.x < 400.0, "Small Finds sits on a side or end wall")
	_assert(case_stand.position.y < 480.0, "Small Finds is an end bay, not down the aisle")
	_assert(not case_stand.intersects(t_rex), "Small Finds does not cover T. rex")
	var aisle: Rect2 = Rect2(920.0, 500.0, 160.0, 900.0)
	_assert(not aisle.intersects(case_stand), "Small Finds leaves the aisle open")
	_assert(not aisle.intersects(left_a) and not aisle.intersects(left_b), "left stands leave the aisle open")
	_assert(not aisle.intersects(right_a) and not aisle.intersects(right_b), "right stands leave the aisle open")
	_assert(exhibit.stand_id_at(case_stand.get_center()) == "small_finds", "clicking the case hits Small Finds")
	exhibit.free()


func _test_museum_click_unveils_then_spotlights() -> void:
	_reset()
	GS.install_find("triceratops_skull", "Triceratops Skull", 1.0, true)
	var mus: Node = (load("res://museum.gd") as GDScript).new()
	root.add_child(mus)
	var pad_pos: Vector2 = _pad_pos_for_stand(mus, "triceratops")
	mus._click_hall(pad_pos)
	_assert(not GS.stand_has_pending_unveil("triceratops"), "click unveils the ribboned bay")
	_assert(int(GS.money) == int(TN.unveil_burst_clean), "click pays the cash burst")
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
	_assert(int(GS.money) == int(TN.unveil_burst_clean), "click pays the cash burst")
	mus._click_hall(pad_pos)
	_assert(str(GS.featured_stand_id) == "small_finds", "second click spotlights the case")
	mus.free()


func _header_rate(line: String) -> float:
	var start: int = line.find("$")
	if start < 0:
		return -1.0
	var rest: String = line.substr(start + 1)
	var end: int = rest.find(" ")
	if end < 0:
		return float(rest)
	return float(rest.substr(0, end))


func _header_amount(line: String) -> String:
	var start: int = line.find("$")
	if start < 0:
		return ""
	var rest: String = line.substr(start + 1)
	var end: int = rest.find(" ")
	if end < 0:
		return rest
	return rest.substr(0, end)


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
	var line: String = str(mus._income.text)
	_assert(line.find("$0.0 /") < 0, "header does not show $0.0 while the case earns")
	_assert(_header_rate(line) >= 0.10, "header prints the featured case rate")
	var cents: PackedStringArray = _header_amount(line).split(".")
	_assert(cents.size() == 2 and cents[1].length() == 2, "header shows hundredths so a live tick cannot hide")
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
	var line: String = str(mus._income.text)
	_assert(line.find("$0.0 /") < 0, "dusty featured header is not $0.0")
	_assert(_header_rate(line) >= 0.05, "dusty featured header still reads as a tick")
	mus.free()


func _test_header_names_a_mounted_tooth() -> void:
	_reset()
	GS.install_find("tooth", "Tooth", 0.0, false)
	GS.unveil_stand("small_finds")
	var mus: Node = (load("res://museum.gd") as GDScript).new()
	root.add_child(mus)
	mus.visible = true
	mus._refresh()
	_assert(str(mus._note.text).find("waiting") < 0, "a mounted tooth is not an empty hall")
	_assert(str(mus._note.text).find("dusty") >= 0, "header admits the tooth is dusty")
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
	_assert(str(mus._note.text).find("Triceratops") >= 0, "header names the featured stand")
	_assert(str(mus._income.text).find("$") >= 0, "header shows exhibit income")
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
	var burst: int = int(GS.unveil_stand("triceratops"))
	_assert(burst > 0, "first unveil pays")
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


func _set_spotlight_rank(rank: int) -> void:
	if GS._item("spotlight").is_empty():
		return
	GS.levels["spotlight"] = rank
	GS.apply_upgrades()


func _test_unveil_pays_and_clears_pending() -> void:
	_reset()
	GS.install_find("triceratops_skull", "Triceratops Skull", 1.0, true)
	var paid: int = int(GS.unveil_stand("triceratops"))
	_assert(paid == int(TN.unveil_burst_clean), "clean unveil pays the clean burst")
	_assert(int(GS.money) == paid, "burst comes from the same money bank")
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
	_assert(line.find("+$") >= 0 and line.find("/sec") >= 0, "header leads with the rush $/sec")
	_assert(line.find("×2") >= 0 or line.find("x2") >= 0, "header shows stacked rush")
	_assert(line.find("s") >= 0, "header shows the rush timer")
	_assert(line.find("+$40") < 0, "header does not lead with the cash burst")
	mus.free()


func _header_rush_text(mus: Node) -> String:
	if mus.get("_rush") != null:
		return str(mus._rush.text)
	return str(mus._income.text)


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
	var income: String = str(mus._income.text)
	var rush: String = _header_rush_text(mus)
	var note: String = str(mus._note.text)
	_assert(income.find("/ sec from the exhibit") >= 0, "income line still names the exhibit rate")
	_assert(income.find("Unveil") < 0, "income line does not swallow the rush")
	_assert(income.find("waiting") < 0, "income line does not swallow the waiting hint")
	_assert(income.find("featured") < 0, "income line does not swallow the featured name")
	_assert(rush.find("Unveil rush") >= 0, "rush sits on its own line")
	_assert(rush.find("+$") >= 0 and rush.find("s") >= 0, "rush line keeps the bonus and timer")
	_assert(note.find("1 unveil waiting") >= 0, "waiting hint is a short count")
	_assert(note.find("Tail") < 0, "header does not name the waiting bone")
	_assert(note.find("Unveil") < 0, "header is not a stand CTA")
	_assert(note.find("T waiting") < 0, "waiting hint is not clipped to T waiting")
	_assert(note.find("Velociraptor") >= 0 and note.find("featured") >= 0, "featured name stays in the header")
	_assert(note.find("\n") >= 0, "waiting and featured are stacked, not one smashed line")
	_assert(bool(mus._note.clip_text), "header note clips overflow")
	_assert(int(mus._note.text_overrun_behavior) == TextServer.OVERRUN_TRIM_ELLIPSIS, "header note ellipsizes overflow")
	_assert(int(mus._note.max_lines_visible) == 2, "header note stays two lines")
	_assert(income.find(note.strip_edges()) < 0, "note copy is not jammed onto the income line")
	var money_r: Rect2 = Rect2(mus._money.position, mus._money.size)
	var income_r: Rect2 = Rect2(mus._income.position, mus._income.size)
	var note_r: Rect2 = Rect2(mus._note.position, mus._note.size)
	_assert(money_r.size.x > 1.0 and income_r.size.x > 1.0 and note_r.size.x > 1.0, "header clusters have laid-out sizes")
	_assert(not money_r.intersects(income_r), "exhibit rate does not overlap $")
	_assert(not income_r.intersects(note_r), "exhibit rate does not overlap the right-side stack")
	_assert(income_r.position.y + income_r.size.y <= note_r.position.y + note_r.size.y + 1.0, "header rows stay inside the bar")
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
	var note: String = str(mus._note.text)
	_assert(note.find("5 unveils waiting") >= 0, "header counts pending unveils")
	_assert(note.find("Brachiosaurus") < 0, "header does not list Brachiosaurus Skull")
	_assert(note.find("Stegosaurus") < 0, "header does not list Stegosaurus pieces")
	_assert(note.find("Tooth") < 0 and note.find("Vertebra") < 0, "header does not list Triceratops bones")
	_assert(note.find("Triceratops featured") >= 0, "featured stays its own short line")
	_assert(note.find("Triceratopsfeatured") < 0, "featured keeps the space before featured")
	_assert(note.find("\n") >= 0, "waiting and featured stay stacked")
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
	var income: String = str(mus._income.text)
	var note: String = str(mus._note.text)
	var money: String = str(mus._money.text)
	_assert(money == "$388276", "wallet stays a dollar amount")
	_assert(income.find("$") >= 0 and income.find(" / sec from the exhibit") >= 0, "rate keeps spaces around / sec from the exhibit")
	_assert(income.find("/secfrom") < 0, "rate is not jammed into /secfromtheexhibit")
	_assert(note.find("Triceratops featured") >= 0, "featured line keeps the space")
	_assert(note.find("Triceratopsfeatured") < 0, "featured is not jammed into Triceratopsfeatured")
	var font: Font = mus._income.get_theme_font("font")
	var sized: int = mus._income.get_theme_font_size("font_size")
	if font != null:
		var with_space: float = font.get_string_size("a b", HORIZONTAL_ALIGNMENT_LEFT, -1, sized).x
		var jammed: float = font.get_string_size("ab", HORIZONTAL_ALIGNMENT_LEFT, -1, sized).x
		_assert(with_space > jammed + 1.0, "catalog font still advances on a word space")
		var rate_w: float = font.get_string_size(income, HORIZONTAL_ALIGNMENT_LEFT, -1, sized).x
		_assert(mus._income.size.x + 0.5 >= rate_w, "rate label is wide enough to keep its spaces")
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
	mus._refresh()
	var view: Vector2 = mus._view()
	var back_r: Rect2 = Rect2(mus._back.position, mus._back.size)
	var money_r: Rect2 = _header_text_rect(mus._money)
	var income_r: Rect2 = _header_text_rect(mus._income)
	var rush_r: Rect2 = _header_text_rect(mus._rush) if mus._rush != null and bool(mus._rush.visible) else Rect2()
	var note_r: Rect2 = _header_text_rect(mus._note)
	var mid_r: Rect2 = income_r.merge(rush_r) if rush_r.size.x > 0.0 else income_r
	var cluster: Rect2 = money_r.merge(mid_r).merge(note_r)
	var left: float = back_r.end.x
	var right: float = view.x
	var avail_center: float = (left + right) * 0.5
	var gap_rate: float = mid_r.position.x - money_r.end.x
	var gap_note: float = note_r.position.x - mid_r.end.x
	_assert(money_r.size.x > 1.0 and income_r.size.x > 1.0 and note_r.size.x > 1.0, "header text has measurable width")
	_assert(not cluster.intersects(back_r), "header cluster stays clear of Back")
	_assert(cluster.position.x >= left + 8.0, "cluster is not jammed against Back")
	_assert(gap_rate >= 8.0 and gap_rate <= 36.0, "wallet and rate sit in one cluster, not a left jam")
	_assert(gap_note >= 8.0 and gap_note <= 36.0, "rate and featured sit in one cluster, not a far-right dump")
	_assert(absf(cluster.get_center().x - avail_center) <= 24.0, "wallet + rate + featured sit in the remaining bar center")
	_assert(cluster.end.y <= mus.HEADER_H + 1.0, "centered cluster stays inside the 86px header")
	_assert(str(mus._income.text).find(" / sec from the exhibit") >= 0, "centered rate keeps readable spaces")
	_assert(str(mus._note.text).find("Triceratops featured") >= 0, "centered featured keeps its space")
	mus.free()


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
	_assert(banner.find("/sec") >= 0, "toast shows the rush $/sec")
	mus.free()


func _assert(ok: bool, label: String) -> void:
	if ok:
		_passed += 1
		print("PASS  %s" % label)
	else:
		_failed += 1
		print("FAIL  %s" % label)
