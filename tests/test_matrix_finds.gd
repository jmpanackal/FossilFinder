extends SceneTree

## Matrix finds: junk in the layer is the money, not a dirt sale.
## Run: godot --headless --path <project> -s res://tests/test_matrix_finds.gd

var _failed: int = 0
var _passed: int = 0
var GS: Node
var TN: Node
var Matrix: GDScript
var Lucky: GDScript


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	GS = root.get_node("GameState")
	TN = root.get_node("Tuning")
	Matrix = load("res://matrix_find.gd") as GDScript
	Lucky = load("res://lucky_strike.gd") as GDScript
	_test_script_exists()
	_test_dirt_pop_is_named_junk()
	_test_dirt_has_variety_and_rarities()
	_test_stone_is_chunkier_and_rarer()
	_test_early_dirt_ev_stays_near_old_pay()
	_test_soil_bounty_buffs_matrix_not_dirt_price()
	_test_stone_bounty_buffs_nodules()
	_test_wide_scoop_batches_a_few_floats()
	_test_lucky_is_a_matrix_glint()
	_test_summary_says_finds_not_dirt()
	_test_shop_copy_is_matrix_language()
	_test_float_is_currency_only()
	_test_sprite_is_the_item()
	_test_toothlet_is_not_a_museum_tooth()
	_test_wide_scoop_caps_sprites_without_merging()
	_test_cells_can_show_a_terrain_tell()
	_test_lucky_float_is_currency()
	print("matrix_finds %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _reset() -> void:
	GS.pieces.clear()
	GS.money = 0
	for item in GS.catalog:
		GS.levels[item["id"]] = 0
	GS.apply_upgrades()


func _test_script_exists() -> void:
	_assert(Matrix != null, "matrix_find.gd exists")


func _test_dirt_pop_is_named_junk() -> void:
	if Matrix == null:
		return
	_reset()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var hit: Dictionary = {}
	for _i in 40:
		var find: Dictionary = Matrix.roll(rng, 0)
		if find.is_empty():
			continue
		hit = find
		break
	_assert(not hit.is_empty(), "a loose-dirt pop can yield a matrix find")
	if hit.is_empty():
		return
	_assert(int(hit.get("amount", 0)) > 0, "the find is the money")
	var name: String = str(hit.get("name", "")).to_lower()
	_assert(not name.is_empty(), "the find has a junk name")
	_assert(name.find("dirt") < 0, "the find is not sold as dirt")
	_assert(name.find("soil") < 0, "the find is not sold as soil")
	_assert(Matrix.has_method("float_text"), "finds have a +$ float label")
	if Matrix.has_method("float_text"):
		var label: String = str(Matrix.float_text(hit))
		_assert(label == "+$%d" % int(hit.get("amount", 0)), "the float is gold +$, never a junk name")
		_assert(label.to_lower().find("dirt") < 0, "the float does not say dirt")
		_assert(label.to_lower().find(name) < 0, "the bank number is not +%s" % name)


func _test_dirt_has_variety_and_rarities() -> void:
	if Matrix == null:
		return
	_reset()
	var rng := RandomNumberGenerator.new()
	rng.seed = 19
	var names: Dictionary = {}
	var rarities: Dictionary = {}
	for _i in 120:
		var find: Dictionary = Matrix.roll(rng, 0)
		if find.is_empty():
			continue
		names[str(find.get("name", ""))] = true
		rarities[int(find.get("rarity", -1))] = true
	_assert(names.size() >= 4, "dirt junk is not one beige shell forever")
	_assert(rarities.has(0), "common trash can pop")
	_assert(rarities.has(1), "uncommon glints can pop")
	_assert(rarities.has(2), "rare scrap can pop")


func _test_stone_is_chunkier_and_rarer() -> void:
	if Matrix == null:
		return
	_reset()
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var dirt_hits: int = 0
	var stone_hits: int = 0
	var dirt_pay: int = 0
	var stone_pay: int = 0
	var stone_names: Dictionary = {}
	for _i in 160:
		var dirt: Dictionary = Matrix.roll(rng, 0)
		if not dirt.is_empty():
			dirt_hits += 1
			dirt_pay += int(dirt.get("amount", 0))
		var stone: Dictionary = Matrix.roll(rng, 20)
		if stone.is_empty():
			continue
		stone_hits += 1
		stone_pay += int(stone.get("amount", 0))
		stone_names[str(stone.get("name", "")).to_lower()] = true
	_assert(dirt_hits > stone_hits, "stone hides finds less often than dirt")
	_assert(float(stone_hits) / 160.0 < 0.62, "stone nodules stay infrequent")
	_assert(float(dirt_hits) / 160.0 > 0.75, "dirt still pops often enough for clicker dopamine")
	if stone_hits > 0 and dirt_hits > 0:
		_assert(float(stone_pay) / float(stone_hits) > float(dirt_pay) / float(dirt_hits), "a stone find is chunkier than a dirt find")
	var blob: String = " ".join(PackedStringArray(stone_names.keys()))
	_assert(blob.find("nodule") >= 0 or blob.find("crystal") >= 0, "stone junk is a nodule or crystal")
	_assert(blob.find("dirt") < 0, "stone does not sell rock dollars")


func _test_early_dirt_ev_stays_near_old_pay() -> void:
	if Matrix == null:
		return
	_reset()
	var baseline: int = int(TN.money_for_layer(0))
	_assert(baseline >= 1, "old loose-dirt pay is the EV target")
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var total: int = 0
	var n: int = 240
	for _i in n:
		var find: Dictionary = Matrix.roll(rng, 0)
		total += int(find.get("amount", 0))
	var avg: float = float(total) / float(n)
	_assert(avg >= float(baseline) * 0.70, "early dirt finds do not crash the shop ladder")
	_assert(avg <= float(baseline) * 1.45, "early dirt finds stay in the old pay ballpark")


func _test_soil_bounty_buffs_matrix_not_dirt_price() -> void:
	if Matrix == null:
		return
	_reset()
	var rng := RandomNumberGenerator.new()
	var n: int = 180
	rng.seed = 5
	var base_total: int = 0
	var base_hits: int = 0
	for _i in n:
		var find: Dictionary = Matrix.roll(rng, 0)
		base_total += int(find.get("amount", 0))
		if not find.is_empty():
			base_hits += 1
	GS.levels["dirt_pay"] = 5
	GS.apply_upgrades()
	_assert(str(GS.catalog_item_desc("dirt_pay") if GS.has_method("catalog_item_desc") else GS.shop_item_desc("dirt_pay")).to_lower().find("dirt layers pay") < 0, "Soil Bounty is not dirt-price copy")
	rng.seed = 5
	var buff_total: int = 0
	var buff_hits: int = 0
	for _i in n:
		var find: Dictionary = Matrix.roll(rng, 0)
		buff_total += int(find.get("amount", 0))
		if not find.is_empty():
			buff_hits += 1
	_assert(buff_total > base_total, "Soil Bounty raises matrix find value")
	_assert(buff_hits >= base_hits, "Soil Bounty can also raise matrix find chance")


func _test_stone_bounty_buffs_nodules() -> void:
	if Matrix == null:
		return
	_reset()
	var rng := RandomNumberGenerator.new()
	var n: int = 180
	rng.seed = 8
	var base_total: int = 0
	for _i in n:
		base_total += int(Matrix.roll(rng, 20).get("amount", 0))
	GS.levels["rock_pay"] = 6
	GS.apply_upgrades()
	_assert(str(GS.shop_item_desc("rock_pay")).to_lower().find("clay and rock pay") < 0, "Stone Bounty is not rock-dollar copy")
	rng.seed = 8
	var buff_total: int = 0
	for _i in n:
		buff_total += int(Matrix.roll(rng, 20).get("amount", 0))
	_assert(buff_total > base_total, "Stone Bounty raises nodule value or chance")


func _test_wide_scoop_batches_a_few_floats() -> void:
	if Matrix == null:
		return
	var pile: Array = []
	for i in 21:
		pile.append({"name": "pebble", "amount": 1, "rarity": 0})
	pile[3] = {"name": "tiny toothlet", "amount": 3, "rarity": 1}
	pile[9] = {"name": "amber speck", "amount": 5, "rarity": 2}
	_assert(Matrix.has_method("batch_display"), "wide scoops batch find floats")
	if not Matrix.has_method("batch_display"):
		return
	var juice: Array = Matrix.batch_display(pile)
	_assert(juice.size() >= 1 and juice.size() <= 5, "one or a few find sprites, not 21 flyers")
	var shown: int = 0
	var names: PackedStringArray = PackedStringArray()
	for raw in juice:
		shown += int(raw.get("amount", 0))
		names.append(str(raw.get("name", "")))
	_assert(shown <= 21 + 2 + 4, "capped sprites do not reprint the leftover as a fatter last label")
	var blob: String = " ".join(names).to_lower()
	_assert(blob.find("amber") >= 0 or blob.find("toothlet") >= 0, "the rare scrap still gets a sprite")


func _test_lucky_is_a_matrix_glint() -> void:
	if Lucky == null:
		return
	_assert(Lucky.has_method("toast_title"), "lucky strike exposes glint copy")
	if Lucky.has_method("toast_title"):
		var title: String = str(Lucky.toast_title()).to_lower()
		_assert(title.find("glint") >= 0, "the shiny cell is a glint in the matrix")
		_assert(title.find("beetle") < 0, "glint copy is not a beetle")
		_assert(title.find("lucky strike") < 0, "glint copy drops lucky-strike leftover")
	var lucky_src: String = FileAccess.get_file_as_string("res://lucky_strike.gd")
	var site_src: String = FileAccess.get_file_as_string("res://dig_site.gd")
	var main_src: String = FileAccess.get_file_as_string("res://main.gd")
	_assert(lucky_src.to_lower().find("beetle") < 0, "lucky script has no beetle leftover")
	_assert(site_src.to_lower().find("beetle") < 0, "dig site draw is not a beetle")
	_assert(main_src.to_lower().find("lucky strike!") < 0, "HUD toast is not Lucky strike!")
	var dirt: int = int(TN.money_for_layer(0))
	var burst: int = int(Lucky.burst_payout(dirt))
	_assert(burst >= dirt * 12, "a glint is still a fat cash burst")


func _test_summary_says_finds_not_dirt() -> void:
	var script: GDScript = load("res://summary.gd") as GDScript
	var line: String = str(script.call("pay_breakdown", 16, 51))
	_assert(line.find("Finds $51") >= 0, "shift-over names junk as Finds $")
	_assert(line.find("Fossils $16") >= 0, "shift-over names the tooth as Fossils $")
	_assert(line.to_lower().find("dirt $") < 0, "shift-over never says Dirt $")
	_assert(line.find("Fossil $16") < 0, "shift-over uses Fossils, not Fossil")


func _test_shop_copy_is_matrix_language() -> void:
	_reset()
	var soil: String = str(GS.shop_item_desc("dirt_pay")).to_lower()
	var stone: String = str(GS.shop_item_desc("rock_pay")).to_lower()
	var soil_feel: String = str(GS.upgrade_feel_line("dirt_pay")).to_lower()
	var stone_feel: String = str(GS.upgrade_feel_line("rock_pay")).to_lower()
	_assert(soil.find("matrix") >= 0 or soil.find("find") >= 0, "Soil Bounty talks about matrix finds")
	_assert(stone.find("nodule") >= 0 or stone.find("crystal") >= 0, "Stone Bounty talks about nodules")
	_assert(soil.find("dirt layers pay") < 0, "Soil Bounty drops dirt-price language")
	_assert(stone.find("rock pay") < 0, "Stone Bounty drops rock-dollar language")
	_assert(soil_feel.find("dirt pays") < 0, "Soil Bounty toast is not dirt pays more")
	_assert(stone_feel.find("stone pays") < 0, "Stone Bounty toast is not stone pays more")


func _test_float_is_currency_only() -> void:
	if Matrix == null:
		return
	var junk := {"name": "tiny toothlet", "amount": 12, "rarity": 1}
	var shell := {"name": "shell hash", "amount": 3, "rarity": 0}
	_assert(Matrix.has_method("float_text"), "currency floats live on MatrixFind")
	if not Matrix.has_method("float_text"):
		return
	_assert(str(Matrix.float_text(junk)) == "+$12", "a toothlet pays +$12, not +tooth")
	_assert(str(Matrix.float_text(shell)) == "+$3", "shell hash pays +$3, not +shell hash")
	var lucky_src: String = FileAccess.get_file_as_string("res://main.gd")
	_assert(lucky_src.find("glint  +$") < 0, "lucky juice is +$, not glint  +$")
	_assert(lucky_src.find("Matrix.float_text") >= 0 or lucky_src.find("+\"$") >= 0 or lucky_src.find("+$%d") >= 0, "matrix pops still spawn a +$ float")


func _test_sprite_is_the_item() -> void:
	if Matrix == null:
		return
	_assert(Matrix.has_method("icon_kind"), "each find has a fly icon")
	if not Matrix.has_method("icon_kind"):
		return
	_assert(str(Matrix.icon_kind("shell hash")) == "shell", "shell hash flies as a shell")
	_assert(str(Matrix.icon_kind("pebble")) == "pebble", "pebble flies as a pebble")
	_assert(str(Matrix.icon_kind("fish scale")) == "scale", "a scale flies as a scale")
	_assert(str(Matrix.icon_kind("nodule")) == "nodule", "a nodule flies as a nodule")
	_assert(str(Matrix.icon_kind("tiny toothlet")) == "speck", "a toothlet flies as a speck, not a museum tooth")
	_assert(str(Matrix.icon_kind("tiny toothlet")) != "tooth", "matrix toothlet is not the museum tooth icon")
	var Fly: GDScript = load("res://loot_fly.gd") as GDScript
	_assert(Fly != null, "loot_fly.gd exists so the object can fly to $")
	if Fly != null:
		_assert(Fly.has_method("arc_point"), "loot fly can arc toward the wallet")
		if Fly.has_method("arc_point"):
			var mid: Vector2 = Fly.arc_point(Vector2(100, 400), Vector2(40, 40), 0.5)
			_assert(mid.y < 400.0 and mid.y < 220.0, "the object arcs up on the way to $")
			_assert(Fly.arc_point(Vector2(100, 400), Vector2(40, 40), 1.0) == Vector2(40, 40), "the object lands on the wallet")


func _test_toothlet_is_not_a_museum_tooth() -> void:
	var hud_script: Script = load("res://hud.gd") as Script
	_assert(hud_script != null, "HUD still owns the named-fossil extract readout")
	if hud_script == null:
		return
	var hud: Node = hud_script.new()
	root.add_child(hud)
	if hud.has_method("refresh"):
		hud.call("refresh", 40.0, 40.0, TN.TOOL_BRUSH, true, true, 5, "Well preserved", 1.0, 80)
	if hud.has_method("set_find_headline"):
		hud.call("set_find_headline", "Tooth found!")
	var headline: Label = hud.get("_headline") as Label
	_assert(headline != null and headline.text == "Tooth found!", "named fossils still say Tooth found!")
	if Matrix != null and Matrix.has_method("float_text"):
		_assert(str(Matrix.float_text({"name": "tiny toothlet", "amount": 8})) != "Tooth found!", "a toothlet is not the extract footer")
	hud.queue_free()


func _test_wide_scoop_caps_sprites_without_merging() -> void:
	if Matrix == null or not Matrix.has_method("batch_display"):
		return
	var pile: Array = []
	for i in 21:
		pile.append({"name": "pebble", "amount": 1, "rarity": 0, "origin": Vector2(float(i) * 8.0, 0.0)})
	pile[3] = {"name": "tiny toothlet", "amount": 3, "rarity": 1, "origin": Vector2(24, 0)}
	pile[9] = {"name": "amber speck", "amount": 5, "rarity": 2, "origin": Vector2(72, 0)}
	var juice: Array = Matrix.batch_display(pile, 5)
	_assert(juice.size() >= 3 and juice.size() <= 5, "wide scoop flies 3-5 objects, not every cell")
	var shown: int = 0
	for raw in juice:
		shown += int(raw.get("amount", 0))
		_assert(int(raw.get("amount", 0)) <= 5, "leftover cash is not stuffed into the last sprite")
		_assert(raw.has("origin") or raw.has("name"), "a flying sprite still knows what it is")
	_assert(shown < 21 + 2 + 4, "uncapped cells still pay, but they do not each get a flyer")
	if Matrix.has_method("batch_leftover"):
		_assert(int(Matrix.batch_leftover(pile, 5)) == (21 + 2 + 4) - shown, "silent leftover still equals the unpaid scoop")


func _test_cells_can_show_a_terrain_tell() -> void:
	if Matrix == null:
		return
	_assert(Matrix.has_method("tell_strength"), "finds expose how loud the dirt speck should be")
	if Matrix.has_method("tell_strength"):
		_assert(float(Matrix.tell_strength(0)) < float(Matrix.tell_strength(1)), "common tells stay quieter than uncommon")
		_assert(float(Matrix.tell_strength(1)) < float(Matrix.tell_strength(2)), "rare tells sparkle more than uncommon")
		_assert(float(Matrix.tell_strength(0)) > 0.0, "even a common find leaves a subtle speck")
	var script: GDScript = load("res://dig_site.gd") as GDScript
	_assert(script != null, "dig_site can seed terrain tells")
	if script == null:
		return
	var site: Node2D = script.new()
	root.add_child(site)
	_assert(site.has_method("pending_find"), "each cell can show what is stuck in the face")
	if site.has_method("pending_find"):
		var told: int = 0
		var empty: int = 0
		for x in int(TN.grid_w):
			for y in int(TN.grid_h):
				var pending: Dictionary = site.call("pending_find", Vector2i(x, y))
				if pending.is_empty():
					empty += 1
				else:
					told += 1
					_assert(str(pending.get("name", "")) != "", "a tell names the inclusion, not a fossil extract")
					_assert(str(pending.get("name", "")).to_lower().find("tooth") < 0 or str(pending.get("name", "")).to_lower().find("toothlet") >= 0, "a dirt speck is not the museum Tooth")
		_assert(told > 0, "some cells show a pebble or speck before they pop")
		_assert(empty > 0 or float(TN.matrix_dirt_chance) >= 0.9, "empty cells stay plain dirt")
	site.queue_free()


func _test_lucky_float_is_currency() -> void:
	if Lucky == null:
		return
	_assert(Lucky.has_method("float_text"), "a glint pays with +$")
	if Lucky.has_method("float_text"):
		_assert(str(Lucky.float_text(48)) == "+$48", "lucky juice is +$48, not glint  +$48")
		_assert(str(Lucky.float_text(48)).to_lower().find("glint") < 0, "the bank number is not +glint")
	_assert(Lucky.has_method("icon_kind") and str(Lucky.icon_kind()) == "glint", "the shiny object flies as a glint")


func _assert(ok: bool, label: String) -> void:
	if ok:
		_passed += 1
		print("PASS  %s" % label)
	else:
		_failed += 1
		print("FAIL  %s" % label)
