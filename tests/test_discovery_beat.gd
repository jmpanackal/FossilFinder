extends SceneTree

## Sittings 2–3: discovery peaks + chip hierarchy. No splash, no rarity.
## Run: godot --headless --path <project> -s res://tests/test_discovery_beat.gd

const Ui := preload("res://ui_style.gd")

var _failed: int = 0
var _passed: int = 0
var GS: Node
var TN: Node


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	GS = root.get_node("GameState")
	TN = root.get_node("Tuning")
	_test_first_bone_ping_is_a_peak()
	_test_pit_keeps_mystery_until_uncover()
	_test_uncover_celebrates_quota()
	_test_no_fossil_found_splash()
	_test_hall_fate_uses_finder_language()
	_test_chip_leads_with_name_not_price()
	_test_crowded_chip_keeps_name_and_price()
	_test_bagged_chip_stamps_hall_fate()
	_test_stars_stay_condition()
	_test_find_chip_stars_are_drawn()
	_test_find_chip_stars_are_small_and_centered()
	print("discovery_beat %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _reset() -> void:
	GS.pieces.clear()
	GS.money = 0
	GS.featured_stand_id = ""
	GS.pending_unveils.clear()
	GS.unveil_spike_left = 0.0
	GS._income_accum = 0.0
	for item in GS.catalog:
		GS.levels[item["id"]] = 0
	GS.apply_upgrades()


func _test_first_bone_ping_is_a_peak() -> void:
	var ping_script: GDScript = load("res://reveal_ping.gd") as GDScript
	_assert(ping_script != null, "first-cell ping still uses reveal_ping")
	if ping_script == null:
		return
	var ping: Node2D = ping_script.new()
	root.add_child(ping)
	_assert(float(ping.get("_max_age")) >= 0.52, "the first-bone ring hangs long enough to read")
	ping.queue_free()
	var site_src: String = FileAccess.get_file_as_string("res://dig_site.gd")
	_assert(site_src.find("fossil_ping") >= 0, "first bone cell still plays the existing ping")
	var main_src: String = FileAccess.get_file_as_string("res://main.gd")
	_assert(main_src.find("func _on_fossil_exposed") >= 0, "first cell still hits the expose hook")
	_assert(main_src.find("_on_fossil_extracted") >= 0 and main_src.find("catch_find") >= 0, "bag lights the chip on the existing hook")
	_assert(main_src.find("_spawn_fossil_fly") >= 0, "uncover still flies on the existing hook")


func _test_pit_keeps_mystery_until_uncover() -> void:
	var chip: Control = _make_chip()
	if chip == null:
		return
	chip.call("apply_card", _card("Brachiosaurus Tooth", "brachiosaurus_tooth", "uncovering", 5, "", 17, "", "", false))
	var name_label: Label = chip.get("_name_label") as Label
	_assert(name_label != null, "first-cell chip still has a name line")
	if name_label != null:
		_assert(name_label.text.find("Brachiosaurus") < 0, "species stays hidden until every cell is out")
		_assert(name_label.text.find("Tooth") < 0, "the piece name waits for full uncover")
		_assert(str(name_label.text) == "Bone", "the chip still has a generic bone label")
	chip.call("apply_card", _card("Brachiosaurus Tooth", "brachiosaurus_tooth", "brush", 5, "Brushed 40%", 17, "Well preserved", "New · 1/6", true))
	name_label = chip.get("_name_label") as Label
	if name_label != null:
		_assert(name_label.text.find("Brachiosaurus") >= 0 and name_label.text.find("Tooth") >= 0, "full uncover names the bone")
	chip.queue_free()
	var cards: Array = _live_cards_one_uncovered()
	if not cards.is_empty():
		_assert(str(cards[0].get("name", "")).find("Tooth") >= 0, "live pit cards name the species at full uncover")
		_assert(str(cards[0].get("piece_id", "")) != "", "piece id stays on the card for art")
		_assert(str(cards[0].get("progress", "")).find("New") >= 0 or str(cards[0].get("progress", "")).find("/") >= 0, "full uncover stamps quota on the card")


func _test_uncover_celebrates_quota() -> void:
	_reset()
	_assert(GS.has_method("uncover_status_line"), "GameState prints uncover quota copy")
	if not GS.has_method("uncover_status_line"):
		return
	_assert(str(GS.call("uncover_status_line", "t_rex_tooth")) == "New · 1/6", "first T. rex tooth says New · 1/6")
	_assert(str(GS.call("uncover_status_line", "t_rex_skull")) == "New · 1/1", "a missing unique bone says New · 1/1")
	GS.install_find("t_rex_tooth", "Tooth", 1.0, true)
	_assert(str(GS.call("uncover_status_line", "t_rex_tooth")) == "New · 2/6", "the next tooth still counts as New toward quota")
	for _i in 5:
		GS.install_find("t_rex_tooth", "Tooth", 1.0, true)
	_assert(str(GS.call("uncover_status_line", "t_rex_tooth")) == "Duplicate · 6/6", "over-quota copies say Duplicate · 6/6")
	var chip: Control = _make_chip()
	if chip == null:
		return
	chip.call("apply_card", _card("T. rex Tooth", "t_rex_tooth", "brush", 5, "Brushed 40%", 80, "Well preserved", "New · 1/6", true))
	var name_label: Label = chip.get("_name_label") as Label
	var status_label: Label = chip.get("_status_label") as Label
	_assert(name_label != null and str(name_label.text).find("T. rex Tooth") >= 0, "uncover chip leads with the bone name")
	_assert(status_label != null and (str(status_label.text).find("1/6") >= 0 or str(status_label.text).find("New") >= 0), "uncover chip shows N/M or New")
	chip.call("apply_card", _card("T. rex Tooth", "t_rex_tooth", "brush", 5, "Brushed 40%", 80, "Well preserved", "Duplicate", true))
	status_label = chip.get("_status_label") as Label
	_assert(status_label != null and str(status_label.text).find("Duplicate") >= 0, "uncover chip can say Duplicate")
	_assert(float(chip.get("_pop")) > 0.0 or float(chip.get("_lit")) > 0.0, "full uncover pops the chip gold")
	chip.queue_free()


func _test_no_fossil_found_splash() -> void:
	var main_src: String = FileAccess.get_file_as_string("res://main.gd")
	_assert(not main_src.is_empty(), "main.gd loads")
	_assert(main_src.find("FOSSIL FOUND") < 0, "no FOSSIL FOUND splash")
	_assert(main_src.find("%s found!") < 0, "extract does not splash a found line")
	_assert(main_src.find("Common") < 0 or main_src.find("rarity") < 0, "no idle rarity tiers on extract")
	var chip: Control = _make_chip()
	if chip == null:
		return
	chip.call("apply_card", _card("Tooth", "t_rex_tooth", "bagged", 5, "Brushed 100%", 80, "Well preserved", "needs this"))
	var name_label: Label = chip.get("_name_label") as Label
	var grade_label: Label = chip.get("_grade_label") as Label
	_assert(name_label != null and name_label.text.find("found") < 0, "the chip title is not a found toast")
	_assert(grade_label != null and grade_label.text.find("Rare") < 0, "condition is not a rarity word")
	chip.queue_free()


func _test_hall_fate_uses_finder_language() -> void:
	_reset()
	_assert(GS.has_method("hall_fate_line"), "GameState names hall fate in Finder language")
	if not GS.has_method("hall_fate_line"):
		return
	_assert(str(GS.call("hall_fate_line", "t_rex_skull")) == "New · 1/1", "a missing unique bone says New · 1/1")
	_assert(str(GS.call("hall_fate_line", "t_rex_tooth")) == "New · 1/6", "a first quota piece says New · 1/6")
	GS.install_find("t_rex_tooth", "Tooth", 1.0, true)
	GS.install_find("t_rex_tooth", "Tooth", 1.0, true)
	_assert(str(GS.call("hall_fate_line", "t_rex_tooth")) == "New · 3/6", "the next bag still counts as New toward the stand")
	for _i in 4:
		GS.install_find("t_rex_tooth", "Tooth", 1.0, true)
	_assert(str(GS.call("hall_fate_line", "t_rex_tooth")) == "Duplicate · 6/6", "over-quota copies say Duplicate · 6/6")
	_assert(str(GS.call("hall_fate_line", "t_rex_tooth")).find("needs this") < 0, "fate does not say needs this")
	_assert(str(GS.call("hall_fate_line", "t_rex_tooth")).find("Rare") < 0, "fate is not an idle rarity word")


func _test_chip_leads_with_name_not_price() -> void:
	var chip: Control = _make_chip()
	if chip == null:
		return
	chip.call("apply_card", _card("Stegosaurus Plate", "stegosaurus_plate", "bagged", 4, "Brushed 100%", 40, "Weathered", "1/3 on display"))
	if chip.has_method("fit_tray"):
		chip.call("fit_tray", 248.0, false)
	var name_label: Label = chip.get("_name_label") as Label
	var grade_label: Label = chip.get("_grade_label") as Label
	var price_label: Label = chip.get("_price_label") as Label
	_assert(name_label != null and name_label.text.find("Stegosaurus Plate") >= 0, "bagged chip leads with the bone name")
	_assert(grade_label != null and grade_label.text.find("Weathered") >= 0, "condition sits under the name")
	_assert(price_label != null and price_label.text.find("$40") >= 0, "$ is still on the chip")
	if name_label != null and price_label != null:
		_assert(name_label.get_theme_font_size("font_size") > price_label.get_theme_font_size("font_size"), "the bone name is louder than the price")
	if price_label != null and grade_label != null:
		_assert(price_label.get_theme_font_size("font_size") <= name_label.get_theme_font_size("font_size"), "price does not shout over the name")
	chip.queue_free()


func _test_crowded_chip_keeps_name_and_price() -> void:
	var chip: Control = _make_chip()
	if chip == null:
		return
	chip.call("apply_card", _card("Stegosaurus Plate", "stegosaurus_plate", "bagged", 4, "Brushed 100%", 40, "Weathered", "1/3 on display"))
	if chip.has_method("fit_tray"):
		chip.call("fit_tray", 164.0, true)
	_assert(chip.custom_minimum_size.x <= 164.0 + 0.5, "a packed chip honors the tray width")
	_assert(chip.custom_minimum_size.x + 0.5 >= 90.0, "a packed chip stays wider than a postage stamp")
	var name_label: Label = chip.get("_name_label") as Label
	var price_label: Label = chip.get("_price_label") as Label
	var icon: Control = chip.get("_icon") as Control
	_assert(name_label != null and name_label.text.find("Stegosaurus") >= 0, "packed chip still names the bone")
	_assert(price_label != null and price_label.text.find("$40") >= 0, "packed chip still shows $")
	_assert(icon != null, "packed chip keeps the bone doodle")
	chip.queue_free()


func _test_bagged_chip_stamps_hall_fate() -> void:
	var chip: Control = _make_chip()
	if chip == null:
		return
	chip.call("apply_card", _card("Tooth", "t_rex_tooth", "bagged", 5, "Brushed 100%", 80, "Well preserved", "New · 1/1"))
	var status_label: Label = chip.get("_status_label") as Label
	_assert(status_label != null and status_label.text.find("New") >= 0 and status_label.text.find("1/1") >= 0, "bag stamps New · 1/1 on the chip")
	chip.call("apply_card", _card("Tooth", "t_rex_tooth", "bagged", 5, "Brushed 100%", 80, "Well preserved", "New · 1/6"))
	status_label = chip.get("_status_label") as Label
	_assert(status_label != null and status_label.text.find("1/6") >= 0, "bag stamps quota on the chip")
	chip.call("apply_card", _card("Tooth", "t_rex_tooth", "bagged", 5, "Brushed 100%", 80, "Well preserved", "Duplicate · 6/6"))
	status_label = chip.get("_status_label") as Label
	_assert(status_label != null and status_label.text.find("Duplicate") >= 0, "bag stamps Duplicate on the chip")
	chip.queue_free()


func _test_stars_stay_condition() -> void:
	var chip: Control = _make_chip()
	if chip == null:
		return
	chip.call("apply_card", _card("Tooth", "t_rex_tooth", "bagged", 5, "Brushed 100%", 80, "Well preserved", "needs this"))
	var grade_label: Label = chip.get("_grade_label") as Label
	_assert(grade_label != null and grade_label.text.find("Well preserved") >= 0, "stars stay with preservation grade")
	_assert(grade_label != null and grade_label.text.find("Rare") < 0, "stars are not a rarity tier")
	chip.queue_free()


func _test_find_chip_stars_are_drawn() -> void:
	var font: Font = Ui.display_font()
	_assert(font != null, "catalog font loads")
	if font != null:
		_assert(not font.has_char("★".unicode_at(0)), "catalog font has no star glyph for the browser")
	var chip: Control = _make_chip()
	if chip == null:
		return
	chip.call("apply_card", _card("Tooth", "t_rex_tooth", "bagged", 5, "Brushed 100%", 80, "Well preserved", "needs this"))
	var grade_label: Label = chip.get("_grade_label") as Label
	_assert(grade_label != null and grade_label.text.find("★") < 0, "find chips do not put star glyphs in a label")
	_assert(chip.get("_stars") != null, "find chips keep a drawn star row")
	var stars: Variant = chip.get("_stars")
	if stars != null:
		_assert(bool(stars.visible), "drawn stars show on a graded find")
		_assert(int(stars.get("filled")) == 5, "drawn stars match the preservation count")
		_assert(stars.has_method("_draw_star"), "stars are polygons, not font tofu")
	chip.queue_free()


func _test_find_chip_stars_are_small_and_centered() -> void:
	var chip: Control = _make_chip()
	if chip == null:
		return
	chip.call("apply_card", _card("Amber Insect", "amber_insect", "bagged", 5, "Brushed 100%", 10, "Well preserved", "Duplicate · 1/1"))
	if chip.has_method("fit_tray"):
		chip.call("fit_tray", 360.0, false)
	chip.size = Vector2(360, 70)
	var grade_row: Node = chip.get("_grade_row")
	_assert(grade_row is HBoxContainer, "stars and the condition word sit on one line")
	var stars: Control = chip.get("_stars") as Control
	_assert(stars != null, "the compact star row exists")
	if stars != null:
		_assert(stars.custom_minimum_size.y <= 8.5, "find-chip stars stay caption-sized")
		_assert(stars.custom_minimum_size.x <= 48.0, "find-chip stars do not out-shout the grade")
		_assert(stars.size_flags_horizontal == Control.SIZE_SHRINK_CENTER, "stars sit on the text center")
	var name_label: Label = chip.get("_name_label") as Label
	var grade_label: Label = chip.get("_grade_label") as Label
	if name_label != null and grade_label != null:
		_assert(name_label.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER, "the bone name stays centered")
		_assert(grade_label.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER, "the grade stays centered")
		_assert(grade_label.size_flags_horizontal == Control.SIZE_SHRINK_CENTER, "grade hugs the stars on one centered line")
	chip.queue_free()


func _make_chip() -> Control:
	var script: GDScript = load("res://find_chip.gd") as GDScript
	_assert(script != null, "find_chip.gd loads")
	if script == null:
		return null
	var chip: Control = script.new() as Control
	root.add_child(chip)
	return chip


func _card(find_name: String, piece_id: String, status: String, stars: int, dirt: String, value: int, grade: String = "", fate: String = "", fully: bool = true) -> Dictionary:
	return {
		"index": 0,
		"name": find_name,
		"piece_id": piece_id,
		"status": status,
		"stars": stars,
		"grade": grade,
		"dirt": dirt,
		"value": value,
		"fate": fate,
		"progress": fate if fully and status != "bagged" else "",
		"exposed": 1,
		"needed": 1 if fully else 4,
		"centroid": Vector2(400, 300),
		"fully_exposed": fully,
		"extracted": status == "bagged",
	}


func _live_cards_one_uncovered() -> Array:
	var script: Script = load("res://dig_site.gd") as Script
	if script == null or not script.can_instantiate():
		return []
	var site: Node = script.new()
	var tooth: Resource = FossilData.new()
	tooth.set("name", "Tooth")
	tooth.set("piece_id", "t_rex_tooth")
	tooth.set("base_value", 80)
	var cell := Vector2i(1, 1)
	site.set("finds", [{
		"data": tooth,
		"piece_id": "t_rex_tooth",
		"extracted": false,
		"integrity": 1.0,
		"cells": {cell: true},
		"origin": cell,
		"layer": 0,
	}])
	site.set("exposed_cells", {cell: true})
	site.set("cleanliness", {cell: 0.4})
	var cards: Array = []
	if site.has_method("live_find_cards"):
		cards = site.call("live_find_cards")
	site.free()
	return cards


func _assert(ok: bool, label: String) -> void:
	if ok:
		_passed += 1
		print("PASS  %s" % label)
	else:
		_failed += 1
		print("FAIL  %s" % label)
