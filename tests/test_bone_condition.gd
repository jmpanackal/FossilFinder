extends SceneTree

## Bones have a hidden condition (Poor..Perfect) set by the ground, revealed
## when fully dug out. Tools never damage bone. Condition sets value and
## museum draw, and a better copy upgrades the exhibit.
## Run: godot --headless --path <project> -s res://tests/test_bone_condition.gd

const SAVE := "user://test_bone_condition.json"

var _failed: int = 0
var _passed: int = 0
var GS: Node
var TN: Node


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	GS = root.get_node("GameState")
	TN = root.get_node("Tuning")
	_test_rolls_follow_the_odds()
	_test_gentle_upgrades_improve_the_odds()
	_test_every_find_rolls_a_condition()
	_test_condition_stays_hidden_until_dug_out()
	_test_better_condition_is_worth_more()
	_test_tools_never_damage_bone()
	_test_condition_scales_museum_visitors()
	_test_better_copy_upgrades_the_exhibit()
	_test_save_keeps_condition()
	_test_plain_language_names()
	_reset()
	print("bone_condition %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _reset() -> void:
	GS.pieces.clear()
	GS.pending_unveils.clear()
	GS.featured_stand_id = ""
	GS.money = 0
	for item in GS.catalog:
		GS.levels[item["id"]] = 0
	GS.apply_upgrades()


func _make_site() -> Node2D:
	var script: GDScript = load("res://dig_site.gd") as GDScript
	var site: Node2D = script.new()
	root.add_child(site)
	return site


func _test_rolls_follow_the_odds() -> void:
	_reset()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var counts := [0, 0, 0, 0, 0]
	for i in 4000:
		var c: int = int(TN.roll_condition(rng))
		counts[c - 1] += 1
	_assert(counts.min() > 0, "every condition can turn up")
	_assert(counts[2] > counts[4] and counts[2] > counts[0], "Good is common, Poor and Perfect are rarer")
	var odds: PackedFloat32Array = TN.condition_odds()
	var total: float = 0.0
	for v in odds:
		total += v
	_assert(is_equal_approx(total, 1.0), "condition odds add to 100%")


func _test_gentle_upgrades_improve_the_odds() -> void:
	_reset()
	var before: float = float(TN.great_or_better_chance())
	GS.levels["shovel_soft"] = 5
	GS.levels["pick_soft"] = 5
	GS.apply_upgrades()
	_assert(float(TN.great_or_better_chance()) > before + 0.1, "Gentle Digging/Picking raise Great+ odds a lot")
	_assert(str(GS.shop_effect_line("shovel_soft")).contains("Great or Perfect"), "shop line explains the odds in plain words")


func _test_every_find_rolls_a_condition() -> void:
	_reset()
	for n in 10:
		var site := _make_site()
		for find in site.finds:
			var c: int = int(find.get("condition", 0))
			_assert(c >= 1 and c <= 5, "each find has a condition 1..5")
		site.queue_free()


func _test_condition_stays_hidden_until_dug_out() -> void:
	_reset()
	var site := _make_site()
	var find: Dictionary = site.finds[0]
	var cells: Array = (find["cells"] as Dictionary).keys()
	var revealed: Array = []
	site.condition_revealed.connect(func(i: int, c: int, _p: Vector2) -> void: revealed.append([i, c]))
	site.call("_reveal_fossil_cell", cells[0])
	var card: Dictionary = site.call("live_find_cards")[0]
	if cells.size() > 1:
		_assert(int(card["stars"]) == 0 and str(card["grade"]) == "", "condition is hidden while the bone is half dug")
		_assert(revealed.is_empty(), "no reveal until the whole bone is out")
	for cell in cells:
		site.call("_reveal_fossil_cell", cell)
	card = site.call("live_find_cards")[0]
	var cond: int = int(find["condition"])
	_assert(int(card["stars"]) == cond, "dug-out bone shows its condition as stars")
	_assert(str(card["grade"]) == str(TN.condition_label(cond)), "dug-out bone names its condition")
	_assert(revealed.size() == 1 and int(revealed[0][1]) == cond, "the reveal fires once with the condition")
	site.queue_free()


func _test_better_condition_is_worth_more() -> void:
	_reset()
	var site := _make_site()
	var find: Dictionary = site.finds[0]
	find["condition"] = 1
	var poor: int = int(site.call("_find_preview_value", find))
	find["condition"] = 5
	var perfect: int = int(site.call("_find_preview_value", find))
	_assert(perfect >= poor * 3, "a Perfect bone is worth far more than a Poor one")
	site.queue_free()


func _test_tools_never_damage_bone() -> void:
	_reset()
	GS.levels["shovel_click"] = 1
	GS.levels["pick_click"] = 1
	GS.apply_upgrades()
	var site := _make_site()
	var find: Dictionary = site.finds[0]
	var cond: int = int(find["condition"])
	var cell: Vector2i = (find["cells"] as Dictionary).keys()[0]
	site.call("_reveal_fossil_cell", cell)
	for tool in [TN.TOOL_SHOVEL, TN.TOOL_PICKAXE]:
		site.set("current_tool", tool)
		for i in 10:
			site.call("_apply_shovel" if tool == TN.TOOL_SHOVEL else "_apply_pickaxe", cell, 1.0, true)
	_assert(int(find["condition"]) == cond, "shovel and pick never lower a bone's condition")
	_assert(not bool(site.call("aiming_spoils_bone")), "no tool warns about spoiling bone")
	site.queue_free()


func _test_condition_scales_museum_visitors() -> void:
	_reset()
	GS.install_find("t_rex_skull", "T. rex Skull", 1.0, true, 1)
	var poor: int = int(GS.piece_visitors("t_rex_skull"))
	_reset()
	GS.install_find("t_rex_skull", "T. rex Skull", 1.0, true, 3)
	var good: int = int(GS.piece_visitors("t_rex_skull"))
	_reset()
	GS.install_find("t_rex_skull", "T. rex Skull", 1.0, true, 5)
	var perfect: int = int(GS.piece_visitors("t_rex_skull"))
	_assert(poor < good and good < perfect, "Poor < Good < Perfect visitors")
	_assert(absi(perfect - good * 2) <= 1, "a Perfect piece draws twice a Good one")


func _test_better_copy_upgrades_the_exhibit() -> void:
	_reset()
	GS.install_find("t_rex_skull", "T. rex Skull", 1.0, true, 2)
	_assert(int(GS.piece_condition("t_rex_skull")) == 2, "first copy mounts at its condition")
	_assert(str(GS.hall_fate_line("t_rex_skull", 4)).begins_with("Upgrade"), "a better copy is labeled an upgrade")
	var money_before: int = int(GS.money)
	var note: String = str(GS.install_find("t_rex_skull", "T. rex Skull", 1.0, true, 4))
	_assert(int(GS.piece_condition("t_rex_skull")) == 4, "the better copy replaces the one on display")
	_assert(note.contains("upgraded"), "the note says the exhibit was upgraded")
	_assert(int(GS.money) > money_before, "the old copy is sold")
	GS.install_find("t_rex_skull", "T. rex Skull", 1.0, true, 1)
	_assert(int(GS.piece_condition("t_rex_skull")) == 4, "a worse copy never replaces a better one")
	_assert(not str(GS.hall_fate_line("t_rex_skull", 1)).begins_with("Upgrade"), "a worse copy is just a duplicate")


func _test_save_keeps_condition() -> void:
	_reset()
	GS.install_find("t_rex_skull", "T. rex Skull", 1.0, true, 5)
	_assert(bool(GS.save_game(SAVE)), "save writes")
	_reset()
	_assert(bool(GS.load_game(SAVE)), "save loads")
	_assert(int(GS.piece_condition("t_rex_skull")) == 5, "condition survives a save")
	var file := FileAccess.open(SAVE, FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": 1, "money": 0, "levels": {}, "pieces": {"t_rex_skull": {"name": "T. rex Skull", "cleanliness": 1.0, "clean": true, "count": 1}}}))
	file.close()
	_reset()
	GS.load_game(SAVE)
	_assert(int(GS.piece_condition("t_rex_skull")) == 3, "old saves without condition load as Good")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))


func _test_plain_language_names() -> void:
	var names: PackedStringArray = TN.CONDITION_NAMES
	_assert(names.size() == 5, "five conditions")
	_assert(" ".join(names) == "Poor Fair Good Great Perfect", "condition names are everyday words")
	_assert(str(TN.CONDITION_HINT).length() > 20, "there is a plain explanation of condition")


func _assert(ok: bool, label: String) -> void:
	if ok:
		_passed += 1
		print("PASS  %s" % label)
	else:
		_failed += 1
		print("FAIL  %s" % label)
