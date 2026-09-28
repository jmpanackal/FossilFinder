extends SceneTree

## Field catalog chrome: display font, brass StyleBoxes, museum plaques.
## Run: godot --headless --path <project> -s res://tests/test_catalog_chrome.gd

const Ui := preload("res://ui_style.gd")
const FONT_PATH := "res://fonts/libre_baskerville/LibreBaskerville-Regular.ttf"
const LICENSE_PATH := "res://fonts/libre_baskerville/OFL.txt"

var _failed: int = 0
var _passed: int = 0
var GS: Node


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	GS = root.get_node("GameState")
	_test_display_font_is_vendored_ofl_serif()
	_test_labels_buttons_and_drawn_copy_use_display_font()
	_test_shared_boxes_are_brass_inset_or_outset()
	_test_shop_museum_summary_settings_pick_up_shared_boxes()
	_test_museum_plaques_are_objects()
	_test_unveil_overflow_copy_stays()
	_test_museum_header_and_board_split()
	print("catalog_chrome %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _test_display_font_is_vendored_ofl_serif() -> void:
	_assert(FileAccess.file_exists(FONT_PATH), "Libre Baskerville Regular is vendored")
	_assert(FileAccess.file_exists(LICENSE_PATH), "SIL OFL license is vendored next to the font")
	if FileAccess.file_exists(LICENSE_PATH):
		var license: String = FileAccess.get_file_as_string(LICENSE_PATH)
		_assert(license.find("SIL OPEN FONT LICENSE") >= 0, "license file is the SIL OFL")
		_assert(license.find("Libre Baskerville") >= 0 or license.find("Impallari") >= 0, "license names Libre Baskerville")
	var ui_src: String = FileAccess.get_file_as_string("res://ui_style.gd")
	_assert(ui_src.find("static func display_font") >= 0, "Ui exposes the catalog font")
	if FileAccess.file_exists(FONT_PATH):
		var font := FontFile.new()
		_assert(font.load_dynamic_font(FONT_PATH) == OK, "display font is a Godot FontFile")
		_assert(font.get_height(16) > 10.0, "display font can measure body copy")


func _test_labels_buttons_and_drawn_copy_use_display_font() -> void:
	var label := Label.new()
	root.add_child(label)
	Ui.apply_label(label, Ui.BODY_SIZE)
	_assert(label.has_theme_font_override("font"), "apply_label wires the catalog font")
	label.queue_free()

	var ui_src: String = FileAccess.get_file_as_string("res://ui_style.gd")
	_assert(ui_src.find("static func apply_copy") >= 0, "Ui can fit catalog copy so spaces survive")
	var copy := Label.new()
	root.add_child(copy)
	if ui_src.find("static func apply_copy") >= 0:
		Ui.apply_copy(copy, "Next upgrade", Ui.CAPTION_SIZE, Ui.MUTED, 96.0)
		_assert(str(copy.text) == "Next upgrade", "apply_copy keeps the given words")
		_assert(copy.autowrap_mode == TextServer.AUTOWRAP_OFF, "apply_copy does not autowrap spaces away")
		_assert(not copy.clip_text, "apply_copy does not clip word spaces")
		var font: Font = copy.get_theme_font("font")
		var sized: int = copy.get_theme_font_size("font_size")
		var need: float = font.get_string_size("Next upgrade", HORIZONTAL_ALIGNMENT_LEFT, -1, sized).x
		_assert(copy.custom_minimum_size.x + 0.5 >= need, "apply_copy is wide enough to keep Next upgrade's space")
	copy.queue_free()

	var title := Label.new()
	root.add_child(title)
	Ui.apply_title(title)
	_assert(title.has_theme_font_override("font"), "titles use the catalog font")
	title.queue_free()

	var button := Button.new()
	root.add_child(button)
	Ui.apply_button(button)
	_assert(button.has_theme_font_override("font"), "buttons use the catalog font")
	button.queue_free()

	var toast_src: String = FileAccess.get_file_as_string("res://toast_layer.gd")
	_assert(toast_src.find("Ui.apply_label") >= 0 or toast_src.find("Ui.apply_caption") >= 0, "toasts go through Ui helpers")
	var float_src: String = FileAccess.get_file_as_string("res://floating_text.gd")
	_assert(float_src.find("Ui.apply_label") >= 0 or float_src.find("display_font") >= 0, "floaters use the catalog font")
	var exhibit_src: String = FileAccess.get_file_as_string("res://museum_exhibit.gd")
	_assert(exhibit_src.find("ThemeDB.fallback_font") < 0, "plaques and ribbons do not use the fallback font")
	_assert(exhibit_src.find("display_font") >= 0, "plaques and ribbons measure with the catalog font")


func _test_shared_boxes_are_brass_inset_or_outset() -> void:
	var panel: StyleBox = Ui.panel_box()
	_assert(_is_brass(panel), "panel_box is a brass StyleBox")
	_assert(_outset(panel), "cards are outset brass")
	_assert(_corner(panel) <= 6, "card corners are tighter than the old 10px round")
	_assert(_shadow_drop(panel), "cards cast a real plaque shadow")
	_assert(_has_dual_border(panel), "cards have a dual border and inner highlight")

	var chip: StyleBox = Ui.chip_box(0.4)
	_assert(_is_brass(chip), "HUD chips use the shared brass helper")
	_assert(_outset(chip), "find chips read as raised plates")
	_assert(_corner(chip) <= 6, "chip corners stay tight")

	var row: StyleBox = Ui.row_box("glow")
	_assert(_is_brass(row), "shop rows use the shared brass helper")
	_assert(_outset(row), "shop rows are outset cards")

	var well: StyleBox = Ui.icon_well_box(Color("1B1410"))
	_assert(_is_brass(well), "icon wells use the shared brass helper")
	_assert(_inset(well), "icon wells are inset")

	var gate: StyleBox = Ui.gate_box()
	_assert(_is_brass(gate), "shop gates use the shared brass helper")
	_assert(_inset(gate), "locked gates sit inset")

	var button := Button.new()
	root.add_child(button)
	Ui.apply_button(button, true)
	var normal: StyleBox = button.get_theme_stylebox("normal")
	var pressed: StyleBox = button.get_theme_stylebox("pressed")
	_assert(_is_brass(normal) and _outset(normal), "buttons are outset brass")
	_assert(_is_brass(pressed) and _inset(pressed), "pressed buttons flip to inset")
	button.queue_free()

	var wallet: StyleBox = Ui.wallet_box()
	_assert(_is_brass(wallet) and _outset(wallet), "wallet chip is outset brass")
	_assert(_shadow_drop(wallet), "wallet chip keeps a card shadow")
	_assert(wallet.bg_color.get_luminance() >= 0.45, "wallet plate reads on dark shop and hall headers")
	var money := Label.new()
	root.add_child(money)
	Ui.apply_wallet(money)
	_assert(money.get_theme_color("font_color").get_luminance() <= 0.35, "wallet $ is ink on the bright plate")
	money.queue_free()


func _test_shop_museum_summary_settings_pick_up_shared_boxes() -> void:
	var shop_src: String = FileAccess.get_file_as_string("res://shop.gd")
	_assert(shop_src.find("StyleBoxFlat.new()") < 0, "shop does not restyle with one-off StyleBoxes")
	_assert(shop_src.find("Ui.apply_panel") >= 0 and shop_src.find("Ui.apply_tab") >= 0, "shop uses shared Ui helpers")
	var settings_src: String = FileAccess.get_file_as_string("res://settings.gd")
	_assert(settings_src.find("Ui.apply_modal") >= 0, "settings uses the shared modal box")
	var summary_src: String = FileAccess.get_file_as_string("res://summary.gd")
	_assert(summary_src.find("Ui.apply_modal") >= 0, "summary uses the shared modal box")
	var hud_src: String = FileAccess.get_file_as_string("res://hud.gd")
	_assert(hud_src.find("Ui.wallet_box") >= 0 and (hud_src.find("Ui.apply_hud_button") >= 0 or hud_src.find("Ui.apply_button") >= 0), "HUD chips use shared helpers")
	var chip_src: String = FileAccess.get_file_as_string("res://find_chip.gd")
	_assert(chip_src.find("Ui.chip_box") >= 0, "find chips use the shared chip box")
	var tooltip_src: String = FileAccess.get_file_as_string("res://shop_tooltip.gd")
	_assert(tooltip_src.find("StyleBoxFlat.new()") < 0, "tooltips do not build a one-off StyleBoxFlat")


func _test_museum_plaques_are_objects() -> void:
	var src: String = FileAccess.get_file_as_string("res://museum_exhibit.gd")
	_assert(src.find("func _draw_plaque") >= 0, "stands still paint a plaque")
	_assert(src.find("_draw_plaque_bevel") >= 0 or src.find("bevel") >= 0, "plaque has a bevel")
	_assert(src.find("screw") >= 0 or src.find("rivet") >= 0, "plaque has screws or rivets")
	_assert(src.find("lip") >= 0, "plaque sits on a stand lip")
	_assert(src.find("draw_rect(rect, Color(\"F0D070\") if featured else Ui.GOLD, false") < 0, "plaque is not only a gold-stroke rectangle")
	var exhibit: Node2D = Node2D.new()
	exhibit.set_script(load("res://museum_exhibit.gd"))
	root.add_child(exhibit)
	_assert(exhibit.has_method("plaque_rect"), "exhibit still exposes the plaque box")
	if exhibit.has_method("plaque_rect"):
		var plate: Rect2 = exhibit.call("plaque_rect", "t_rex")
		_assert(plate.size.x > 1.0 and plate.size.y > 1.0, "empty T. rex plaque still has a plate")
	exhibit.free()


func _test_unveil_overflow_copy_stays() -> void:
	_reset()
	GS.install_find("brachiosaurus_skull", "Brachiosaurus Skull", 1.0, true)
	GS.install_find("stegosaurus_foot", "Stegosaurus Foot", 1.0, true)
	GS.install_find("stegosaurus_plate", "Stegosaurus Plate", 1.0, true)
	GS.install_find("triceratops_tooth", "Triceratops Tooth", 1.0, true)
	GS.install_find("triceratops_vertebra", "Triceratops Vertebra", 1.0, true)
	GS.set_featured_stand("triceratops")
	_assert(str(GS.pending_unveil_waiting_line()) == "5 unveils waiting", "header waiting line stays a count")
	var mus: Node = (load("res://museum.gd") as GDScript).new()
	root.add_child(mus)
	mus.visible = true
	mus._refresh()
	var exhibit: Node2D = mus._canvas
	var card: Dictionary = {}
	if exhibit.has_method("hall_board"):
		card = exhibit.call("hall_board")
	_assert(str(GS.pending_unveil_waiting_line()) == "5 unveils waiting", "waiting count still exists for ribbons")
	_assert(str(card.get("featured", "")).find("Triceratops") >= 0, "the title board still names the featured stand")
	_assert(str(card.get("visitors", "")).is_empty(), "waiting copy does not put visitors on the wall board")
	_assert(str(exhibit.call("ribbon_prompt", "brachiosaurus")) == "Unveil Brachiosaurus Skull", "one pending stand is Unveil <Part>")
	_assert(str(exhibit.call("ribbon_prompt", "stegosaurus")) == "Unveil 2 finds", "several pending on a stand is Unveil N finds")
	mus.free()


func _test_museum_header_and_board_split() -> void:
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
		if settings.has_method("_layout_nav_chrome"):
			settings.call("_layout_nav_chrome")
	mus._refresh()
	_assert(mus.has_method("header_stats"), "museum exposes separate header stats")
	var stats: Dictionary = mus.call("header_stats") if mus.has_method("header_stats") else {}
	_assert(str(stats.get("visitors", "")).is_valid_int(), "header visitor count is a bare number")
	_assert(str(stats.get("visitors_label", "")) == "visitors", "header visitors caption is its own word")
	_assert(str(stats.get("each_value", "")).begins_with("$"), "header donation is its own $ amount")
	_assert(str(stats.get("each_label", "")) == "each", "header each caption is its own word")
	_assert(str(stats.get("rate", "")).begins_with("$"), "header rate is its own $ amount")
	_assert(str(stats.get("rate_label", "")) == "/ sec", "header / sec caption keeps its space")
	var visitors: Label = mus.get("_visitors") as Label
	var visitors_cap: Label = mus.get("_visitors_cap") as Label
	var rate: Label = mus.get("_rate") as Label
	var rate_cap: Label = mus.get("_rate_cap") as Label
	_assert(visitors != null and visitors_cap != null, "header uses separate visitor labels")
	_assert(rate != null and rate_cap != null, "header uses separate rate labels")
	if visitors != null:
		_assert(str(visitors.text).find("visitors") < 0, "header does not jam 166visitors")
	var exhibit: Node2D = mus._canvas
	var card: Dictionary = {}
	if exhibit.has_method("hall_board"):
		card = exhibit.call("hall_board")
	_assert(str(card.get("title", "")) == "FOSSIL HALL", "the wall board keeps FOSSIL HALL")
	_assert(str(card.get("featured_label", "")) == "Featured", "the wall board keeps Featured")
	_assert(str(card.get("featured", "")) == "Triceratops", "the wall board names the stand")
	_assert(str(card.get("visitors", "")).is_empty(), "the wall board no longer owns visitors")
	_assert(str(card.get("rate", "")).is_empty(), "the wall board no longer owns hall rate")
	if exhibit.has_method("hall_board_featured_rect"):
		var board: Rect2 = exhibit.call("hall_board_rect")
		var feat: Rect2 = exhibit.call("hall_board_featured_rect")
		_assert(feat.size.y >= board.size.y * 0.5, "featured grows to fill the wall box")
	if mus.has_method("header_cluster_rect"):
		var cluster: Rect2 = mus.call("header_cluster_rect")
		_assert(cluster.end.y <= float(mus.HEADER_H) + 0.5, "header cluster stays in HEADER_H")
		if settings != null:
			if settings.has_method("set_nav_context"):
				settings.call("set_nav_context", "museum")
			if settings.has_method("_layout_nav_chrome"):
				settings.call("_layout_nav_chrome")
			mus._refresh()
			cluster = mus.call("header_cluster_rect")
			if settings.has_method("overlay_content_right"):
				_assert(cluster.end.x <= float(settings.call("overlay_content_right")) + 0.5, "header cluster stays clear of Dig/Upgrades/Menu")
			var nav: Control = settings.get("_nav_bar") as Control
			if nav != null:
				_assert(cluster.end.x <= nav.global_position.x - 4.0, "header cluster stays clear of the overlay nav")
	mus.free()


func _is_brass(box: StyleBox) -> bool:
	return box != null and box.has_method("is_brass") and bool(box.call("is_brass"))


func _outset(box: StyleBox) -> bool:
	return box != null and box.has_method("is_outset") and bool(box.call("is_outset"))


func _inset(box: StyleBox) -> bool:
	return box != null and box.has_method("is_inset") and bool(box.call("is_inset"))


func _corner(box: StyleBox) -> int:
	if box != null and "corner_radius" in box:
		return int(box.corner_radius)
	return 99


func _shadow_drop(box: StyleBox) -> bool:
	if box == null:
		return false
	var size: int = int(box.shadow_size) if "shadow_size" in box else 0
	var offset: Vector2 = box.shadow_offset if "shadow_offset" in box else Vector2.ZERO
	return size >= 6 and offset.y >= 2.0


func _has_dual_border(box: StyleBox) -> bool:
	return box != null and box.has_method("has_dual_border") and bool(box.call("has_dual_border"))


func _reset() -> void:
	GS.pieces.clear()
	GS.money = 0
	GS.featured_stand_id = ""
	GS.pending_unveils.clear()
	GS.pending_notices.clear()
	GS.unveil_spike_left = 0.0
	GS._income_accum = 0.0
	for item in GS.catalog:
		GS.levels[item["id"]] = 0
	GS.apply_upgrades()


func _assert(ok: bool, label: String) -> void:
	if ok:
		_passed += 1
		print("PASS  %s" % label)
	else:
		_failed += 1
		print("FAIL  %s" % label)
