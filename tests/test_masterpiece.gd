extends SceneTree

## The Cleaning Cart slowly cleans one exhibit's dirty bones (closing it);
## a complete stand with every bone Perfect and clean becomes a Masterpiece.
## Run: godot --headless --path <project> -s res://tests/test_masterpiece.gd

var _failed: int = 0
var _passed: int = 0
var GS: Node
var TN: Node
var _masters: Array = []
var _ready_stands: Array = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	GS = root.get_node("GameState")
	TN = root.get_node("Tuning")
	GS.masterpiece_completed.connect(func(stand_id: String, bonus: int) -> void: _masters.append([stand_id, bonus]))
	GS.masterpiece_ready.connect(func(stand_id: String) -> void: _ready_stands.append(stand_id))
	_test_cart_needs_the_upgrade()
	_test_cart_closes_its_exhibit()
	_test_cart_cleans_dirtiest_bone_slowly()
	_test_cart_climbs_one_level_per_interval()
	_test_cart_ties_go_to_the_pricier_bone_and_stay()
	_test_cart_is_a_late_game_upgrade()
	_test_catalog_tiers_never_go_backwards()
	_test_parked_cart_does_nothing()
	_test_cart_ranks_clean_faster()
	_test_cart_position_saves()
	await _test_masterpiece_waits_for_the_unveil()
	_test_unveil_brings_a_crowd()
	_test_masterpiece_upgrades_keep_paying()
	_test_masterpiece_unveil_survives_saving()
	_test_cleanup_crew_is_gone_and_refunded()
	await _test_masterpiece_needs_complete_and_great()
	await _test_cart_can_finish_a_masterpiece()
	_test_region_condition_is_the_weakest_bone()
	_test_fame_scales_bone_value_with_income()
	_test_find_card_says_new_or_duplicate()
	_test_empty_stand_still_opens_hover_card()
	_reset()
	print("masterpiece %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _reset() -> void:
	GS.pieces.clear()
	GS.pending_unveils.clear()
	GS.featured_stand_id = ""
	GS.cleaner_stand_id = ""
	GS.masterpieces_unveiled.clear()
	GS.masterpiece_crowd_left = 0.0
	GS.masterpiece_crowd_visitors = 0
	GS.money = 0
	for item in GS.catalog:
		GS.levels[item["id"]] = 0
	GS.apply_upgrades()
	_masters.clear()
	_ready_stands.clear()


func _fill_stand(stand: String, condition: int) -> void:
	for id in GS.stand_piece_ids(stand):
		while bool(GS.piece_needs_more(id)):
			GS.install_find(id, id, 1.0, true, condition)


func _own_cart(rank: int) -> void:
	GS.levels["workshop"] = rank
	GS.apply_upgrades()


func _test_cart_needs_the_upgrade() -> void:
	_reset()
	GS.install_find("t_rex_skull", "T. rex Skull", 0.3, false, 3)
	_assert(not bool(GS.set_cleaner_stand("t_rex")), "the cart cannot be placed before buying it")
	GS.cleaner_stand_id = "t_rex"
	_assert(not bool(GS.stand_is_being_cleaned("t_rex")), "an unowned cart closes nothing")
	GS._tick_cleaner(100.0)
	_assert(not bool(GS.piece_is_clean("t_rex_skull")), "the bone stays dirty")


func _test_cart_closes_its_exhibit() -> void:
	_reset()
	_own_cart(1)
	GS.install_find("t_rex_skull", "T. rex Skull", 0.3, false, 3)
	GS.install_find("triceratops_skull", "Triceratops Skull", 0.3, false, 3)
	GS.pending_unveils.clear()
	var open_income: float = float(GS.stand_income("t_rex"))
	_assert(open_income > 0.0, "an open exhibit earns")
	_assert(bool(GS.set_cleaner_stand("t_rex")), "the cart can be placed on a filled exhibit")
	_assert(bool(GS.stand_is_being_cleaned("t_rex")), "a dirty exhibit with the cart is closed")
	_assert(is_equal_approx(float(GS.stand_income("t_rex")), 0.0), "a closed exhibit earns nothing")
	_assert(float(GS.stand_income("triceratops")) > 0.0, "other exhibits keep earning")
	_assert(not bool(GS.set_cleaner_stand("stegosaurus")), "the cart cannot go to an empty exhibit")
	_assert(bool(GS.set_cleaner_stand("")), "the cart can be parked")
	_assert(is_equal_approx(float(GS.stand_income("t_rex")), open_income), "parking reopens the exhibit")


func _test_cart_cleans_dirtiest_bone_slowly() -> void:
	_reset()
	_own_cart(1)
	GS.install_find("t_rex_skull", "T. rex Skull", 0.6, false, 3)
	GS.install_find("t_rex_jaw", "T. rex Jaw", 0.2, false, 2)
	GS.pending_unveils.clear()
	GS.set_cleaner_stand("t_rex")
	_assert(str(GS.prep_cart_target()) == "t_rex_jaw", "the dirtiest bone is cleaned first")
	GS._tick_cleaner(10.0)
	var progress: float = float(GS.piece_cleanliness("t_rex_jaw"))
	_assert(progress > 0.2 and progress < 0.25, "cleaning is gradual, not instant")
	_assert(not bool(GS.piece_is_clean("t_rex_jaw")), "a bone is not clean after a few seconds")
	_assert(is_equal_approx(float(GS.piece_cleanliness("t_rex_skull")), 0.6), "only the target bone is worked on")
	GS._tick_cleaner(5000.0)
	_assert(bool(GS.piece_is_clean("t_rex_jaw")), "it ends up clean")
	_assert(int(GS.piece_condition("t_rex_jaw")) == 2, "stars do not change")
	_assert(str(GS.prep_cart_target()) == "t_rex_skull", "the cart moves on to the next dirty bone")
	GS._tick_cleaner(5000.0)
	_assert(bool(GS.piece_is_clean("t_rex_skull")), "every dirty bone gets done")
	_assert(not bool(GS.stand_is_being_cleaned("t_rex")), "the exhibit reopens on its own once spotless")
	_assert(float(GS.stand_income("t_rex")) > 0.0, "and earns again")
	_assert(str(GS.cleaner_stand_id) == "t_rex", "the cart stays put until moved")


func _test_cart_climbs_one_level_per_interval() -> void:
	## A level takes the rank's seconds however wide it is: 200s takes a Caked
	## bone to Dirty (25%), not to spotless.
	_reset()
	_own_cart(1)
	GS.install_find("t_rex_skull", "T. rex Skull", 0.0, false, 3)
	GS.pending_unveils.clear()
	GS.set_cleaner_stand("t_rex")
	var secs: float = float(GS.prep_cart_seconds(1))
	GS._tick_cleaner(secs - 1.0)
	_assert(float(GS.piece_cleanliness("t_rex_skull")) < 0.25, "just under one interval is still Caked")
	GS._tick_cleaner(2.0)
	var c: float = float(GS.piece_cleanliness("t_rex_skull"))
	_assert(c >= 0.25 and c < 0.6, "one interval raises it exactly one level, to Dirty")
	_assert(not bool(GS.piece_is_clean("t_rex_skull")), "it is nowhere near clean yet")
	var info: Dictionary = GS.prep_cart_level_info("t_rex_skull")
	_assert(float(info["to"]) > 0.59 and float(info["to"]) < 0.61, "the overlay shows it heading for Dusty")
	GS._tick_cleaner(secs * 2.0)
	_assert(bool(GS.piece_is_clean("t_rex_skull")), "three intervals clean a Caked bone")


func _test_cart_ties_go_to_the_pricier_bone_and_stay() -> void:
	## Two equally dirty bones: the more valuable one is cleaned first, and the
	## cart does not flip back and forth between them while it works.
	_reset()
	_own_cart(1)
	GS.install_find("t_rex_jaw", "T. rex Jaw", 0.2, false, 3)
	GS.install_find("t_rex_skull", "T. rex Skull", 0.2, false, 3)
	GS.pending_unveils.clear()
	GS.set_cleaner_stand("t_rex")
	_assert(str(GS.prep_cart_target()) == "t_rex_skull", "a tie goes to the more valuable bone")
	var flips: int = 0
	for _i in 2000:
		GS._tick_cleaner(2.0)
		if bool(GS.piece_is_clean("t_rex_skull")):
			break
		if str(GS.prep_cart_target()) != "t_rex_skull":
			flips += 1
	_assert(flips == 0, "the cart stays on the same bone until it is clean")
	_assert(bool(GS.piece_is_clean("t_rex_skull")), "the pricier bone finishes first")
	_assert(not bool(GS.piece_is_clean("t_rex_jaw")), "the cheaper one waits")
	_assert(str(GS.prep_cart_target()) == "t_rex_jaw", "then the cart moves to the cheaper bone")


func _max_museum_tier(tier: int) -> void:
	for item in GS.catalog:
		if str(item["cat"]) == "Museum" and int(item["tier"]) == tier and not bool(item.get("optional", false)):
			GS.levels[item["id"]] = int(item["max"])


func _test_cart_is_a_late_game_upgrade() -> void:
	## Masterpieces are a late-game goal, so the cart is too: it is a tier 3
	## Museum upgrade, priced like the other tier 3 upgrades, and it does not
	## hold up the tier 4 blockbuster upgrades.
	_reset()
	var item: Dictionary = GS._item("workshop")
	_assert(int(item["tier"]) == 3, "the cart is a tier 3 Museum upgrade")
	_assert(int(item["cost"]) >= 25000, "the cart is priced for the late game")
	GS.money = 100000000
	_assert(not bool(GS.can_buy("workshop")), "the cart is locked at the start, however rich you are")
	_max_museum_tier(1)
	_assert(not bool(GS.can_buy("workshop")), "maxing tier 1 alone is not enough")
	_max_museum_tier(2)
	_assert(bool(GS.can_buy("workshop")), "maxing tier 1 and 2 unlocks the cart")
	_max_museum_tier(3)
	_assert(bool(GS.tier_unlocked("blockbuster_ticket")), "tier 4 opens without buying the cart")
	_assert(int(GS.levels["workshop"]) == 0, "the cart was never bought")
	_assert(GS.prep_cart_seconds(1) >= 300, "a rank 1 cart is very slow")
	_reset()


func _test_catalog_tiers_never_go_backwards() -> void:
	## The shop opens a new tier section whenever the tier changes down the
	## catalog, so an out-of-place row shows a duplicate "Museum III" block.
	var last: Dictionary = {}
	var ok: bool = true
	var bad: String = ""
	for item in GS.catalog:
		var cat: String = str(item["cat"])
		var tier: int = int(item["tier"])
		if last.has(cat) and tier < int(last[cat]):
			ok = false
			bad = str(item["id"])
		last[cat] = tier
	_assert(ok, "catalog rows stay grouped by tier in every shop tab (%s)" % bad)


func _test_parked_cart_does_nothing() -> void:
	_reset()
	_own_cart(3)
	GS.install_find("t_rex_skull", "T. rex Skull", 0.3, false, 3)
	GS._tick_cleaner(500.0)
	_assert(not bool(GS.piece_is_clean("t_rex_skull")), "a parked cart cleans nothing")
	_assert(is_equal_approx(float(GS.piece_cleanliness("t_rex_skull")), 0.3), "and leaves dirt alone")


func _test_cart_ranks_clean_faster() -> void:
	_reset()
	_assert(GS.prep_cart_seconds(1) > GS.prep_cart_seconds(2) and GS.prep_cart_seconds(2) > GS.prep_cart_seconds(3), "higher ranks clean faster")
	_own_cart(3)
	_assert(str(GS.shop_effect_line("workshop")).contains("Cleans"), "shop line says how fast it cleans")


func _test_cleanup_crew_is_gone_and_refunded() -> void:
	## Cleanup Crew (paid dirty bones more) overlapped the cart and was removed.
	## Old saves get the money back and the upgrade is ignored.
	_reset()
	_assert(GS._item("restoration").is_empty(), "Cleanup Crew is no longer in the shop")
	var refund: int = int(GS.retired_refund({"restoration": 2}))
	_assert(refund == 1600 + int(round(1600.0 * 1.85)), "two ranks refund what they cost")
	_assert(int(GS.retired_refund({})) == 0, "no ranks, no refund")
	var path: String = "user://test_crew_refund.json"
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 1, "money": 100, "levels": {"restoration": 2}, "pieces": {}}))
	f.close()
	GS.load_game(path)
	_assert(int(GS.money) == 100 + refund, "loading an old save pays the refund")
	_assert(not GS.levels.has("restoration"), "the removed upgrade is not carried over")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_reset()


func _perfect_velociraptor_ready() -> void:
	_reset()
	_fill_stand("velociraptor", 5)
	GS.pending_unveils.clear()


func _test_masterpiece_waits_for_the_unveil() -> void:
	## Finishing a Masterpiece makes it ready. The bonus and the x2.5 draw only
	## start when the player unveils it.
	_reset()
	_fill_stand("velociraptor", 3)
	GS.pending_unveils.clear()
	for id in GS.stand_piece_ids("velociraptor"):
		GS.install_find(id, id, 1.0, true, 5)
	await process_frame
	var money: int = int(GS.money)
	var before: int = int(GS.stand_visitors("velociraptor"))
	_assert(bool(GS.stand_masterpiece_ready("velociraptor")), "a finished Perfect stand is ready to unveil")
	_assert(not bool(GS.stand_masterpiece_active("velociraptor")), "but its boost is not active yet")
	_assert(int(GS.money) == money and _masters.is_empty(), "nothing is paid before the unveil")
	_assert(GS.has_ready_masterpiece(), "the hall knows a Masterpiece is waiting")
	var bonus: int = int(GS.unveil_masterpiece("velociraptor"))
	_assert(bonus > 0 and int(GS.money) >= money + bonus, "the unveil pays the bonus")
	_assert(not bool(GS.stand_masterpiece_ready("velociraptor")) and bool(GS.stand_masterpiece_active("velociraptor")), "an unveiled Masterpiece is active")
	_assert(int(GS.stand_visitors("velociraptor")) > int(float(before) * 2.3), "the x2.5 draw starts at the unveil")
	_assert(int(GS.unveil_masterpiece("velociraptor")) == 0, "a Masterpiece can only be unveiled once")
	_assert(not GS.has_ready_masterpiece(), "nothing is waiting any more")
	_assert(int(GS.unveil_masterpiece("t_rex")) == 0, "an unfinished stand cannot be unveiled")


func _test_unveil_brings_a_crowd() -> void:
	_perfect_velociraptor_ready()
	var base: int = int(GS.museum_visitors_base())
	GS.unveil_masterpiece("velociraptor")
	_assert(float(GS.masterpiece_crowd_left) > 0.0 and int(GS.masterpiece_crowd_visitors) >= int(TN.masterpiece_crowd_min), "a crowd rushes in")
	_assert(int(GS.museum_visitors()) > int(GS.museum_visitors_base()), "the crowd adds visitors on top of the museum's usual ones")
	_assert(str(GS.unveil_rush_line()).begins_with("Masterpiece unveiling"), "the header says a Masterpiece unveiling is under way")
	_assert(int(GS.visitor_sprite_count()) <= int(GS._packed_visitor_sprites(GS.museum_visitors_base())) + int(TN.masterpiece_crowd_max_sprites), "a huge crowd does not draw hundreds of walkers")
	var income: float = float(GS.museum_income())
	GS._process(float(GS.masterpiece_crowd_left) + 1.0)
	_assert(is_equal_approx(float(GS.masterpiece_crowd_left), 0.0) and int(GS.masterpiece_crowd_visitors) == 0, "the crowd leaves")
	_assert(int(GS.museum_visitors()) == int(GS.museum_visitors_base()), "the museum goes back to its usual crowd")
	_assert(float(GS.museum_income()) < income, "and its usual income")
	_assert(base > 0, "there was a crowd to begin with")


func _test_masterpiece_upgrades_keep_paying() -> void:
	## Only five stands can be Masterpieces, so the upgrades are for owning them,
	## not for the one-off unveil: they help all game once a Masterpiece is unveiled.
	_perfect_velociraptor_ready()
	GS.unveil_masterpiece("velociraptor")
	GS.masterpiece_crowd_left = 0.0
	GS.masterpiece_crowd_visitors = 0
	var stand_before: int = int(GS.stand_visitors("velociraptor"))
	var museum_before: int = int(GS.museum_visitors_base())
	GS.levels["masterpiece_prestige"] = 2
	GS.apply_upgrades()
	_assert(is_equal_approx(float(TN.masterpiece_mult), 3.5), "two ranks of Masterpiece Prestige make a Masterpiece draw x3.5")
	_assert(int(GS.stand_visitors("velociraptor")) > stand_before, "Masterpiece Prestige raises an unveiled Masterpiece's crowd")
	var after_prestige: int = int(GS.museum_visitors_base())
	GS.levels["masterpiece_renown"] = 2
	GS.apply_upgrades()
	_assert(int(GS.museum_visitors_base()) > after_prestige, "Critics' Acclaim lifts the whole museum once a Masterpiece is unveiled")
	_assert(is_equal_approx(float(GS.masterpiece_renown_mult()), 1.06), "two ranks with one Masterpiece is +6%")
	_assert(museum_before > 0, "there was a museum to lift")
	## A Masterpiece that is only ready (not unveiled) does not count.
	_perfect_velociraptor_ready()
	GS.levels["masterpiece_renown"] = 4
	GS.apply_upgrades()
	_assert(is_equal_approx(float(GS.masterpiece_renown_mult()), 1.0), "a Masterpiece waiting to be unveiled adds nothing yet")
	for id in ["masterpiece_prestige", "masterpiece_renown"]:
		var item: Dictionary = GS._item(id)
		_assert(not item.is_empty() and str(item["cat"]) == "Museum" and int(item["tier"]) == 4, "%s is a Museum IV upgrade" % id)
		_assert(str(GS.shop_effect_line(id)) != "", "%s explains its effect" % id)
	for id in ["gala_payout", "gala_crowd", "gala_hours", "blockbuster_hours"]:
		_assert(GS._item(id).is_empty(), "%s is gone" % id)
		_assert(int(GS.retired_refund({id: 1})) > 0, "%s ranks are refunded" % id)
	_reset()


func _test_masterpiece_unveil_survives_saving() -> void:
	_perfect_velociraptor_ready()
	var path: String = "user://test_masterpiece_save.json"
	GS.save_game(path)
	GS.masterpieces_unveiled.clear()
	GS.load_game(path)
	_assert(bool(GS.stand_masterpiece_ready("velociraptor")), "a Masterpiece that was never unveiled is still waiting after loading")
	GS.unveil_masterpiece("velociraptor")
	GS.save_game(path)
	GS.masterpieces_unveiled.clear()
	GS.masterpiece_crowd_left = 0.0
	GS.load_game(path)
	_assert(bool(GS.stand_masterpiece_active("velociraptor")), "an unveiled Masterpiece stays unveiled")
	_assert(float(GS.masterpiece_crowd_left) > 0.0 and int(GS.masterpiece_crowd_visitors) > 0, "a running Masterpiece crowd is saved")
	## A save from before the ceremony has no record: its Masterpieces were paid already.
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	var data: Dictionary = JSON.parse_string(file.get_as_text())
	file.close()
	data.erase("masterpieces_unveiled")
	var out: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	out.store_string(JSON.stringify(data))
	out.close()
	GS.masterpieces_unveiled.clear()
	GS.load_game(path)
	_assert(bool(GS.stand_masterpiece_active("velociraptor")), "an old save's Masterpiece counts as already unveiled")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_reset()


func _test_cart_position_saves() -> void:
	_reset()
	_own_cart(1)
	GS.install_find("t_rex_skull", "T. rex Skull", 0.3, false, 3)
	GS.pending_unveils.clear()
	GS.set_cleaner_stand("t_rex")
	var path: String = "user://test_cart_save.json"
	GS.save_game(path)
	GS.cleaner_stand_id = ""
	GS.load_game(path)
	_assert(str(GS.cleaner_stand_id) == "t_rex", "the cart's exhibit is saved")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _test_masterpiece_needs_complete_and_great() -> void:
	_reset()
	_fill_stand("velociraptor", 3)
	await process_frame
	_assert(bool(GS.stand_is_complete("velociraptor")), "stand is complete")
	_assert(not bool(GS.stand_is_masterpiece("velociraptor")), "Good bones are not a Masterpiece")
	_assert(_masters.is_empty(), "no masterpiece celebration yet")
	var plain: int = int(GS.stand_visitors("velociraptor"))
	for id in GS.stand_piece_ids("velociraptor"):
		GS.install_find(id, id, 1.0, true, 5)
	await process_frame
	_assert(bool(GS.stand_is_masterpiece("velociraptor")), "all Perfect makes a Masterpiece")
	_assert(_ready_stands == ["velociraptor"], "the Masterpiece is announced once, as ready to unveil")
	_assert(_masters.is_empty(), "nothing is paid until it is unveiled")
	GS.unveil_masterpiece("velociraptor")
	_assert(_masters.size() == 1 and str(_masters[0][0]) == "velociraptor", "the unveil is celebrated once")
	_assert(int(_masters[0][1]) > 0 if not _masters.is_empty() else false, "it pays a bonus")
	_assert(int(GS.stand_visitors("velociraptor")) > plain * 2, "an unveiled Masterpiece of Perfect bones draws far more")


func _test_cart_can_finish_a_masterpiece() -> void:
	## A Masterpiece needs every bone Perfect AND clean: one dirty bone blocks
	## it, and the Cleaning Cart cleaning it finishes the Masterpiece.
	_reset()
	_fill_stand("velociraptor", 5)
	await process_frame
	_assert(bool(GS.stand_is_masterpiece("velociraptor")), "all Perfect, clean bones make a Masterpiece")
	_masters.clear()
	_ready_stands.clear()
	var ids: PackedStringArray = GS.stand_piece_ids("velociraptor")
	var piece: Dictionary = GS.pieces[ids[0]]
	piece["clean"] = false
	piece["cleanliness"] = 0.4
	GS.pieces[ids[0]] = piece
	_assert(not bool(GS.stand_is_masterpiece("velociraptor")), "one dirty bone blocks the Masterpiece")
	_own_cart(1)
	GS.pending_unveils.clear()
	GS.set_cleaner_stand("velociraptor")
	GS._tick_cleaner(5000.0)
	_assert(bool(GS.stand_is_masterpiece("velociraptor")), "the Cleaning Cart cleaning it completes the Masterpiece")
	_assert(_ready_stands == ["velociraptor"], "and it is announced as ready to unveil")
	piece = GS.pieces[ids[0]]
	piece["condition"] = 4
	GS.pieces[ids[0]] = piece
	var info: Dictionary = _exhibit_info("velociraptor")
	if not info.is_empty():
		_assert((info["bones"] as Array).size() == ids.size(), "the star card lists every bone")
		_assert(absf(float(info["avg"]) - (5.0 * float(ids.size() - 1) + 4.0) / float(ids.size())) < 0.01, "the star card shows the average")


func _exhibit_info(stand_id: String) -> Dictionary:
	var ex: Node = load("res://museum_exhibit.gd").new()
	var info: Dictionary = ex.call("stand_condition_info", stand_id)
	ex.free()
	return info


func _test_region_condition_is_the_weakest_bone() -> void:
	## The museum colors each part by its weakest bone, so stars have a visible cause.
	_reset()
	GS.install_find("t_rex_skull", "T. rex Skull", 1.0, true, 5)
	var region: String = str(GS.fossil_data_for("t_rex_skull").mount_region)
	_assert(int(GS.stand_region_condition("t_rex", region)) == 5, "a Perfect skull paints its region Perfect")
	for id in GS.stand_piece_ids("t_rex"):
		if id != "t_rex_skull" and str(GS.fossil_data_for(id).mount_region) == region:
			GS.install_find(id, id, 1.0, true, 1)
			_assert(int(GS.stand_region_condition("t_rex", region)) == 1, "a Poor bone in the same region shows as Poor")
			break
	var exhibit_script: GDScript = load("res://museum_exhibit.gd") as GDScript
	var exhibit: Node2D = exhibit_script.new()
	root.add_child(exhibit)
	_reset()
	GS.install_find("t_rex_skull", "T. rex Skull", 1.0, true, 2)
	_assert(str(exhibit.call("stand_condition_note", "t_rex")).contains("below Perfect"), "the stand says how many bones are below Perfect")
	exhibit.queue_free()


func _test_fame_scales_bone_value_with_income() -> void:
	_reset()
	_reset_fame_cache()
	_assert(is_equal_approx(float(GS.fame_mult()), 1.0), "an empty museum pays base price")
	for sid in ["t_rex", "triceratops", "velociraptor"]:
		_fill_stand(sid, 5)
	GS.fame_mult()
	var income: float = float(GS.museum_income_base())
	GS.set("_fame_frame", -1)
	_assert(float(GS.fame_mult()) > 1.0 + income * float(TN.fame_per_income) - 0.01, "fame grows with museum income")
	_assert(str(GS.fame_line()).contains("finds pay x"), "the tray explains the fame bonus in plain words")


func _reset_fame_cache() -> void:
	GS.set("_fame_frame", -1)


func _test_find_card_says_new_or_duplicate() -> void:
	var chip_script: GDScript = load("res://find_chip.gd") as GDScript
	var chip: Control = chip_script.new()
	root.add_child(chip)
	_assert(str(chip.call("_museum_line", "New · 1/6")).begins_with("New for museum"), "a needed bone says New for museum")
	_assert(str(chip.call("_museum_line", "Duplicate · 6/6")).begins_with("Duplicate"), "an extra copy says Duplicate")
	_assert(str(chip.call("_museum_line", "Upgrade · Great")).begins_with("Upgrades exhibit"), "a better copy says it upgrades the exhibit")
	_assert(str(chip.call("_note_line", {"cast": true, "kind": TN.BONE_FRAGILE})).contains("losing stars"), "plaster on a fragile bone says what it saved")
	_assert(str(chip.call("_note_line", {"cast": true, "kind": TN.BONE_SOLID})) == "", "plaster on a solid bone adds no noise")
	chip.queue_free()


func _test_empty_stand_still_opens_hover_card() -> void:
	## Empty stands still show $0.00 / sec. Hovering that chip (or the empty
	## bay) must open the same museum card: missing bones + Masterpiece path.
	_reset()
	_assert(not bool(GS.stand_is_filled("velociraptor")), "Velociraptor starts empty")
	_assert(is_equal_approx(float(GS.stand_income("velociraptor")), 0.0), "empty stand earns $0 / sec")
	var exhibit: Node2D = (load("res://museum_exhibit.gd") as GDScript).new()
	root.add_child(exhibit)
	var rate: Rect2 = exhibit.call("stand_rate_rect", "velociraptor")
	_assert(rate.size != Vector2.ZERO, "empty stand still paints a $/sec chip")
	_assert(str(exhibit.call("stand_at_card", rate.get_center())) == "velociraptor", "hovering the $0 chip opens the stand card")
	_assert(str(exhibit.call("stand_at_card", exhibit.stand_rect("velociraptor").get_center())) == "velociraptor", "hovering the empty bay opens the stand card")
	var info: Dictionary = exhibit.call("stand_condition_info", "velociraptor")
	var bones: Array = info.get("bones", [])
	_assert(bones.size() == GS.stand_piece_ids("velociraptor").size(), "empty card lists every missing bone")
	_assert(int(info.get("total", -1)) == 0, "empty card counts zero found bones")
	_assert(is_equal_approx(float(info.get("income", -1.0)), 0.0), "empty card shows $0 / sec")
	_assert(str(info.get("word", "")).to_lower().find("empty") >= 0 or int(info.get("stars", -1)) == 0, "empty card does not pretend it is rated")
	var tip: Control = (load("res://star_tip.gd") as GDScript).new()
	root.add_child(tip)
	tip.call("show_info", info)
	_assert(tip.size.x > 40.0 and tip.size.y > 40.0, "empty stand tip has a real card size")
	_assert(str(tip.call("_avg_line")).to_lower().find("mounted") >= 0 or str(tip.call("_avg_line")).to_lower().find("nothing") >= 0, "empty tip says nothing is mounted yet")
	_assert(str(tip.call("_master_line")).to_lower().find("masterpiece") >= 0, "empty tip still names the Masterpiece path")
	## Filled stands keep the stars + $/sec hit targets.
	_fill_stand("velociraptor", 4)
	var filled_rate: Rect2 = exhibit.call("stand_rate_rect", "velociraptor")
	_assert(str(exhibit.call("stand_at_card", filled_rate.get_center())) == "velociraptor", "filled $/sec chip still opens the card")
	var mus: Node = (load("res://museum.gd") as GDScript).new()
	root.add_child(mus)
	mus.visible = true
	_reset()
	var empty_exhibit: Node2D = mus._canvas
	var chip: Rect2 = empty_exhibit.call("stand_rate_rect", "velociraptor")
	var zoom: float = empty_exhibit.scale.x
	var pad_pos: Vector2 = chip.get_center() * zoom - Vector2(0.0, mus.HEADER_H) + mus._pan
	mus.call("_update_star_tip", pad_pos)
	var star_tip: Control = mus.get("_star_tip")
	_assert(star_tip != null and star_tip.visible, "museum shows the hover card over an empty stand chip")
	tip.queue_free()
	exhibit.queue_free()
	mus.free()


func _assert(ok: bool, label: String) -> void:
	if ok:
		_passed += 1
		print("PASS  %s" % label)
	else:
		_failed += 1
		print("FAIL  %s" % label)
