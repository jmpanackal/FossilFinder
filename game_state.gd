extends Node

signal money_changed

const UiStyle := preload("res://ui_style.gd")
signal collection_changed
signal upgrades_changed
signal hall_changed
## The Cleaning Cart finished a bone.
signal cleaner_finished(piece_id: String)
signal progress_reset
signal skeleton_completed(stand_id: String, bonus: int)
## Complete stand where every bone is Perfect.
signal masterpiece_completed(stand_id: String, bonus: int)

const STAND_T_REX := "t_rex"
const STAND_TRICERATOPS := "triceratops"
const STAND_BRACHIOSAURUS := "brachiosaurus"
const STAND_VELOCIRAPTOR := "velociraptor"
const STAND_STEGOSAURUS := "stegosaurus"
const STAND_SMALL_FINDS := "small_finds"
const STAND_PLANT_FOSSILS := "plant_fossils"
const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 1
## Upgrades that no longer exist. Ranks in old saves are refunded at what they
## cost (base cost x scale^rank for each rank bought).
const RETIRED_UPGRADES := {"restoration": {"cost": 1600, "scale": 1.85}}

var money: int = 0
var levels: Dictionary = {}
var pieces: Dictionary = {}
var precision_on: bool = false
var pending_notices: Array = []
var last_unlock_title: String = ""
var last_unlocked_ids: Array[String] = []
var featured_stand_id: String = ""
## Stand the Cleaning Cart is parked at ("" = parked in the bay).
var cleaner_stand_id: String = ""
var cleaner_finished_name: String = ""
## The bone the cart is currently on (see prep_cart_target).
var _cart_target: String = ""
## One-time explainer hints the player has already seen (saved).
var hints_seen: Dictionary = {}
var pending_unveils: Dictionary = {}
var unveil_spike_left: float = 0.0
var unveil_rush_stacks: int = 0
var unveil_rush_unit: float = 0.0
var _income_accum: float = 0.0
var _bases: Dictionary = {}
var _fossil_by_id: Dictionary = {}
var _stand_ids_cache: Dictionary = {}
var _stand_scale_cache: Dictionary = {}

var catalog: Array[Dictionary] = [
	{"id": "hands_click", "cat": "Hands", "tier": 1, "name": "Calloused Fingers", "desc": "A careful one-cell harvest. Better finds and more $. Weaker dirt than a shovel, and they do not chip bone.", "cost": 8, "scale": 1.65, "max": 5},
	{"id": "hands_hold", "cat": "Hands", "tier": 1, "name": "Steady Hands", "desc": "Hold digs faster.", "unlock_name": "Hold to Dig", "unlock_desc": "Click and hold to keep digging.", "unlock_action": "Unlock", "cost": 36, "scale": 1.65, "max": 4},
	{"id": "hands_sense", "cat": "Hands", "tier": 1, "name": "Bone Sense", "desc": "Feel for buried bone farther away.", "unlock_name": "Bone Sense", "unlock_desc": "Digging by hand marks buried bone in nearby cells.", "unlock_action": "Unlock", "cost": 60, "scale": 1.9, "max": 4},
	{"id": "hands_cast", "cat": "Hands", "tier": 1, "name": "Plaster Cast", "desc": "Plaster faster: a quicker hold means you catch the +1★ window more often.", "unlock_name": "Plaster Cast", "unlock_desc": "Hold Hands on a crumbling bone to plaster it. Quick plaster gains a star; late plaster only keeps it.", "unlock_action": "Unlock", "cost": 140, "scale": 2.2, "max": 3},
	{"id": "hands_burlap", "cat": "Hands", "tier": 2, "name": "Wet Burlap", "desc": "Keeps dug-out Fragile and Opal bones damp: more time before each lost star.", "unlock_name": "Wet Burlap", "unlock_desc": "Drape damp cloth over crumbling bones: they take longer to lose each star, so you have more time to brush and plaster.", "unlock_action": "Unlock", "cost": 2200, "scale": 1.9, "max": 4, "requires": "hands_cast"},
	{"id": "hands_craft", "cat": "Hands", "tier": 2, "name": "Fieldcraft", "desc": "Better finds and more $. With Bone Sense, a much wider feel for buried bone.", "cost": 1500, "scale": 1.85, "max": 6},
	{"id": "hands_swift", "cat": "Hands", "tier": 2, "name": "Quick Hands", "desc": "Hold harvests faster.", "cost": 1800, "scale": 1.8, "max": 5},
	{"id": "hands_consolidant", "cat": "Hands", "tier": 3, "name": "Consolidant", "desc": "Quick plaster gains +2 stars instead of +1.", "unlock_name": "Consolidant", "unlock_desc": "A hardening resin soaked in before the plaster: quick plaster now gains +2 stars (then +1, then keeps, as it dries).", "unlock_action": "Unlock", "cost": 60000, "scale": 1.0, "max": 1, "requires": "hands_burlap"},
	{"id": "hands_resin", "cat": "Hands", "tier": 4, "name": "Museum Resin", "desc": "Quick plaster gains +3 stars.", "unlock_name": "Museum Resin", "unlock_desc": "Lab-grade resin: quick plaster now gains +3 stars, turning even a Fair bone Perfect if you are fast.", "unlock_action": "Unlock", "cost": 900000, "scale": 1.0, "max": 1, "requires": "hands_consolidant"},
	{"id": "shovel_click", "cat": "Shovel", "tier": 1, "name": "Heavy Swings", "desc": "Clicks hit dirt much harder (holding a bit harder too).", "unlock_name": "Shovel", "unlock_desc": "A rusty shovel. Barely better than your hands.", "cost": 24, "scale": 2.0, "max": 6},
	{"id": "shovel_hold", "cat": "Shovel", "tier": 1, "name": "Steady Shoveling", "desc": "Hold digs faster.", "unlock_name": "Hold to Dig", "unlock_desc": "Click and hold to keep digging.", "unlock_action": "Unlock", "cost": 75, "scale": 2.0, "max": 5, "requires": "shovel_click"},
	{"id": "shovel_radius", "cat": "Shovel", "tier": 1, "name": "Wider Scoop", "desc": "Covers more ground.", "unlock_name": "Wider Scoop", "unlock_desc": "The shovel covers more than one cell.", "unlock_action": "Unlock", "cost": 120, "scale": 2.05, "max": 4, "requires": "shovel_click"},
	{"id": "shovel_super", "cat": "Shovel", "tier": 2, "name": "Super Shovel", "desc": "A heavier class of shovel. Hits harder and covers more.", "cost": 4000, "scale": 1.95, "max": 6},
	{"id": "shovel_soft", "cat": "Shovel", "tier": 2, "name": "Gentle Digging", "desc": "Digging gently means more bones come up in great shape.", "cost": 2200, "scale": 1.95, "max": 5},
	{"id": "shovel_titan", "cat": "Shovel", "tier": 3, "name": "Titan Shovel", "desc": "The heaviest shovel. Hits harder and covers more.", "cost": 80000, "scale": 1.7, "max": 6},
	{"id": "pick_click", "cat": "Pickaxe", "tier": 1, "name": "Sharp Strikes", "desc": "Clicks hit clay and rock much harder (holding a bit harder too).", "unlock_name": "Pickaxe", "unlock_desc": "Needed for clay and stone. Weak on dirt.", "cost": 145, "scale": 1.8, "max": 6, "requires": "shovel_click"},
	{"id": "pick_hold", "cat": "Pickaxe", "tier": 1, "name": "Relentless Picking", "desc": "Hold digs faster.", "unlock_name": "Hold to Dig", "unlock_desc": "Click and hold to keep striking.", "unlock_action": "Unlock", "cost": 175, "scale": 1.8, "max": 5, "requires": "pick_click"},
	{"id": "pick_radius", "cat": "Pickaxe", "tier": 1, "name": "Wider Scoop", "desc": "Covers more ground.", "unlock_name": "Wider Scoop", "unlock_desc": "The pickaxe cracks a wider patch of stone.", "unlock_action": "Unlock", "cost": 150, "scale": 1.9, "max": 4, "requires": "pick_click"},
	{"id": "pick_super", "cat": "Pickaxe", "tier": 2, "name": "Super Pick", "desc": "A heavier pick. Clay and rock give faster.", "cost": 4500, "scale": 1.95, "max": 6},
	{"id": "pick_soft", "cat": "Pickaxe", "tier": 2, "name": "Gentle Picking", "desc": "Careful strikes mean more bones come up in great shape.", "cost": 2200, "scale": 1.95, "max": 5},
	{"id": "pick_titan", "cat": "Pickaxe", "tier": 3, "name": "Titan Pick", "desc": "The heaviest pick. Clay and rock give faster.", "cost": 80000, "scale": 1.7, "max": 6},
	{"id": "brush_speed", "cat": "Brush", "tier": 1, "name": "Softer Bristles", "desc": "Dusting goes faster and the bristles reach the next bone cell.", "unlock_name": "Brush", "unlock_desc": "A slow brush. Clean bones sell for more.", "cost": 250, "scale": 1.85, "max": 5, "requires": "shovel_click"},
	{"id": "brush_master", "cat": "Brush", "tier": 2, "name": "Master Brush", "desc": "Faster dusting and a much wider sweep.", "cost": 3500, "scale": 1.95, "max": 6},
	{"id": "round_time", "cat": "Site", "tier": 1, "name": "Longer Shift", "desc": "More seconds each dig.", "cost": 80, "scale": 1.95, "max": 4},
	{"id": "dirt_pay", "cat": "Site", "tier": 1, "name": "Soil Bounty", "desc": "Small finds in the soil pay more, especially by hand.", "cost": 50, "scale": 1.9, "max": 5},
	{"id": "site_size", "cat": "Site", "tier": 1, "name": "Wider Claim", "desc": "The next dig uses a larger pit.", "cost": 100, "scale": 2.1, "max": 3},
	{"id": "scrap_bed", "cat": "Site", "tier": 1, "name": "Scattered Fossils", "desc": "Better odds of extra fossils. Each one found may mean another is hiding.", "unlock_name": "Scattered Fossils", "unlock_desc": "Extra fossils may hide in the pit. You never know how many: keep digging to find out.", "unlock_action": "Unlock", "cost": 160, "scale": 2.0, "max": 2},
	{"id": "rich_bed", "cat": "Site", "tier": 2, "name": "Rich Bed", "desc": "Better odds of extra fossils.", "unlock_name": "Rich Bed", "unlock_desc": "Large bones can appear in the pit.", "unlock_action": "Unlock", "cost": 1400, "scale": 1.9, "max": 3},
	{"id": "site_expand", "cat": "Site", "tier": 2, "name": "Open Ground", "desc": "Stretch the claim much farther.", "cost": 2200, "scale": 1.95, "max": 5},
	{"id": "rock_pay", "cat": "Site", "tier": 2, "name": "Stone Bounty", "desc": "Nodules and crystals in stone pay more.", "cost": 1000, "scale": 1.85, "max": 6},
	{"id": "money_mult", "cat": "Site", "tier": 2, "name": "Keen Eye", "desc": "Everything you dig is worth more.", "cost": 1500, "scale": 1.85, "max": 6},
	{"id": "fossil_value", "cat": "Site", "tier": 2, "name": "Careful Hands", "desc": "Clean fossils sell for more.", "cost": 1400, "scale": 1.85, "max": 6},
	{"id": "round_marathon", "cat": "Site", "tier": 3, "name": "Marathon Shift", "desc": "Shifts run longer than a full Longer Shift.", "cost": 25000, "scale": 1.74, "max": 6},
	{"id": "prime_bed", "cat": "Site", "tier": 3, "name": "Prime Bed", "desc": "Better odds of extra fossils. Each one found may mean another is hiding.", "cost": 28000, "scale": 1.7, "max": 4},
	{"id": "lighting", "cat": "Museum", "tier": 1, "name": "Warm Lights", "desc": "The display earns more from visitors.", "cost": 500, "scale": 2.0, "max": 5},
	{"id": "spotlight", "cat": "Museum", "tier": 1, "name": "Featured exhibit 2x", "desc": "Featured exhibit 3x.", "unlock_name": "Unlock Spotlight", "unlock_desc": "Featured exhibit 2x.", "unlock_action": "Unlock", "cost": 280, "scale": 1.9, "max": 3},
	{"id": "benches", "cat": "Museum", "tier": 1, "name": "Benches", "desc": "Guests sit, linger, and donate.", "cost": 450, "scale": 2.0, "max": 5},
	{"id": "unveil_time", "cat": "Museum", "tier": 1, "name": "Opening Hours", "desc": "Unveiling rushes last longer.", "cost": 200, "scale": 1.85, "max": 4},
	{"id": "unveil_crowd", "cat": "Museum", "tier": 1, "name": "Opening Crowd", "desc": "Unveiling rushes bring more people.", "cost": 220, "scale": 1.85, "max": 4},
	{"id": "glass_case", "cat": "Museum", "tier": 2, "name": "Glass Case", "desc": "A better case adds a steady visitor bonus.", "cost": 1000, "scale": 1.85, "max": 6},
	{"id": "labels", "cat": "Museum", "tier": 2, "name": "Clear Labels", "desc": "People stay longer and pay more.", "cost": 3200, "scale": 2.55, "max": 6},
	{"id": "gift_shop", "cat": "Museum", "tier": 2, "name": "Gift Counter", "desc": "Small souvenirs raise income.", "cost": 6400, "scale": 2.62, "max": 6},
	{"id": "crowds", "cat": "Museum", "tier": 3, "name": "Weekend Crowds", "desc": "More foot traffic every second.", "cost": 4000, "scale": 1.95, "max": 6},
	{"id": "workshop", "cat": "Museum", "tier": 3, "name": "Cleaning Cart", "desc": "The cart climbs each dirt level faster.", "unlock_name": "Cleaning Cart", "unlock_desc": "Drag the cart onto an exhibit to slowly clean its dirty bones. The exhibit is closed and earns nothing while the cart is there. Drag it to the parking bay to reopen everything.", "unlock_action": "Unlock", "cost": 30000, "scale": 2.2, "max": 3, "optional": true},
	{"id": "blockbuster_ticket", "cat": "Museum", "tier": 4, "name": "Box Office", "desc": "Tickets pay more.", "cost": 120000, "scale": 1.90, "max": 6},
	{"id": "blockbuster_crowd", "cat": "Museum", "tier": 4, "name": "Sellout Crowd", "desc": "More visitors: +20% of your crowd per rank.", "cost": 140000, "scale": 1.75, "max": 5},
	{"id": "blockbuster_hours", "cat": "Museum", "tier": 4, "name": "Encore Rush", "desc": "Unveiling rushes last longer.", "cost": 130000, "scale": 1.7, "max": 4},
	{"id": "blockbuster_feature", "cat": "Museum", "tier": 4, "name": "Marquee", "desc": "The featured stand pays even more.", "cost": 150000, "scale": 1.65, "max": 2},
]


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_bases = {
		"hands_click_mult": Tuning.hands_click_mult,
		"shovel_click_mult": Tuning.shovel_click_mult,
		"shovel_hold_tick_rate": Tuning.shovel_hold_tick_rate,
		"shovel_radius": Tuning.shovel_radius,
		"pickaxe_radius": Tuning.pickaxe_radius,
		"pickaxe_click_mult": Tuning.pickaxe_click_mult,
		"pickaxe_hold_tick_rate": Tuning.pickaxe_hold_tick_rate,
		"brush_clean_per_pixel": Tuning.brush_clean_per_pixel,
		"round_seconds": Tuning.base_round_seconds,
		"museum_income_mult": Tuning.museum_income_mult,
		"precision_damage_bonus": 0.0,
		"money_mult": Tuning.money_mult,
		"exhibit_flat_income": 0.0,
		"dirt_money_bonus": 0.0,
		"rock_money_bonus": 0.0,
		"matrix_dirt_chance": 0.48,
		"matrix_stone_chance": 0.55,
		"fossil_value_mult": 1.0,
		"integrity_hit_cost": Tuning.integrity_hit_cost,
		"unveil_spike_seconds": Tuning.unveil_spike_seconds,
		"unveil_rush_strength": Tuning.unveil_rush_strength,
		"spotlight_mult": 1.0,
	}
	for item in catalog:
		levels[item["id"]] = 0
	apply_upgrades()


func _process(delta: float) -> void:
	if cleaner_stand_id != "":
		_tick_cleaner(delta)
	var rate: float = museum_income()
	if rate > 0.0:
		_income_accum += rate * delta
		if _income_accum >= 1.0:
			var gained: int = int(_income_accum)
			_income_accum -= float(gained)
			add_money(gained)
	if unveil_spike_left > 0.0:
		unveil_spike_left = maxf(0.0, unveil_spike_left - delta)
		if unveil_spike_left <= 0.0:
			_clear_unveil_rush()
			hall_changed.emit()


## True the first time a hint id is asked for; marks it seen.
func take_hint(id: String) -> bool:
	if hints_seen.has(id):
		return false
	hints_seen[id] = true
	return true


func add_money(amount: int) -> void:
	if amount == 0:
		return
	money += amount
	money_changed.emit()


func tier_unlocked(id: String) -> bool:
	var item := _item(id)
	if item.is_empty():
		return false
	var tier: int = int(item.get("tier", 1))
	if tier <= 1:
		return true
	var group := str(item.get("cat", ""))
	for other in catalog:
		if str(other.get("cat", "")) != group:
			continue
		if int(other.get("tier", 1)) >= tier:
			continue
		if bool(other.get("optional", false)):
			continue
		if int(levels.get(str(other["id"]), 0)) < int(other["max"]):
			return false
	return true


func _required_ids(item: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	var raw: Variant = item.get("requires", "")
	if raw is Array:
		for value in raw:
			var req_id: String = str(value)
			if not req_id.is_empty():
				ids.append(req_id)
	else:
		var req_id: String = str(raw)
		if not req_id.is_empty():
			ids.append(req_id)
	return ids


func requirements_met(id: String) -> bool:
	var item: Dictionary = _item(id)
	if item.is_empty():
		return false
	var need: int = int(item.get("require_level", 1))
	for req_id in _required_ids(item):
		if int(levels.get(req_id, 0)) < need:
			return false
	return true


func lock_reason(id: String) -> String:
	var item: Dictionary = _item(id)
	if item.is_empty():
		return ""
	if not requirements_met(id):
		var need: int = int(item.get("require_level", 1))
		for req_id in _required_ids(item):
			if int(levels.get(req_id, 0)) >= need:
				continue
			var req: Dictionary = _item(req_id)
			var req_name: String = str(req.get("unlock_name", req.get("name", "that upgrade")))
			return "Buy %s first." % req_name
		return "Locked"
	if tier_unlocked(id):
		return ""
	var needed: int = int(item.get("tier", 2)) - 1
	var roman: PackedStringArray = ["", "I", "II", "III", "IV"]
	var mark: String = roman[needed] if needed >= 0 and needed < roman.size() else str(needed)
	return "Max %s %s first." % [str(item.get("cat", "tier")), mark]


func can_buy(id: String) -> bool:
	var item: Dictionary = _item(id)
	if item.is_empty():
		return false
	if not requirements_met(id):
		return false
	if not tier_unlocked(id):
		return false
	var level: int = int(levels.get(id, 0))
	if level >= int(item["max"]):
		return false
	return money >= cost_of(id)


func cost_of(id: String) -> int:
	var item := _item(id)
	var level: int = int(levels.get(id, 0))
	return int(round(float(item["cost"]) * pow(float(item["scale"]), float(level))))


func buy(id: String) -> bool:
	if not can_buy(id):
		return false
	last_unlock_title = ""
	last_unlocked_ids.clear()
	var tier_locked: Array[String] = []
	var req_locked: Array[String] = []
	for entry in catalog:
		var other_id: String = str(entry["id"])
		if not tier_unlocked(other_id):
			tier_locked.append(other_id)
		elif not requirements_met(other_id):
			req_locked.append(other_id)
	add_money(-cost_of(id))
	levels[id] = int(levels.get(id, 0)) + 1
	_queue_notice(id)
	apply_upgrades()
	for other_id in tier_locked:
		if not tier_unlocked(other_id):
			continue
		last_unlocked_ids.append(other_id)
		if last_unlock_title.is_empty():
			var other: Dictionary = _item(other_id)
			last_unlock_title = tier_title(str(other.get("cat", "")), int(other.get("tier", 2)))
	for other_id in req_locked:
		if not requirements_met(other_id) or not tier_unlocked(other_id):
			continue
		if not last_unlocked_ids.has(other_id):
			last_unlocked_ids.append(other_id)
	upgrades_changed.emit()
	Sfx.play("buy")
	return true


func consume_pending_notices() -> Array:
	var notices: Array = pending_notices.duplicate(true)
	pending_notices.clear()
	return notices


func tool_for_upgrade(id: String) -> int:
	if id.begins_with("hands"):
		return Tuning.TOOL_HANDS
	if id.begins_with("shovel"):
		return Tuning.TOOL_SHOVEL
	if id.begins_with("pick"):
		return Tuning.TOOL_PICKAXE
	if id.begins_with("brush"):
		return Tuning.TOOL_BRUSH
	return -1


func owns_tool(tool: int) -> bool:
	match tool:
		Tuning.TOOL_PICKAXE:
			return int(levels.get("pick_click", 0)) > 0
		Tuning.TOOL_BRUSH:
			return int(levels.get("brush_speed", 0)) > 0
		Tuning.TOOL_SHOVEL:
			return int(levels.get("shovel_click", 0)) > 0
		Tuning.TOOL_HANDS:
			return true
		_:
			return false


func owned_tool_ids() -> Array[int]:
	var tools: Array[int] = [Tuning.TOOL_HANDS]
	if owns_tool(Tuning.TOOL_SHOVEL):
		tools.append(Tuning.TOOL_SHOVEL)
	if owns_tool(Tuning.TOOL_PICKAXE):
		tools.append(Tuning.TOOL_PICKAXE)
	if owns_tool(Tuning.TOOL_BRUSH):
		tools.append(Tuning.TOOL_BRUSH)
	return tools


func toolbar_entries() -> Array:
	var rows: Array = []
	for tool in owned_tool_ids():
		rows.append({"id": tool, "hotkey": Tuning.hotkey_for_tool(tool)})
	return rows


func hold_unlocked() -> bool:
	return int(levels.get("hands_hold", 0)) > 0 or int(levels.get("shovel_hold", 0)) > 0 or int(levels.get("pick_hold", 0)) > 0


func big_finds_unlocked() -> bool:
	return int(levels.get("rich_bed", 0)) > 0


func is_unlock_offer(id: String) -> bool:
	var item: Dictionary = _item(id)
	if item.is_empty() or not item.has("unlock_name"):
		return false
	return int(levels.get(id, 0)) <= 0


func shop_display_name(id: String) -> String:
	if id == "spotlight":
		return spotlight_shop_name()
	var item: Dictionary = _item(id)
	if is_unlock_offer(id):
		return str(item["unlock_name"])
	return str(item.get("name", id))


func shop_item_desc(id: String) -> String:
	if id == "spotlight":
		return spotlight_shop_desc()
	var item: Dictionary = _item(id)
	if is_unlock_offer(id) and item.has("unlock_desc"):
		return str(item["unlock_desc"])
	return str(item.get("desc", ""))


func shop_effect_line(id: String) -> String:
	var item: Dictionary = _item(id)
	if item.is_empty():
		return ""
	var current: int = int(levels.get(id, 0))
	var max_level: int = int(item.get("max", 1))
	var line: String = _shop_effect_at(id, current) if current >= max_level else _shop_effect_delta(id, current, current + 1)
	if line.is_empty():
		return _shop_effect_fallback(id)
	return line


func _shop_effect_fallback(id: String) -> String:
	var raw: String = shop_item_desc(id).strip_edges()
	if raw.ends_with("."):
		return raw.substr(0, raw.length() - 1)
	return raw


func _shop_effect_at(id: String, level: int) -> String:
	var zero: Dictionary = _tuning_at(id, 0)
	var at: Dictionary = _tuning_at(id, level)
	return _format_shop_effect(id, zero, at)


func _shop_effect_delta(id: String, from_level: int, to_level: int) -> String:
	var before: Dictionary = _tuning_at(id, from_level)
	var after: Dictionary = _tuning_at(id, to_level)
	return _format_shop_effect(id, before, after)


func _tuning_at(id: String, level: int) -> Dictionary:
	var saved: int = int(levels.get(id, 0))
	levels[id] = level
	apply_upgrades()
	var snap: Dictionary = _tuning_snapshot()
	levels[id] = saved
	apply_upgrades()
	return snap


func _tuning_snapshot() -> Dictionary:
	return {
		"hands_click_mult": Tuning.hands_click_mult,
		"shovel_click_mult": Tuning.shovel_click_mult,
		"shovel_hold_tick_rate": Tuning.shovel_hold_tick_rate,
		"shovel_radius": Tuning.shovel_radius,
		"pickaxe_radius": Tuning.pickaxe_radius,
		"pickaxe_click_mult": Tuning.pickaxe_click_mult,
		"pickaxe_hold_tick_rate": Tuning.pickaxe_hold_tick_rate,
		"brush_clean_per_pixel": Tuning.brush_clean_per_pixel,
		"round_seconds": Tuning.round_seconds,
		"museum_income_mult": Tuning.museum_income_mult,
		"money_mult": Tuning.money_mult,
		"dirt_money_bonus": Tuning.dirt_money_bonus,
		"rock_money_bonus": Tuning.rock_money_bonus,
		"fossil_value_mult": Tuning.fossil_value_mult,
		"exhibit_flat_income": Tuning.exhibit_flat_income,
		"donation": Tuning.donation_base * Tuning.donation_mult + Tuning.donation_flat,
		"visitor_flat": Tuning.visitor_flat,
		"visitor_mult": Tuning.visitor_mult,
		"crumble_slow": Tuning.crumble_slow,
		"plaster_bonus": Tuning.plaster_bonus,
		"site_size_rank": Tuning.site_size_rank,
		"extra_find_slots": Tuning.extra_find_slots,
		"extra_find_chance": Tuning.extra_find_chance,
		"big_finds_unlocked": Tuning.big_finds_unlocked,
		"integrity_hit_cost": Tuning.integrity_hit_cost,
		"unveil_spike_seconds": Tuning.unveil_spike_seconds,
		"unveil_rush_strength": Tuning.unveil_rush_strength,
		"spotlight_mult": Tuning.spotlight_mult,
		"matrix_hands_quality": Tuning.matrix_hands_quality,
		"matrix_hands_pay": Tuning.matrix_hands_pay,
		"matrix_dirt_chance": Tuning.matrix_dirt_chance,
		"matrix_stone_chance": Tuning.matrix_stone_chance,
		"hands_sense_radius": Tuning.hands_sense_radius,
		"condition_luck": Tuning.condition_luck,
		"cast_rank": Tuning.cast_rank,
		"workshop": int(_lv("workshop")),
	}


func _format_shop_effect(id: String, zero: Dictionary, at: Dictionary) -> String:
	match id:
		"hands_click":
			return _pct_over_line("+%d%% click harvest", float(zero["hands_click_mult"]), float(at["hands_click_mult"]))
		"hands_hold", "hands_swift", "shovel_hold":
			return _pct_faster_line("Hold digs %d%% faster", float(zero["shovel_hold_tick_rate"]), float(at["shovel_hold_tick_rate"]))
		"hands_consolidant", "hands_resin":
			return "Quick plaster +%d★ (was +%d★)" % [int(at["plaster_bonus"]), int(zero["plaster_bonus"])]
		"hands_burlap":
			return _pct_delta_line("+%d%% time before a bone crumbles", float(zero["crumble_slow"]), float(at["crumble_slow"]))
		"hands_cast":
			var before: int = int(zero["cast_rank"])
			var after: int = int(at["cast_rank"])
			if before <= 0:
				return "Wrap a bone in %.1fs" % Tuning.cast_hold_by_rank[clampi(after, 1, 3) - 1]
			return "Wrap time %.1fs → %.1fs" % [Tuning.cast_hold_by_rank[clampi(before, 1, 3) - 1], Tuning.cast_hold_by_rank[clampi(after, 1, 3) - 1]]
		"hands_sense":
			var reach: float = float(at["hands_sense_radius"])
			if float(zero["hands_sense_radius"]) <= 0.0 and reach > 0.0:
				return "Feel bone %.1f cells away" % reach
			return "Feel bone %.1f → %.1f cells away" % [float(zero["hands_sense_radius"]), reach]
		"hands_craft":
			return _join_effects(PackedStringArray([
				"+%d%% harvest quality" % int(round((float(at["matrix_hands_quality"]) - float(zero["matrix_hands_quality"])) * 100.0)),
				_pct_over_line("+%d%% harvest pay", float(zero["matrix_hands_pay"]), float(at["matrix_hands_pay"])),
			]))
		"shovel_click":
			if is_equal_approx(float(zero["shovel_click_mult"]), float(at["shovel_click_mult"])):
				return "Unlocks the shovel"
			return _pct_over_line("+%d%% shovel clicks", float(zero["shovel_click_mult"]), float(at["shovel_click_mult"]))
		"shovel_radius":
			return _radius_delta_line(zero, at, "shovel_radius")
		"pick_radius":
			return _radius_delta_line(zero, at, "pickaxe_radius")
		"shovel_super", "shovel_titan":
			return _join_effects(PackedStringArray([
				_pct_over_line("+%d%% shovel clicks", float(zero["shovel_click_mult"]), float(at["shovel_click_mult"])),
				_pct_faster_line("Hold digs %d%% faster", float(zero["shovel_hold_tick_rate"]), float(at["shovel_hold_tick_rate"])),
				_radius_delta_line(zero, at, "shovel_radius"),
			]))
		"shovel_soft", "pick_soft":
			return _condition_odds_line(float(zero["condition_luck"]), float(at["condition_luck"]))
		"pick_click":
			if is_equal_approx(float(zero["pickaxe_click_mult"]), float(at["pickaxe_click_mult"])):
				return "Unlocks the pickaxe"
			return _pct_over_line("+%d%% pick clicks", float(zero["pickaxe_click_mult"]), float(at["pickaxe_click_mult"]))
		"pick_hold":
			return _pct_faster_line("Hold digs %d%% faster", float(zero["pickaxe_hold_tick_rate"]), float(at["pickaxe_hold_tick_rate"]))
		"pick_super", "pick_titan":
			return _join_effects(PackedStringArray([
				_pct_over_line("+%d%% pick clicks", float(zero["pickaxe_click_mult"]), float(at["pickaxe_click_mult"])),
				_pct_faster_line("Hold digs %d%% faster", float(zero["pickaxe_hold_tick_rate"]), float(at["pickaxe_hold_tick_rate"])),
				_radius_delta_line(zero, at, "pickaxe_radius"),
			]))
		"brush_speed":
			if is_equal_approx(float(zero["brush_clean_per_pixel"]), float(at["brush_clean_per_pixel"])):
				return "Unlocks the brush"
			return _pct_over_line("+%d%% brush speed", float(zero["brush_clean_per_pixel"]), float(at["brush_clean_per_pixel"]))
		"brush_master":
			return _pct_over_line("+%d%% brush speed", float(zero["brush_clean_per_pixel"]), float(at["brush_clean_per_pixel"]))
		"round_time", "round_marathon":
			return "+%ds per shift" % int(round(float(at["round_seconds"]) - float(zero["round_seconds"])))
		"dirt_pay":
			return "+$%.2f matrix finds" % (float(at["dirt_money_bonus"]) - float(zero["dirt_money_bonus"]))
		"site_size", "site_expand":
			var layout: Vector2i = Tuning.site_layout_for_rank(int(at["site_size_rank"]))
			return "Pit %d×%d" % [layout.x, layout.y]
		"scrap_bed", "prime_bed":
			return _extra_fossil_line(float(at["extra_find_chance"]), float(zero["extra_find_chance"]))
		"rich_bed":
			var extra: String = _extra_fossil_line(float(at["extra_find_chance"]), float(zero["extra_find_chance"]))
			if bool(at["big_finds_unlocked"]) and not bool(zero["big_finds_unlocked"]):
				return "Unlocks large bones · %s" % extra if not extra.is_empty() else "Unlocks large bones"
			return extra
		"rock_pay":
			return "+$%.1f stone finds" % (float(at["rock_money_bonus"]) - float(zero["rock_money_bonus"]))
		"money_mult":
			return _pct_delta_line("+%d%% dig value", float(zero["money_mult"]), float(at["money_mult"]))
		"fossil_value":
			return _pct_delta_line("+%d%% fossil sale", float(zero["fossil_value_mult"]), float(at["fossil_value_mult"]))
		"lighting", "labels", "gift_shop", "benches", "blockbuster_ticket":
			return _ticket_this_buy_line(float(at["donation"]) - float(zero["donation"]))
		"spotlight", "blockbuster_feature":
			return "Featured exhibit %dx" % int(round(float(at["spotlight_mult"])))
		"glass_case", "crowds":
			return _visitor_this_buy_line(int(at["visitor_flat"]) - int(zero["visitor_flat"]))
		"blockbuster_crowd":
			var gain: float = float(at["visitor_mult"]) - float(zero["visitor_mult"])
			var extra: int = int(round(float(museum_visitors_base()) / maxf(Tuning.visitor_mult, 0.01) * (float(at["visitor_mult"]) - float(zero["visitor_mult"]))))
			var pct: String = "+%d%% visitors" % int(round(gain * 100.0))
			var cash: float = _cents_money(float(extra) * museum_donation())
			if cash < 0.01:
				return pct
			return _join_effects(PackedStringArray(["+$%.2f / sec" % cash, pct]))
		"unveil_time", "blockbuster_hours":
			return "Crowd surge on unveil +%ds" % int(round(float(at["unveil_spike_seconds"]) - float(zero["unveil_spike_seconds"])))
		"unveil_crowd":
			return _pct_delta_line("+%d%% visitors on unveil", float(zero["unveil_rush_strength"]), float(at["unveil_rush_strength"]))
		"workshop":
			var secs: int = prep_cart_seconds(int(at["workshop"]))
			if secs <= 0:
				return "No cart yet"
			return "Cleans one dirt level per %ds" % secs
		_:
			return ""


func _pct_faster_line(template: String, before: float, after: float) -> String:
	if after <= before + 0.0001:
		return ""
	var pct: int = int(round((after / maxf(before, 0.01) - 1.0) * 100.0))
	return template % pct


func _pct_over_line(template: String, before: float, after: float) -> String:
	if after <= before + 0.0000001:
		return ""
	var pct: int = int(round((after / maxf(before, 0.000001) - 1.0) * 100.0))
	return template % pct


func _pct_delta_line(template: String, before: float, after: float) -> String:
	var delta: float = after - before
	if absf(delta) < 0.0001:
		return ""
	return template % int(round(delta * 100.0))


func _condition_odds_line(before: float, after: float) -> String:
	var a: int = int(round(Tuning.great_or_better_chance(before) * 100.0))
	var b: int = int(round(Tuning.great_or_better_chance(after) * 100.0))
	return "Great or Perfect bones: %d%% → %d%%" % [a, b]


func _integrity_line(before: float, after: float) -> String:
	if after >= before - 0.0001:
		return ""
	var pct: int = int(round((before - after) / maxf(before, 0.01) * 100.0))
	return "Hits cost %d%% less integrity" % pct


func _extra_fossil_line(chance: float, before: float = 0.0) -> String:
	if chance <= 0.0 or absf(chance - before) < 0.001:
		return ""
	if before > 0.0:
		return "Extra fossil odds %d%% → %d%%" % [int(round(before * 100.0)), int(round(chance * 100.0))]
	return "Extra fossil odds %d%%" % int(round(chance * 100.0))


func _radius_delta_line(zero: Dictionary, at: Dictionary, key: String = "shovel_radius") -> String:
	var delta: float = float(at.get(key, 0.0)) - float(zero.get(key, 0.0))
	if delta <= 0.001:
		return ""
	return "+%.1f cell radius" % delta


func _cents_money(amount: float) -> float:
	return float(int(round(amount * 100.0))) / 100.0


func _ticket_this_buy_line(delta: float) -> String:
	var per: float = _cents_money(delta)
	var per_bit: String = "+$%.2f per visitor" % per
	var visitors: int = museum_visitors()
	if visitors <= 0:
		return per_bit
	return _join_effects(PackedStringArray([
		"+$%.2f / sec" % _cents_money(float(visitors) * per),
		per_bit,
	]))


func _visitor_this_buy_line(extra: int) -> String:
	var people: String = "+%d visitors" % extra
	var visitors: int = museum_visitors()
	if visitors <= 0:
		return people
	return _join_effects(PackedStringArray([
		"+$%.2f / sec" % _cents_money(float(extra) * museum_donation()),
		people,
	]))


func _donation_rank_cents(id: String, ranks: int) -> int:
	var curve: Array[int] = []
	match id:
		"lighting", "benches":
			curve = [1, 1, 1, 1, 1]
		"labels":
			curve = [1, 2, 3, 4, 5, 5]
		"gift_shop":
			curve = [2, 2, 3, 4, 5, 10]
		"blockbuster_ticket":
			curve = [10, 12, 15, 18, 22, 25]
		_:
			return 0
	var total: int = 0
	var n: int = mini(maxi(ranks, 0), curve.size())
	for i in n:
		total += int(curve[i])
	return total


func _join_effects(parts: PackedStringArray, limit: int = 2) -> String:
	var kept: PackedStringArray = PackedStringArray()
	for part in parts:
		if part.is_empty():
			continue
		kept.append(part)
		if kept.size() >= limit:
			break
	return " · ".join(kept)


func spotlight_shop_name() -> String:
	var rank: int = int(levels.get("spotlight", 0))
	if rank <= 0:
		return "Unlock Spotlight"
	return "Featured exhibit %dx" % (rank + 1)


func spotlight_shop_desc() -> String:
	var rank: int = int(levels.get("spotlight", 0))
	if rank <= 0:
		return "Featured exhibit 2x."
	if rank >= 3:
		return "The featured stand pays 4x."
	return "Featured exhibit %dx." % (rank + 2)


func shop_row_title(id: String) -> String:
	var item: Dictionary = _item(id)
	if is_unlock_offer(id):
		return shop_display_name(id)
	var level: int = int(levels.get(id, 0))
	var max_level: int = int(item.get("max", 1))
	return "%s    %d / %d" % [shop_display_name(id), level, max_level]


## Live "tool power" numbers for the shop tab header. Plain labels, real values.
func shop_hero_stats(cat: String) -> Array:
	var out: Array = []
	var add := func(label: String, value: String) -> void: out.append({"label": label, "value": value})
	match cat:
		"Hands":
			add.call("Harvest power", "%d%%" % int(round(Tuning.hands_click_mult * 100.0)))
			add.call("Hold speed", ("%.1f/s" % Tuning.shovel_hold_tick_rate) if _lv("hands_hold") > 0.0 else "Locked")
			add.call("Bone sense", ("%.1f cells" % Tuning.hands_sense_radius) if Tuning.hands_sense_radius > 0.0 else "Locked")
			add.call("Plaster", ("+%d★ · %.1fs" % [Tuning.plaster_bonus, Tuning.cast_hold_seconds()]) if Tuning.cast_owned() else "Locked")
			if _lv("hands_burlap") > 0.0:
				add.call("Crumble time", "x%.2f" % Tuning.crumble_slow)
		"Shovel":
			if not owns_tool(Tuning.TOOL_SHOVEL):
				add.call("Shovel", "Locked")
			else:
				add.call("Dig power", "%d%%" % int(round(Tuning.shovel_click_mult * 100.0)))
				add.call("Reach", "%d cells" % Tuning.shovel_hit_cells(Vector2i(8, 8), Tuning.shovel_radius).size())
				add.call("Hold speed", ("%.1f/s" % Tuning.shovel_hold_tick_rate) if _lv("shovel_hold") > 0.0 else "Locked")
				add.call("Great+ bones", "%d%%" % int(round(Tuning.great_or_better_chance() * 100.0)))
		"Pickaxe":
			if not owns_tool(Tuning.TOOL_PICKAXE):
				add.call("Pickaxe", "Locked")
			else:
				add.call("Strike power", "%d%%" % int(round(Tuning.pickaxe_click_mult * 100.0)))
				add.call("Reach", "%d cells" % Tuning.shovel_hit_cells(Vector2i(8, 8), Tuning.pickaxe_radius).size())
				add.call("Hold speed", ("%.1f/s" % Tuning.pickaxe_hold_tick_rate) if _lv("pick_hold") > 0.0 else "Locked")
				add.call("Great+ bones", "%d%%" % int(round(Tuning.great_or_better_chance() * 100.0)))
		"Brush":
			if not owns_tool(Tuning.TOOL_BRUSH):
				add.call("Brush", "Locked")
			else:
				var per_pass: float = clampf(Tuning.brush_clean_per_pixel * (Tuning.brush_base_strength / 0.0015), 0.25, Tuning.brush_max_strength)
				add.call("Dirt per sweep", "%.1f layers" % per_pass)
				add.call("Extra width", "+%dpx" % int(round(Tuning.brush_reach_px)))
				add.call("Clean bonus", "x%.1f" % (1.0 / maxf(Tuning.unbrushed_value, 0.01)))
		"Site":
			var layout: Vector2i = Tuning.site_layout_for_rank(Tuning.site_size_rank)
			add.call("Shift", "%ds" % int(round(Tuning.round_seconds)))
			add.call("Pit size", "%dx%d" % [layout.x, layout.y])
			add.call("Extra fossil odds", "%d%%" % int(round(Tuning.extra_find_chance * 100.0)))
			add.call("Finds pay", "x%.2f" % Tuning.money_mult)
		"Museum":
			add.call("Income", UiStyle.money_text(museum_income()) + "/s")
			add.call("Visitors", str(museum_visitors()))
			add.call("Museum fame", "x%.1f" % fame_mult())
			add.call("Cleaning cart", "%ds / level" % prep_cart_seconds(int(_lv("workshop"))) if _lv("workshop") > 0.0 else "none")
	return out


func shop_button_label(id: String) -> String:
	var item: Dictionary = _item(id)
	var price: String = UiStyle.money_text(cost_of(id))
	if is_unlock_offer(id):
		var action: String = str(item.get("unlock_action", "Buy"))
		if action == "Unlock":
			return "Unlock  %s" % price
		return "Buy %s  %s" % [str(item["unlock_name"]), price]
	return "Buy  %s" % price


func shop_row_heat(id: String) -> String:
	var item: Dictionary = _item(id)
	if item.is_empty():
		return "locked"
	if not requirements_met(id) or not tier_unlocked(id):
		return "locked"
	if int(levels.get(id, 0)) >= int(item["max"]):
		return "maxed"
	if can_buy(id):
		return "glow"
	return "dim"


func museum_rate_line() -> String:
	var rate: float = museum_income()
	if rate < 0.005:
		return ""
	return "$%.2f/s" % rate


func small_finds_count() -> int:
	var count: int = 0
	for piece_id in pieces:
		if stand_for_piece(str(piece_id)) == STAND_SMALL_FINDS:
			count += 1
	return count


func tool_display_name(tool: int) -> String:
	match tool:
		Tuning.TOOL_HANDS:
			return "Hands"
		Tuning.TOOL_SHOVEL:
			return "Shovel"
		Tuning.TOOL_PICKAXE:
			return "Pickaxe"
		Tuning.TOOL_BRUSH:
			return "Brush"
		_:
			return "Tool"


func tool_role_line(tool: int) -> String:
	match tool:
		Tuning.TOOL_HANDS:
			return "Pick up small finds"
		Tuning.TOOL_SHOVEL:
			return "Clear dirt fast"
		Tuning.TOOL_PICKAXE:
			return "Break clay and stone"
		Tuning.TOOL_BRUSH:
			return "Wipe dirt off bones"
		_:
			return ""


func next_upgrade_action(tool: int) -> String:
	match tool:
		Tuning.TOOL_HANDS:
			return "Next hands upgrade"
		Tuning.TOOL_SHOVEL:
			return "Next shovel upgrade"
		Tuning.TOOL_PICKAXE:
			return "Next pick upgrade"
		Tuning.TOOL_BRUSH:
			return "Next brush upgrade"
		_:
			return "Next upgrade"


func next_shop_id(tool: int = -1) -> String:
	var filter_tool: int = tool if tool >= 0 else Tuning.TOOL_HANDS
	var cheapest: String = ""
	var cheapest_cost: int = 1 << 30
	var locked_next: String = ""
	for item in catalog:
		var id: String = str(item["id"])
		if tool_for_upgrade(id) != filter_tool:
			continue
		if int(levels.get(id, 0)) >= int(item["max"]):
			continue
		if requirements_met(id) and tier_unlocked(id):
			var cost: int = cost_of(id)
			if cost < cheapest_cost:
				cheapest_cost = cost
				cheapest = id
		elif locked_next.is_empty():
			locked_next = id
	if not cheapest.is_empty():
		return cheapest
	return locked_next


func next_goal_maxed_lines(tool: int) -> PackedStringArray:
	return PackedStringArray(["Next upgrade", "%s maxed" % tool_display_name(tool)])


func next_goal(tool: int = -1) -> Dictionary:
	var shop: Dictionary = _shop_goal(next_shop_id(tool))
	var stand: Dictionary = _stand_goal()
	if shop.is_empty():
		return stand
	if bool(shop.get("affordable", false)):
		return shop
	if not stand.is_empty() and float(stand.get("progress", 0.0)) > float(shop.get("progress", 0.0)):
		return stand
	return shop


func try_buy_next_goal(tool: int = -1) -> bool:
	var goal: Dictionary = next_goal(tool)
	if str(goal.get("kind", "")) != "shop":
		return false
	var id: String = str(goal.get("id", ""))
	if id.is_empty() or not can_buy(id):
		return false
	return buy(id)


func next_goal_label(id: String) -> String:
	var tool: int = tool_for_upgrade(id)
	if tool < 0:
		return shop_display_name(id)
	return "%s · %s" % [tool_display_name(tool), shop_display_name(id)]


func next_goal_rank_name(id: String) -> String:
	var item: Dictionary = _item(id)
	var rank: String = str(item.get("name", ""))
	if rank.is_empty():
		return shop_display_name(id)
	return rank


func next_goal_chip_lines(id: String, cost: int) -> PackedStringArray:
	var lines := PackedStringArray(["Next upgrade"])
	var effect: String = shop_effect_line(id)
	if effect.is_empty():
		effect = next_goal_rank_name(id)
	for raw in effect.split(" · "):
		var bit: String = str(raw).strip_edges()
		if bit.is_empty():
			continue
		if bit.begins_with("Hold digs "):
			bit = bit.replace("Hold digs ", "Hold-dig ")
		lines.append(bit)
	if lines.size() == 1:
		lines.append(effect)
	lines.append("$%d" % cost)
	return lines


func next_goal_chip_text(id: String, cost: int) -> String:
	var effect: String = shop_effect_line(id)
	if effect.is_empty():
		effect = next_goal_rank_name(id)
	return " · ".join(PackedStringArray(["Next upgrade", effect, "$%d" % cost]))


func _shop_goal(id: String) -> Dictionary:
	if id.is_empty():
		return {}
	var cost: int = cost_of(id)
	var affordable: bool = can_buy(id)
	var progress: float = 1.0 if affordable else clampf(float(money) / float(maxi(cost, 1)), 0.0, 0.999)
	return {
		"kind": "shop",
		"id": id,
		"title": "%s $%d" % [next_goal_label(id), cost],
		"current": float(money),
		"target": float(cost),
		"progress": progress,
		"affordable": affordable,
	}


func _stand_goal() -> Dictionary:
	var have: int = small_finds_count()
	if have <= 0 or have >= 2:
		return {}
	return {
		"kind": "stand",
		"id": STAND_SMALL_FINDS,
		"title": "Small Finds %d/2" % have,
		"current": float(have),
		"target": 2.0,
		"progress": float(have) / 2.0,
		"affordable": false,
	}


func is_site_upgrade(id: String) -> bool:
	return id == "round_time" or id == "dirt_pay" or id == "site_size" or id == "scrap_bed" or id == "rich_bed" or id == "site_expand" or id == "rock_pay" or id == "money_mult" or id == "fossil_value" or id == "round_marathon" or id == "prime_bed"


func upgrade_feel_line(id: String) -> String:
	match id:
		"hands_click":
			return "Richer harvest"
		"hands_hold":
			return "Hold to keep digging"
		"hands_craft":
			return "Richer harvest"
		"hands_swift":
			return "Faster hands"
		"shovel_click":
			return "Heavier swings" if int(levels.get("shovel_click", 0)) > 1 else "You have a shovel"
		"shovel_hold":
			return "Faster shoveling"
		"shovel_radius":
			return "Wider scoop"
		"pick_radius":
			return "Wider scoop"
		"shovel_super":
			return "Super Shovel"
		"shovel_titan":
			return "Titan Shovel"
		"shovel_soft":
			return "Softer on bone"
		"pick_click":
			return "Harder strikes" if int(levels.get("pick_click", 0)) > 1 else "You have a pickaxe"
		"pick_hold":
			return "Faster picking"
		"pick_super":
			return "Super Pick"
		"pick_titan":
			return "Titan Pick"
		"pick_soft":
			return "Kinder to bone"
		"brush_speed":
			return "Faster dusting" if int(levels.get("brush_speed", 0)) > 1 else "You have a brush"
		"brush_master":
			return "Master Brush"
		"round_time":
			return "Clock starts fuller"
		"round_marathon":
			return "Clock starts fuller"
		"prime_bed":
			return "More fossils in the pit"
		"dirt_pay":
			return "Richer matrix"
		"site_size":
			return "The pit is bigger"
		"scrap_bed":
			return "More fossils in the pit"
		"rich_bed":
			return "Large bones can appear"
		"site_expand":
			return "The pit is bigger"
		"rock_pay":
			return "Richer nodules"
		"money_mult":
			return "Everything is worth more"
		"fossil_value":
			return "Fossils sell for more"
		"blockbuster_ticket":
			return "Tickets pay more"
		"blockbuster_crowd":
			return "More visitors"
		"blockbuster_hours":
			return "Unveils last longer"
		"blockbuster_feature":
			return "Featured stand pays more"
		_:
			var item: Dictionary = _item(id)
			return str(item.get("name", id))


func notice_label(notice: Dictionary) -> String:
	var line: String = upgrade_feel_line(str(notice.get("id", "")))
	var delta: int = int(notice.get("delta", 1))
	if delta > 1:
		return "%s  +%d" % [line, delta]
	return line


func tier_title(cat: String, tier: int) -> String:
	var roman: PackedStringArray = ["", "I", "II", "III", "IV"]
	var mark: String = roman[tier] if tier >= 0 and tier < roman.size() else str(tier)
	var names := {
		"Hands:2": "Fieldcraft",
		"Shovel:3": "Titan Shovel",
		"Pickaxe:3": "Titan Pick",
		"Site:3": "Grand Claim",
		"Museum:4": "Blockbuster",
	}
	var extra: String = str(names.get("%s:%d" % [cat, tier], ""))
	if extra.is_empty():
		return "%s %s" % [cat, mark]
	return "%s %s — %s" % [cat, mark, extra]


func _queue_notice(id: String) -> void:
	var item: Dictionary = _item(id)
	for notice in pending_notices:
		if str(notice.get("id", "")) != id:
			continue
		notice["delta"] = int(notice.get("delta", 0)) + 1
		return
	pending_notices.append({
		"id": id,
		"name": str(item.get("name", id)),
		"delta": 1,
		"cat": str(item.get("cat", "")),
	})


func apply_upgrades() -> void:
	var shovel_ranks: float = maxf(0.0, _lv("shovel_click") - 1.0)
	var pick_ranks: float = maxf(0.0, _lv("pick_click") - 1.0)
	var brush_ranks: float = maxf(0.0, _lv("brush_speed") - 1.0)
	Tuning.hands_click_mult = float(_bases["hands_click_mult"]) + 0.07 * _lv("hands_click")
	Tuning.matrix_hands_quality = 0.10 * _lv("hands_click") + 0.045 * _lv("dirt_pay") + 0.08 * _lv("hands_craft")
	Tuning.matrix_hands_pay = 1.0 + 0.12 * _lv("hands_click") + 0.06 * _lv("dirt_pay") + 0.10 * _lv("hands_craft")
	Tuning.matrix_clear_pay = 0.50
	## Click ranks hit much harder than hold ranks speed up, and half of the
	## click bonus carries into held digging, so they help every play style.
	Tuning.shovel_click_mult = float(_bases["shovel_click_mult"]) + 0.40 * shovel_ranks + 0.32 * _lv("shovel_super") + 0.32 * _lv("shovel_titan")
	Tuning.shovel_hold_mult = 1.0 + 0.5 * 0.40 * shovel_ranks
	Tuning.shovel_hold_tick_rate = float(_bases["shovel_hold_tick_rate"]) + 0.55 * _lv("hands_hold") + 0.55 * _lv("hands_swift") + 0.85 * _lv("shovel_hold") + 0.70 * _lv("shovel_super") + 0.70 * _lv("shovel_titan")
	# Unlock is one cell of reach (a plus). Rank 2 is a 3-wide scoop.
	# Old 0.40/rank stayed under 1.0 through rank 2, so neighbors were skipped.
	var scoop: float = _lv("shovel_radius")
	Tuning.shovel_radius = 0.0 if scoop <= 0.0 else (0.5 + 0.5 * scoop + 0.5 * _lv("shovel_super") + 0.5 * _lv("shovel_titan"))
	Tuning.pickaxe_click_mult = float(_bases["pickaxe_click_mult"]) + 0.30 * pick_ranks + 0.32 * _lv("pick_super") + 0.32 * _lv("pick_titan")
	Tuning.pickaxe_hold_mult = 1.0 + 0.5 * 0.30 * pick_ranks
	Tuning.pickaxe_hold_tick_rate = float(_bases["pickaxe_hold_tick_rate"]) + 0.70 * _lv("pick_hold") + 0.55 * _lv("pick_super") + 0.55 * _lv("pick_titan")
	Tuning.pickaxe_radius = 1.0 + 0.35 * _lv("pick_radius") + 0.35 * _lv("pick_super") + 0.35 * _lv("pick_titan")
	Tuning.brush_clean_per_pixel = float(_bases["brush_clean_per_pixel"]) + 0.00055 * brush_ranks + 0.0007 * _lv("brush_master")
	Tuning.brush_reach_px = 5.0 * brush_ranks + 7.0 * _lv("brush_master")
	Tuning.cast_rank = int(_lv("hands_cast"))
	Tuning.plaster_bonus = 1 + int(_lv("hands_consolidant")) + int(_lv("hands_resin"))
	Tuning.crumble_slow = 1.0 + 0.35 * _lv("hands_burlap")
	var sense: float = _lv("hands_sense")
	Tuning.hands_sense_radius = 0.0 if sense <= 0.0 else 0.75 + 0.5 * sense + 0.45 * _lv("hands_craft")
	Tuning.round_seconds = float(_bases["round_seconds"]) + 6.0 * _lv("round_time") + 8.0 * _lv("round_marathon")
	Tuning.museum_income_mult = 1.0
	var ticket_cents: int = _donation_rank_cents("lighting", int(_lv("lighting")))
	ticket_cents += _donation_rank_cents("labels", int(_lv("labels")))
	ticket_cents += _donation_rank_cents("gift_shop", int(_lv("gift_shop")))
	ticket_cents += _donation_rank_cents("blockbuster_ticket", int(_lv("blockbuster_ticket")))
	Tuning.donation_mult = 1.0 + float(ticket_cents) / (Tuning.donation_base * 100.0)
	Tuning.donation_flat = float(_donation_rank_cents("benches", int(_lv("benches")))) / 100.0
	Tuning.visitor_flat = int(3 * _lv("glass_case") + 8 * _lv("crowds"))
	## Late-game crowds scale with the museum (a flat +8 was a rounding error
	## next to Box Office by the time you can afford it).
	Tuning.visitor_mult = 1.0 + 0.20 * _lv("blockbuster_crowd")
	Tuning.precision_damage_bonus = 0.0
	Tuning.money_mult = float(_bases["money_mult"]) + 0.06 * _lv("money_mult")
	Tuning.dirt_money_bonus = 0.35 * _lv("dirt_pay")
	Tuning.rock_money_bonus = 1.1 * _lv("rock_pay")
	Tuning.matrix_dirt_chance = float(_bases["matrix_dirt_chance"]) + 0.012 * _lv("dirt_pay")
	Tuning.matrix_stone_chance = float(_bases["matrix_stone_chance"]) + 0.055 * _lv("rock_pay")
	Tuning.fossil_value_mult = 1.0 + 0.08 * _lv("fossil_value")
	Tuning.exhibit_flat_income = 0.0
	Tuning.site_size_rank = int(_lv("site_size") + _lv("site_expand"))
	## Extra fossils are a chain of chances, not a fixed count: each one that
	## shows up rolls for another, so you never know when the pit is empty.
	var beds: float = _lv("scrap_bed") + _lv("rich_bed") + _lv("prime_bed")
	## Bigger pits hold a little more too: each pit size step adds to the odds
	## and the cap, so a big pit can surprise you even before the bed upgrades.
	var pit_steps: float = float(Tuning.site_size_rank)
	Tuning.extra_find_slots = int(2.0 + beds * 2.0 + pit_steps) if beds > 0.0 else int(pit_steps)
	var bed_odds: float = 0.30 + 0.10 * _lv("scrap_bed") + 0.07 * _lv("rich_bed") + 0.05 * _lv("prime_bed") if beds > 0.0 else 0.0
	Tuning.extra_find_chance = minf(bed_odds + 0.04 * pit_steps, 0.85)
	Tuning.big_finds_unlocked = _lv("rich_bed") > 0.0
	Tuning.passive_miner_owned = false
	Tuning.integrity_hit_cost = 0.0
	Tuning.condition_luck = 0.12 * (_lv("shovel_soft") + _lv("pick_soft"))
	Tuning.unveil_spike_seconds = float(_bases["unveil_spike_seconds"]) + 6.0 * _lv("unveil_time") + 6.0 * _lv("blockbuster_hours")
	Tuning.unveil_rush_strength = float(_bases["unveil_rush_strength"]) + 0.25 * _lv("unveil_crowd")
	Tuning.spotlight_mult = float(_bases["spotlight_mult"]) + _lv("spotlight") + _lv("blockbuster_feature")


func piece_need(piece_id: String) -> int:
	var data: FossilData = fossil_data_for(piece_id)
	if data != null:
		return maxi(1, int(data.set_need))
	return 1


func piece_count(piece_id: String) -> int:
	if not pieces.has(piece_id):
		return 0
	var piece: Dictionary = pieces[piece_id]
	return maxi(0, int(piece.get("count", 1)))


func piece_needs_more(piece_id: String) -> bool:
	return piece_count(piece_id) < piece_need(piece_id)


func piece_progress_label(piece_id: String) -> String:
	var need: int = piece_need(piece_id)
	if need <= 1:
		return ""
	return "%d/%d" % [piece_count(piece_id), need]


func uncover_status_line(piece_id: String) -> String:
	return collection_status_line(piece_id)


func hall_fate_line(piece_id: String, condition: int = 0) -> String:
	if condition > 0 and has_piece(piece_id) and piece_count(piece_id) >= piece_need(piece_id) and condition > piece_condition(piece_id):
		return "Upgrade · %s" % Tuning.condition_name(condition)
	return collection_status_line(piece_id)


func piece_condition(piece_id: String) -> int:
	if not has_piece(piece_id):
		return 0
	return int((pieces[piece_id] as Dictionary).get("condition", Tuning.CONDITION_GOOD))


## Average condition of what is mounted on a stand (0 if nothing is).
func stand_condition(stand_id: String) -> float:
	var total: float = 0.0
	var n: int = 0
	for piece_id in pieces:
		if stand_for_piece(str(piece_id)) != stand_id:
			continue
		total += float(piece_condition(str(piece_id)))
		n += 1
	return total / float(n) if n > 0 else 0.0


func collection_status_line(piece_id: String) -> String:
	var need: int = maxi(1, piece_need(piece_id))
	var count: int = piece_count(piece_id)
	if count >= need:
		return "Duplicate · %d/%d" % [need, need]
	return "New · %d/%d" % [count + 1, need]


func _duplicate_sale(cleanliness: float, set_bonus: bool, condition: int = Tuning.CONDITION_GOOD) -> int:
	var bonus: float = 100.0 * Tuning.duplicate_cash * (0.5 + cleanliness * 0.5) * Tuning.fossil_value_mult * Tuning.condition_value(condition) * fame_mult()
	if set_bonus:
		bonus *= Tuning.set_complete_sale_mult
	return int(round(bonus))


func try_mount_matrix_find(find: Dictionary) -> bool:
	var piece_id: String = _matrix_hall_piece(find)
	if piece_id.is_empty() or has_piece(piece_id):
		return false
	var data: FossilData = fossil_data_for(piece_id)
	var display_name: String = data.name if data != null else "Amber Insect"
	install_find(piece_id, display_name, 0.35, false)
	return true


func _matrix_hall_piece(find: Dictionary) -> String:
	var key: String = str(find.get("name", "")).to_lower()
	if key.find("amber") >= 0:
		return "amber_insect"
	return ""


func install_find(piece_id: String, display_name: String, cleanliness: float, clean: bool, condition: int = Tuning.CONDITION_GOOD) -> String:
	var stand_id: String = stand_for_piece(piece_id)
	var was_complete: bool = stand_id != "" and stand_is_complete(stand_id)
	var was_master: bool = stand_id != "" and stand_is_masterpiece(stand_id)
	var note: String = _install_piece(piece_id, display_name, cleanliness, clean, clampi(condition, 1, 5))
	if stand_id != "" and not was_master and stand_is_masterpiece(stand_id):
		call_deferred("_award_masterpiece", stand_id)
	if stand_id != "" and not was_complete and stand_is_complete(stand_id):
		var bonus: int = skeleton_bonus(stand_id)
		add_money(bonus)
		skeleton_completed.emit(stand_id, bonus)
		note = "%s COMPLETE! +$%d, visitors x%s." % [stand_title(stand_id), bonus, _mult_text(Tuning.complete_stand_mult)]
	return note


var _fame_frame: int = -1
var _fame_value: float = 1.0


## Museum fame: collectors pay more for bones as the museum earns more.
## Cached per frame because every find card asks for it.
func fame_mult() -> float:
	var frame: int = Engine.get_process_frames()
	if frame != _fame_frame:
		_fame_frame = frame
		_fame_value = 1.0 + museum_income_base() * Tuning.fame_per_income
	return _fame_value


func fame_line() -> String:
	var mult: float = fame_mult()
	if mult < 1.05:
		return ""
	return "Museum fame: finds pay x%s" % (("%.1f" % mult) if mult < 10.0 else str(int(round(mult))))


## Masterpiece: complete, and every piece Perfect (5 stars) AND clean.
func stand_is_masterpiece(stand_id: String) -> bool:
	if stand_id.is_empty() or not stand_is_complete(stand_id):
		return false
	for piece_id in stand_piece_ids(stand_id):
		if piece_condition(str(piece_id)) < Tuning.masterpiece_min_condition:
			return false
		if not piece_is_clean(str(piece_id)):
			return false
	return true


## Clean = flagged clean, or brushed past the same 96% the hover card calls "Clean".
func piece_is_clean(piece_id: String) -> bool:
	if not has_piece(piece_id):
		return false
	var piece: Dictionary = pieces[piece_id]
	return bool(piece.get("clean", false)) or float(piece.get("cleanliness", 0.0)) >= Tuning.clean_extract_threshold


func masterpiece_bonus(stand_id: String) -> int:
	## The hardest goal in the game pays like it: a big multiple of the bones'
	## worth, or several minutes of museum income, whichever is larger.
	var from_bones: float = float(skeleton_bonus(stand_id)) * Tuning.masterpiece_bonus_mult
	var from_income: float = museum_income() * Tuning.masterpiece_income_seconds
	return int(round(maxf(from_bones, from_income)))


func _award_masterpiece(stand_id: String) -> void:
	var bonus: int = masterpiece_bonus(stand_id)
	add_money(bonus)
	hall_changed.emit()
	masterpiece_completed.emit(stand_id, bonus)


## Cleaning Cart (id "workshop" for old saves): drag it onto an exhibit and it
## slowly cleans that exhibit's dirtiest bone. The exhibit is closed (earns
## nothing) the whole time. Parked (cleaner_stand_id == "") it does nothing.
func prep_cart_seconds(rank: int = -1) -> int:
	if rank < 0:
		rank = int(_lv("workshop"))
	return int(Tuning.cart_level_seconds[clampi(rank, 0, Tuning.cart_level_seconds.size() - 1)])


## Dirt levels match the hover card's words: Caked < 25% <= Dirty < 60% <=
## Dusty < 96% <= Clean. Returns [bottom, top] of the level a bone is in.
## (An Array, not a Vector2: Vector2 is 32-bit and 0.96 would round below the
## real threshold, so a bone could never finish its last level.)
func dirt_level_span(cleanliness: float) -> Array:
	var edges: Array[float] = [0.0, 0.25, 0.6, Tuning.clean_extract_threshold]
	for i in range(edges.size() - 1):
		if cleanliness < edges[i + 1]:
			return [edges[i], edges[i + 1]]
	return [edges[edges.size() - 1], 1.0]


## What the cart is doing right now, for the overlay: the level it is moving
## the bone out of and into, how far through that level it is, and time left.
func prep_cart_level_info(piece_id: String) -> Dictionary:
	if not has_piece(piece_id):
		return {}
	var c: float = piece_cleanliness(piece_id)
	var span: Array = dirt_level_span(c)
	var low: float = span[0]
	var high: float = span[1]
	var secs: float = float(prep_cart_seconds())
	var width: float = maxf(high - low, 0.001)
	return {
		"from": c,
		"to": high,
		"progress": clampf((c - low) / width, 0.0, 1.0),
		"seconds_left": (high - c) / width * secs,
	}


func prep_cart_owned() -> bool:
	return int(_lv("workshop")) > 0


func stand_dirty_pieces(stand_id: String) -> PackedStringArray:
	var out := PackedStringArray()
	for piece_id in pieces:
		var id: String = str(piece_id)
		if stand_for_piece(id) == stand_id and not piece_is_clean(id):
			out.append(id)
	return out


## The bone the cart is working on. It picks the bone in the lowest dirt
## level (Caked before Dirty before Dusty); among bones in the same level, the
## more valuable one goes first. Once picked it sticks with that bone until it
## is clean, so equally dirty bones can't swap places every frame.
func prep_cart_target() -> String:
	if not stand_is_being_cleaned(cleaner_stand_id):
		_cart_target = ""
		return ""
	if _cart_target != "" and stand_for_piece(_cart_target) == cleaner_stand_id and has_piece(_cart_target) and not piece_is_clean(_cart_target):
		return _cart_target
	_cart_target = _pick_cart_target(cleaner_stand_id)
	return _cart_target


func _pick_cart_target(stand_id: String) -> String:
	var pick: String = ""
	var pick_level: float = 2.0
	var pick_value: float = -1.0
	for id in stand_dirty_pieces(stand_id):
		var level: float = float(dirt_level_span(piece_cleanliness(id))[0])
		var data: FossilData = fossil_data_for(id)
		var value: float = float(data.base_value) if data != null else 0.0
		if level < pick_level - 0.0001 or (absf(level - pick_level) <= 0.0001 and value > pick_value):
			pick = id
			pick_level = level
			pick_value = value
	return pick


## Closed for cleaning: the cart is here and there is dirt for it to work on.
func stand_is_being_cleaned(stand_id: String) -> bool:
	if stand_id.is_empty() or stand_id != cleaner_stand_id or not prep_cart_owned():
		return false
	if stand_has_pending_unveil(stand_id):
		return false
	return not stand_dirty_pieces(stand_id).is_empty()


func set_cleaner_stand(stand_id: String) -> bool:
	if stand_id != "" and (not prep_cart_owned() or not stand_is_filled(stand_id)):
		return false
	if cleaner_stand_id == stand_id:
		return true
	cleaner_stand_id = stand_id
	_cart_target = ""
	hall_changed.emit()
	return true


func _tick_cleaner(delta: float) -> void:
	var id: String = prep_cart_target()
	if id.is_empty():
		return
	var piece: Dictionary = pieces[id]
	var c: float = float(piece.get("cleanliness", 0.0))
	var per_level: float = float(prep_cart_seconds())
	if per_level <= 0.0:
		return
	## Each dirt level takes the same time to climb, however wide it is.
	var budget: float = delta
	var steps: int = 0
	while budget > 0.0 and c < Tuning.clean_extract_threshold and steps < 8:
		steps += 1
		var span: Array = dirt_level_span(c)
		var low: float = span[0]
		var high: float = span[1]
		var rate: float = (high - low) / per_level
		var needed: float = (high - c) / rate
		if needed > budget:
			c += rate * budget
			budget = 0.0
		else:
			c = high
			budget -= needed
	if c < Tuning.clean_extract_threshold:
		piece["cleanliness"] = c
		return
	var stand_id: String = stand_for_piece(id)
	var was_master: bool = stand_is_masterpiece(stand_id)
	piece["clean"] = true
	piece["cleanliness"] = 1.0
	cleaner_finished_name = str(piece.get("name", id))
	if not was_master and stand_is_masterpiece(stand_id):
		_award_masterpiece(stand_id)
	collection_changed.emit()
	hall_changed.emit()
	cleaner_finished.emit(id)


## The finished-skeleton payout: the stand's full bone value, doubled.
func skeleton_bonus(stand_id: String) -> int:
	var total: float = 0.0
	for piece_id in stand_piece_ids(stand_id):
		var data: FossilData = fossil_data_for(str(piece_id))
		if data != null:
			total += float(data.base_value) * float(piece_need(str(piece_id)))
	return int(round(total * Tuning.skeleton_bonus_mult))


func _mult_text(mult: float) -> String:
	if is_equal_approx(mult, round(mult)):
		return "%d" % int(round(mult))
	return "%.1f" % mult


func _install_piece(piece_id: String, display_name: String, cleanliness: float, clean: bool, condition: int = Tuning.CONDITION_GOOD) -> String:
	var need: int = piece_need(piece_id)
	var count: int = piece_count(piece_id)
	if pieces.has(piece_id) and count >= need:
		var set_bonus: bool = need > 1
		var held: Dictionary = pieces[piece_id]
		var old_condition: int = int(held.get("condition", Tuning.CONDITION_GOOD))
		var cleaner: bool = condition == old_condition and clean and not bool(held.get("clean", false))
		if condition > old_condition or cleaner:
			## A better (or same-star but clean) copy replaces the one on display;
			## the old one is sold.
			var old_sale: int = _duplicate_sale(float(held.get("cleanliness", 0.0)), set_bonus, old_condition)
			held["condition"] = condition
			held["name"] = display_name
			held["cleanliness"] = cleanliness
			held["clean"] = clean
			pieces[piece_id] = held
			add_money(old_sale)
			collection_changed.emit()
			hall_changed.emit()
			return "Exhibit upgraded: %s is now in %s. Old copy sold for $%d." % [display_name, Tuning.condition_label(condition).to_lower(), old_sale]
		var bonus: int = _duplicate_sale(cleanliness, set_bonus, condition)
		add_money(bonus)
		collection_changed.emit()
		if set_bonus:
			return "Set complete for %s. Extra sold for $%d." % [display_name, bonus]
		return "Already on display. Extra copy sold for $%d." % bonus
	if pieces.has(piece_id):
		var piece: Dictionary = pieces[piece_id]
		piece["count"] = count + 1
		piece["condition"] = maxi(int(piece.get("condition", Tuning.CONDITION_GOOD)), condition)
		if cleanliness >= float(piece.get("cleanliness", 0.0)):
			piece["name"] = display_name
			piece["cleanliness"] = cleanliness
			piece["clean"] = clean
		pieces[piece_id] = piece
		collection_changed.emit()
		hall_changed.emit()
		return _mount_note(display_name, count + 1, need, bool(pieces[piece_id].get("clean", clean)))
	pieces[piece_id] = {
		"name": display_name,
		"cleanliness": cleanliness,
		"clean": clean,
		"count": 1,
		"condition": condition,
	}
	if stand_for_piece(piece_id) != "":
		pending_unveils[piece_id] = true
	collection_changed.emit()
	hall_changed.emit()
	return _mount_note(display_name, 1, need, clean)


func _mount_note(display_name: String, count: int, need: int, clean: bool) -> String:
	if need > 1:
		if count >= need:
			return "%s set complete (%d/%d)." % [display_name, count, need]
		var note: String = "%s %d/%d is now on display." % [display_name, count, need]
		if clean:
			return note
		return "%s It still looks dusty." % note
	if clean:
		return "%s is now on display." % display_name
	return "%s is on display, but it still looks dusty." % display_name


func stand_for_piece(piece_id: String) -> String:
	if piece_id.is_empty():
		return ""
	if piece_id.begins_with("t_rex"):
		return STAND_T_REX
	if piece_id.begins_with("triceratops"):
		return STAND_TRICERATOPS
	if piece_id.begins_with("stegosaurus"):
		return STAND_STEGOSAURUS
	if piece_id.begins_with("brachiosaurus"):
		return STAND_BRACHIOSAURUS
	if piece_id.begins_with("velociraptor"):
		return STAND_VELOCIRAPTOR
	if piece_id == "cycad" or piece_id == "fossil_flower":
		return STAND_PLANT_FOSSILS
	return STAND_SMALL_FINDS


func stand_uses_exhibit_rate(stand_id: String) -> bool:
	return stand_id == STAND_T_REX or stand_id == STAND_TRICERATOPS or stand_id == STAND_BRACHIOSAURUS or stand_id == STAND_VELOCIRAPTOR or stand_id == STAND_STEGOSAURUS


func fossil_data_for(piece_id: String) -> FossilData:
	if piece_id.is_empty():
		return null
	if _fossil_by_id.has(piece_id):
		return _fossil_by_id[piece_id] as FossilData
	for path in Tuning.main_fossil_paths:
		var data: FossilData = load(str(path)) as FossilData
		if data != null and data.piece_id == piece_id:
			_fossil_by_id[piece_id] = data
			return data
	for path in Tuning.extra_fossil_paths:
		var data: FossilData = load(str(path)) as FossilData
		if data != null and data.piece_id == piece_id:
			_fossil_by_id[piece_id] = data
			return data
	return null


func stand_piece_ids(stand_id: String) -> PackedStringArray:
	var ids: PackedStringArray = PackedStringArray()
	if stand_id.is_empty():
		return ids
	var paths: PackedStringArray = Tuning.main_fossil_paths
	if stand_id == STAND_SMALL_FINDS or stand_id == STAND_PLANT_FOSSILS:
		paths = Tuning.extra_fossil_paths
	## Income math asks for this several times a frame; the roster is static.
	var key: String = "%s|%d|%s|%s" % [stand_id, paths.size(), paths[0] if paths.size() > 0 else "", paths[paths.size() - 1] if paths.size() > 0 else ""]
	if _stand_ids_cache.has(key):
		return _stand_ids_cache[key]
	for path in paths:
		var data: FossilData = load(str(path)) as FossilData
		if data == null or data.stand_id != stand_id:
			continue
		if data.piece_id.is_empty() or ids.has(data.piece_id):
			continue
		ids.append(data.piece_id)
	_stand_ids_cache[key] = ids
	return ids


func stand_regions(stand_id: String) -> PackedStringArray:
	var regions: PackedStringArray = PackedStringArray()
	for piece_id in stand_piece_ids(stand_id):
		var data: FossilData = fossil_data_for(piece_id)
		if data == null or data.mount_region.is_empty():
			continue
		if not regions.has(data.mount_region):
			regions.append(data.mount_region)
	return regions


func stand_region_filled(stand_id: String, region: String) -> bool:
	if stand_id.is_empty() or region.is_empty():
		return false
	for piece_id in pieces:
		var id: String = str(piece_id)
		if stand_for_piece(id) != stand_id:
			continue
		var data: FossilData = fossil_data_for(id)
		if data != null and data.mount_region == region:
			return true
	return false


## Weakest condition among the bones mounted in one region of a stand (0 = empty).
func stand_region_condition(stand_id: String, region: String) -> int:
	var worst: int = 0
	for piece_id in pieces:
		var id: String = str(piece_id)
		if stand_for_piece(id) != stand_id:
			continue
		var data: FossilData = fossil_data_for(id)
		if data == null or data.mount_region != region:
			continue
		var cond: int = piece_condition(id)
		worst = cond if worst == 0 else mini(worst, cond)
	return worst if worst > 0 else Tuning.CONDITION_GOOD


func stand_region_clean(stand_id: String, region: String) -> bool:
	if not stand_region_filled(stand_id, region):
		return false
	for piece_id in pieces:
		var id: String = str(piece_id)
		if stand_for_piece(id) != stand_id:
			continue
		var data: FossilData = fossil_data_for(id)
		if data == null or data.mount_region != region:
			continue
		var piece: Dictionary = pieces[id]
		if bool(piece.get("clean", false)):
			return true
	return false


func stand_is_complete(stand_id: String) -> bool:
	var ids: PackedStringArray = stand_piece_ids(stand_id)
	if ids.is_empty():
		return false
	for piece_id in ids:
		if piece_needs_more(piece_id):
			return false
	return true


func piece_blurb(piece_id: String) -> String:
	match piece_id:
		"t_rex_tooth":
			return "T. rex teeth for the jaw — collect 6 for a mouth, not a textbook set of 60."
		"t_rex_jaw":
			return "A T. rex jaw for the center bay."
		"t_rex_femur":
			return "A T. rex femur for the legs."
		"t_rex_ribcage":
			return "A T. rex ribcage for the torso."
		"t_rex_tail":
			return "A T. rex tail series for the center bay."
		"t_rex_skull":
			return "A T. rex skull for the head."
		"triceratops_tooth":
			return "Triceratops battery teeth for the beak — collect 5."
		"triceratops_vertebra":
			return "A Triceratops vertebra for the body."
		"triceratops_nose_horn":
			return "A Triceratops nose horn."
		"triceratops_brow_horns":
			return "Triceratops brow horns."
		"triceratops_hind_limb":
			return "A Triceratops hind limb."
		"triceratops_tail":
			return "A Triceratops tail."
		"triceratops_skull":
			return "A skull for the Triceratops bay."
		"stegosaurus_foot":
			return "Stegosaurus feet — collect all 4."
		"stegosaurus_plate":
			return "Stegosaurus plates for the back — collect 3, not a full sail of 17."
		"stegosaurus_femur":
			return "A Stegosaurus femur for the legs."
		"stegosaurus_thagomizer":
			return "A Stegosaurus tail spike."
		"stegosaurus_torso":
			return "A Stegosaurus torso."
		"stegosaurus_skull":
			return "A Stegosaurus skull for the head."
		"velociraptor_claw":
			return "Velociraptor sickle claws — one per foot, collect 2."
		"velociraptor_skull":
			return "A Velociraptor skull."
		"velociraptor_femur":
			return "A Velociraptor femur."
		"velociraptor_tail":
			return "A Velociraptor tail."
		"velociraptor_ribs":
			return "Velociraptor ribs."
		"brachiosaurus_tooth":
			return "Brachiosaurus peg teeth — collect 5 to start the sauropod stand."
		"brachiosaurus_tail":
			return "A Brachiosaurus tail."
		"brachiosaurus_skull":
			return "A small Brachiosaurus skull."
		"brachiosaurus_humerus":
			return "A Brachiosaurus humerus."
		"brachiosaurus_femur":
			return "A Brachiosaurus femur."
		"brachiosaurus_neck":
			return "A long Brachiosaurus neck."
		"trilobite":
			return "A trilobite for the Small Finds case."
		"amber_insect":
			return "An insect in amber for the Small Finds case."
		"tooth":
			return "A small tooth — first piece for the hall case."
		"vertebra":
			return "A vertebra for the Small Finds case."
		"cycad":
			return "A cycad for the Plant Fossils case."
		"fossil_flower":
			return "A fossil flower for the Plant Fossils case."
		_:
			return "Goes on display in the hall."


func stand_title(stand_id: String) -> String:
	match stand_id:
		STAND_T_REX:
			return "T. rex"
		STAND_TRICERATOPS:
			return "Triceratops"
		STAND_BRACHIOSAURUS:
			return "Brachiosaurus"
		STAND_VELOCIRAPTOR:
			return "Velociraptor"
		STAND_STEGOSAURUS:
			return "Stegosaurus"
		STAND_SMALL_FINDS:
			return "Small Finds"
		STAND_PLANT_FOSSILS:
			return "Plant Fossils"
		_:
			return ""


func stand_is_filled(stand_id: String) -> bool:
	if stand_id.is_empty():
		return false
	for piece_id in pieces:
		if stand_for_piece(str(piece_id)) == stand_id:
			return true
	return false


func stand_has_pending_unveil(stand_id: String) -> bool:
	if not stand_is_filled(stand_id):
		return false
	for piece_id in pieces:
		if stand_for_piece(str(piece_id)) != stand_id:
			continue
		if bool(pending_unveils.get(str(piece_id), false)):
			return true
	return false


func has_any_pending_unveil() -> bool:
	return not pending_unveil_ids("").is_empty()


func pending_unveil_ids(stand_id: String = "") -> PackedStringArray:
	var ids: PackedStringArray = []
	for piece_id in pieces:
		var id: String = str(piece_id)
		if not bool(pending_unveils.get(id, false)):
			continue
		var piece_stand: String = stand_for_piece(id)
		if piece_stand == "":
			continue
		if stand_id != "" and piece_stand != stand_id:
			continue
		ids.append(id)
	return ids


func _piece_display_name(piece_id: String) -> String:
	if pieces.has(piece_id):
		return str(pieces[piece_id].get("name", piece_id))
	return piece_id


func _join_and(names: PackedStringArray) -> String:
	if names.is_empty():
		return ""
	if names.size() == 1:
		return names[0]
	if names.size() == 2:
		return "%s and %s" % [names[0], names[1]]
	var head: String = ", ".join(names.slice(0, names.size() - 1))
	return "%s, and %s" % [head, names[names.size() - 1]]


func pending_unveil_label(stand_id: String = "") -> String:
	var names: PackedStringArray = []
	for id in pending_unveil_ids(stand_id):
		names.append(_piece_display_name(id))
	return _join_and(names)


func unveil_title(stand_id: String) -> String:
	var label: String = pending_unveil_label(stand_id)
	if label.is_empty():
		return "Unveil"
	return "Unveil %s" % label


func pending_unveil_waiting_line() -> String:
	var n: int = pending_unveil_ids("").size()
	if n <= 0:
		return ""
	if n == 1:
		return "1 unveil waiting"
	return "%d unveils waiting" % n


func _clear_unveil_rush() -> void:
	unveil_spike_left = 0.0
	unveil_rush_stacks = 0
	unveil_rush_unit = 0.0


func museum_donation() -> float:
	return Tuning.donation_base * Tuning.donation_mult + Tuning.donation_flat


func piece_visitors(piece_id: String, force_clean: bool = false) -> int:
	if not has_piece(piece_id):
		return 0
	var piece: Dictionary = pieces[piece_id]
	var count: int = piece_count(piece_id)
	var clean: bool = bool(piece.get("clean", false)) or force_clean
	var exhibit: bool = stand_uses_exhibit_rate(stand_for_piece(piece_id))
	var clean_draw: int = Tuning.visitor_draw_exhibit_clean if exhibit else Tuning.visitor_draw_scrap_clean
	var dirty_draw: int = Tuning.visitor_draw_exhibit_dirty if exhibit else Tuning.visitor_draw_scrap_dirty
	## How dirty it is matters, not just clean-or-not: income slides from the
	## dirty floor (fully caked) up to full as the bone gets cleaner.
	var cleanliness: float = 1.0 if clean else clampf(float(piece.get("cleanliness", 0.0)), 0.0, 1.0)
	var floor_draw: float = minf(float(dirty_draw), float(clean_draw))
	var draw: float = lerpf(floor_draw, float(clean_draw), cleanliness)
	## Better-condition bones draw more visitors (Good = 1x).
	var cond_mult: float = Tuning.condition_visitors(int(piece.get("condition", Tuning.CONDITION_GOOD)))
	var scale: float = stand_size_scale(stand_for_piece(piece_id)) if exhibit else 1.0
	var weight: float = piece_unit_weight(piece_id) if exhibit else 1.0
	## Every mounted bone draws at least one visitor, however small.
	return maxi(1, int(round(draw * float(count) * weight * cond_mult * scale)))


## How clean a displayed bone is, 0..1 (1 = fully clean).
func piece_cleanliness(piece_id: String) -> float:
	if not has_piece(piece_id):
		return 0.0
	var piece: Dictionary = pieces[piece_id]
	return 1.0 if bool(piece.get("clean", false)) else clampf(float(piece.get("cleanliness", 0.0)), 0.0, 1.0)


## A displayed bone's own share of its stand's $/sec (stars, dirt and the
## stand's complete/Masterpiece/Featured boosts all included).
func piece_stand_income(piece_id: String) -> float:
	var stand_id: String = stand_for_piece(piece_id)
	var raw: int = 0
	for other in pieces:
		if stand_for_piece(str(other)) == stand_id:
			raw += piece_visitors(str(other))
	if raw <= 0:
		return 0.0
	return float(piece_visitors(piece_id)) / float(raw) * stand_income(stand_id)


## Dino skeletons need different bone counts (Velociraptor 6, T. rex 11).
## Each bone's draw is scaled so a finished skeleton is worth about the same
## whichever dino it is, with only a slight edge for the bigger ones.
func stand_size_scale(stand_id: String) -> float:
	if stand_id.is_empty():
		return 1.0
	if _stand_scale_cache.has(stand_id):
		return float(_stand_scale_cache[stand_id])
	var units: int = 0
	for piece_id in stand_piece_ids(stand_id):
		units += piece_need(str(piece_id))
	units = maxi(units, 1)
	var edge: float = 1.0 + Tuning.stand_size_edge * clampf(float(units - 6) / 5.0, 0.0, 1.0)
	var scale: float = Tuning.stand_target_units / float(units) * edge
	_stand_scale_cache[stand_id] = scale
	return scale


## How much one copy of a bone draws compared with an average bone on its
## stand (1.0 = average). Bigger, more intricate bones (higher base_value) draw
## more, so a skull always out-earns a tail and a tail out-earns a tooth. A
## set of small bones (need > 1) shares one base_value between its copies, so a
## full set of teeth never out-earns a big bone. Weights are normalised per
## stand, so a finished stand's total draw is unchanged.
func piece_unit_weight(piece_id: String) -> float:
	var key: String = "w|" + piece_id
	if _stand_scale_cache.has(key):
		return float(_stand_scale_cache[key])
	var stand_id: String = stand_for_piece(piece_id)
	var units: float = 0.0
	var total_value: float = 0.0
	for id in stand_piece_ids(stand_id):
		units += float(piece_need(str(id)))
		var other: FossilData = fossil_data_for(str(id))
		total_value += float(other.base_value) if other != null else 1.0
	var data: FossilData = fossil_data_for(piece_id)
	var weight: float = 1.0
	if data != null and total_value > 0.0 and units > 0.0:
		var per_copy: float = float(data.base_value) / float(piece_need(piece_id))
		weight = per_copy * units / total_value
	_stand_scale_cache[key] = weight
	return weight


func stand_visitors(stand_id: String, force_clean: bool = false) -> int:
	if stand_is_being_cleaned(stand_id):
		return 0
	var total: int = 0
	for piece_id in pieces:
		if stand_for_piece(str(piece_id)) != stand_id:
			continue
		total += piece_visitors(str(piece_id), force_clean)
	if stand_id != "" and stand_is_complete(stand_id):
		total = int(round(float(total) * Tuning.complete_stand_mult))
		if stand_is_masterpiece(stand_id):
			total = int(round(float(total) * Tuning.masterpiece_mult))
	if stand_id != "" and stand_id == featured_stand_id:
		total = int(round(float(total) * Tuning.spotlight_mult))
	return total


func museum_visitors_base() -> int:
	return int(round(float(_museum_visitors_raw()) * Tuning.visitor_mult))


func _museum_visitors_raw() -> int:
	var total: int = int(Tuning.visitor_flat)
	var seen: Dictionary = {}
	for piece_id in pieces:
		var stand_id: String = stand_for_piece(str(piece_id))
		if stand_id.is_empty() or seen.has(stand_id):
			continue
		seen[stand_id] = true
		total += stand_visitors(stand_id)
	return total


func surge_visitors() -> int:
	if unveil_spike_left <= 0.0 or unveil_rush_stacks <= 0:
		return 0
	return int(round(float(unveil_rush_stacks) * unveil_rush_unit * Tuning.unveil_rush_strength))


func museum_visitors() -> int:
	return museum_visitors_base() + surge_visitors()


func visitor_sprite_count() -> int:
	return _packed_visitor_sprites(museum_visitors_base()) + surge_visitors()


func _packed_visitor_sprites(n: int) -> int:
	if n <= 24:
		return n
	return mini(48, 24 + int((n - 24) / 10))


func unveil_rush_rate() -> float:
	return float(surge_visitors()) * museum_donation()


func unveil_rush_line() -> String:
	var extra: int = surge_visitors()
	if extra <= 0:
		return ""
	var secs: int = maxi(1, int(ceili(unveil_spike_left)))
	if unveil_rush_stacks > 1:
		return "Crowd surge ×%d · +%d visitors · %ds" % [unveil_rush_stacks, extra, secs]
	return "Crowd surge · +%d visitors · %ds" % [extra, secs]


func museum_income_base() -> float:
	return float(museum_visitors_base()) * museum_donation()


func museum_crowd_line() -> String:
	var n: int = museum_visitors()
	var donation: float = museum_donation()
	var rate: float = museum_income()
	if n <= 0:
		return "$0.00 / sec"
	return "%d visitors · $%.2f each · $%.2f / sec" % [n, donation, rate]


func piece_income(piece_id: String) -> float:
	return float(piece_visitors(piece_id)) * museum_donation()


func stand_income(stand_id: String) -> float:
	return float(stand_visitors(stand_id)) * museum_donation()



func unveil_stand(stand_id: String) -> int:
	if not stand_has_pending_unveil(stand_id):
		return 0
	var waiting: Array[String] = []
	for piece_id in pieces:
		var id: String = str(piece_id)
		if stand_for_piece(id) != stand_id:
			continue
		if not bool(pending_unveils.get(id, false)):
			continue
		waiting.append(id)
	for id in waiting:
		pending_unveils.erase(id)
	_add_unveil_rush_stack()
	collection_changed.emit()
	hall_changed.emit()
	return 0


func _add_unveil_rush_stack() -> void:
	var duration: float = Tuning.unveil_spike_seconds
	if unveil_spike_left <= 0.0 or unveil_rush_stacks <= 0:
		unveil_rush_unit = float(Tuning.unveil_surge_visitors)
		unveil_rush_stacks = 1
		unveil_spike_left = duration
		return
	if unveil_rush_stacks < Tuning.unveil_rush_stack_cap:
		unveil_rush_stacks += 1
	unveil_spike_left += duration


func set_featured_stand(stand_id: String) -> bool:
	if not stand_is_filled(stand_id):
		return false
	featured_stand_id = stand_id
	hall_changed.emit()
	collection_changed.emit()
	return true


func museum_income() -> float:
	return float(museum_visitors()) * museum_donation()


func has_piece(piece_id: String) -> bool:
	return pieces.has(piece_id)


func _lv(id: String) -> float:
	return float(levels.get(id, 0))


func _item(id: String) -> Dictionary:
	for item in catalog:
		if str(item["id"]) == id:
			return item
	return {}


func reset_progress(path: String = SAVE_PATH) -> void:
	money = 0
	pieces.clear()
	hints_seen.clear()
	featured_stand_id = ""
	cleaner_stand_id = ""
	pending_unveils.clear()
	pending_notices.clear()
	last_unlock_title = ""
	last_unlocked_ids.clear()
	_clear_unveil_rush()
	_income_accum = 0.0
	precision_on = false
	for item in catalog:
		levels[item["id"]] = 0
	levels.erase("precision")
	apply_upgrades()
	_erase_save(path)
	money_changed.emit()
	collection_changed.emit()
	upgrades_changed.emit()
	hall_changed.emit()
	progress_reset.emit()


## A New game must never come back from disk. Deleting through a globalized
## absolute path can silently fail (web builds keep user:// in browser
## storage), which let an old save, finds and all, reload on the next launch.
## Delete through user:// directly, and if the file is somehow still there,
## overwrite it with the fresh, empty game.
func _erase_save(path: String) -> void:
	if not FileAccess.file_exists(path):
		return
	var dir: DirAccess = DirAccess.open(path.get_base_dir())
	if dir != null:
		dir.remove(path.get_file())
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if FileAccess.file_exists(path):
		save_game(path)


## Money back for ranks of upgrades that have since been removed.
func retired_refund(raw_levels: Dictionary) -> int:
	var total: float = 0.0
	for id in RETIRED_UPGRADES:
		var info: Dictionary = RETIRED_UPGRADES[id]
		for rank in int(raw_levels.get(id, 0)):
			total += float(info["cost"]) * pow(float(info["scale"]), float(rank))
	return int(round(total))


func has_save(path: String = SAVE_PATH) -> bool:
	return FileAccess.file_exists(path)


func save_game(path: String = SAVE_PATH) -> bool:
	var data := {
		"version": SAVE_VERSION,
		"money": money,
		"levels": levels.duplicate(),
		"pieces": pieces.duplicate(true),
		"hints_seen": hints_seen.duplicate(),
		"precision_on": precision_on,
		"featured_stand_id": featured_stand_id,
		"cleaner_stand_id": cleaner_stand_id,
		"pending_unveils": pending_unveils.duplicate(),
		"pending_notices": pending_notices.duplicate(true),
		"unveil_spike_left": unveil_spike_left,
		"unveil_rush_stacks": unveil_rush_stacks,
		"unveil_rush_unit": unveil_rush_unit,
	}
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return true


func load_game(path: String = SAVE_PATH) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	var data: Dictionary = parsed
	money = int(data.get("money", 0))
	var raw_levels: Dictionary = data.get("levels", {})
	money += retired_refund(raw_levels)
	for item in catalog:
		var id: String = str(item["id"])
		levels[id] = int(raw_levels.get(id, 0))
	levels.erase("precision")
	pieces.clear()
	var raw_pieces: Dictionary = data.get("pieces", {})
	for raw_id in raw_pieces:
		var piece_id: String = str(raw_id)
		var piece: Dictionary = raw_pieces[raw_id]
		pieces[piece_id] = {
			"name": str(piece.get("name", piece_id)),
			"cleanliness": float(piece.get("cleanliness", 0.0)),
			"clean": bool(piece.get("clean", false)),
			"count": maxi(1, int(piece.get("count", 1))),
			"condition": clampi(int(piece.get("condition", Tuning.CONDITION_GOOD)), 1, 5),
		}
	hints_seen.clear()
	var raw_hints: Variant = data.get("hints_seen", {})
	if raw_hints is Dictionary:
		for raw_id in raw_hints:
			hints_seen[str(raw_id)] = true
	precision_on = bool(data.get("precision_on", false))
	featured_stand_id = str(data.get("featured_stand_id", ""))
	cleaner_stand_id = str(data.get("cleaner_stand_id", ""))
	pending_unveils.clear()
	var raw_unveils: Dictionary = data.get("pending_unveils", {})
	for raw_id in raw_unveils:
		if bool(raw_unveils[raw_id]):
			pending_unveils[str(raw_id)] = true
	unveil_spike_left = float(data.get("unveil_spike_left", 0.0))
	unveil_rush_stacks = int(data.get("unveil_rush_stacks", 0))
	unveil_rush_unit = float(data.get("unveil_rush_unit", 0.0))
	pending_notices.clear()
	var raw_notices: Variant = data.get("pending_notices", [])
	if raw_notices is Array:
		for raw in raw_notices:
			if raw is Dictionary:
				pending_notices.append((raw as Dictionary).duplicate(true))
	apply_upgrades()
	money_changed.emit()
	collection_changed.emit()
	upgrades_changed.emit()
	hall_changed.emit()
	return true
