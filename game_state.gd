extends Node

signal money_changed
signal collection_changed
signal upgrades_changed
signal hall_changed

const STAND_T_REX := "t_rex"
const STAND_TRICERATOPS := "triceratops"
const STAND_BRACHIOSAURUS := "brachiosaurus"
const STAND_VELOCIRAPTOR := "velociraptor"
const STAND_STEGOSAURUS := "stegosaurus"
const STAND_SMALL_FINDS := "small_finds"
const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 1

var money: int = 0
var levels: Dictionary = {}
var pieces: Dictionary = {}
var precision_on: bool = false
var pending_notices: Array = []
var last_unlock_title: String = ""
var last_unlocked_ids: Array[String] = []
var featured_stand_id: String = ""
var pending_unveils: Dictionary = {}
var unveil_spike_left: float = 0.0
var _income_accum: float = 0.0
var _bases: Dictionary = {}

var catalog: Array[Dictionary] = [
	{"id": "hands_click", "cat": "Hands", "tier": 1, "name": "Calloused Fingers", "desc": "A careful one-cell scrape. Weaker dirt than a shovel, but they do not chip bone.", "cost": 8, "scale": 1.55, "max": 5},
	{"id": "hands_hold", "cat": "Hands", "tier": 1, "name": "Steady Hands", "desc": "Hold digs faster.", "unlock_name": "Hold to Dig", "unlock_desc": "Click and hold to keep digging.", "unlock_action": "Unlock", "cost": 32, "scale": 1.55, "max": 4},
	{"id": "shovel_click", "cat": "Shovel", "tier": 1, "name": "Heavy Swings", "desc": "Clicks hit dirt harder.", "unlock_name": "Shovel", "unlock_desc": "A rusty shovel. Barely better than your hands.", "cost": 20, "scale": 1.7, "max": 6},
	{"id": "shovel_hold", "cat": "Shovel", "tier": 1, "name": "Steady Shoveling", "desc": "Hold digs faster.", "unlock_name": "Hold to Dig", "unlock_desc": "Click and hold to keep digging.", "unlock_action": "Unlock", "cost": 55, "scale": 1.65, "max": 5, "requires": "shovel_click"},
	{"id": "shovel_radius", "cat": "Shovel", "tier": 1, "name": "Wider Scoop", "desc": "Covers more ground.", "unlock_name": "Wider Scoop", "unlock_desc": "The shovel covers more than one cell.", "unlock_action": "Unlock", "cost": 90, "scale": 1.75, "max": 4, "requires": "shovel_click"},
	{"id": "shovel_super", "cat": "Shovel", "tier": 2, "name": "Super Shovel", "desc": "A heavier class of shovel. Hits harder and covers more.", "cost": 900, "scale": 1.85, "max": 6},
	{"id": "shovel_soft", "cat": "Shovel", "tier": 2, "name": "Soft Edge", "desc": "Takes more hits to crack bone.", "cost": 720, "scale": 1.75, "max": 5},
	{"id": "pick_click", "cat": "Pickaxe", "tier": 1, "name": "Sharp Strikes", "desc": "Clicks hit clay and rock harder.", "unlock_name": "Pickaxe", "unlock_desc": "Needed for clay and stone. Weak on dirt.", "cost": 140, "scale": 1.7, "max": 6, "requires": "shovel_click"},
	{"id": "pick_hold", "cat": "Pickaxe", "tier": 1, "name": "Relentless Picking", "desc": "Hold digs faster.", "unlock_name": "Hold to Dig", "unlock_desc": "Click and hold to keep striking.", "unlock_action": "Unlock", "cost": 160, "scale": 1.65, "max": 5, "requires": "pick_click"},
	{"id": "pick_super", "cat": "Pickaxe", "tier": 2, "name": "Super Pick", "desc": "A heavier pick. Clay and rock give faster.", "cost": 1100, "scale": 1.85, "max": 6},
	{"id": "pick_soft", "cat": "Pickaxe", "tier": 2, "name": "Blunted Point", "desc": "Takes more hits to crack bone.", "cost": 720, "scale": 1.75, "max": 5},
	{"id": "precision", "cat": "Pickaxe", "tier": 2, "name": "Fine Point", "desc": "Hits harder in single-block mode.", "unlock_name": "Fine Point", "unlock_desc": "Unlock single-block mode.", "unlock_action": "Unlock", "cost": 650, "scale": 1.8, "max": 5},
	{"id": "brush_speed", "cat": "Brush", "tier": 1, "name": "Softer Bristles", "desc": "Dusting the bone goes faster.", "unlock_name": "Brush", "unlock_desc": "A slow brush. Clean bones sell for more.", "cost": 220, "scale": 1.7, "max": 5, "requires": "pick_click"},
	{"id": "brush_master", "cat": "Brush", "tier": 2, "name": "Master Brush", "desc": "Even faster dusting once the first brush is maxed.", "cost": 800, "scale": 1.8, "max": 6},
	{"id": "round_time", "cat": "Site", "tier": 1, "name": "Longer Shift", "desc": "More seconds each dig.", "cost": 55, "scale": 1.65, "max": 4},
	{"id": "dirt_pay", "cat": "Site", "tier": 1, "name": "Soil Bounty", "desc": "Matrix finds in the soil pay more.", "cost": 30, "scale": 1.65, "max": 5},
	{"id": "site_size", "cat": "Site", "tier": 1, "name": "Wider Claim", "desc": "The next dig uses a larger pit.", "cost": 65, "scale": 1.85, "max": 3},
	{"id": "scrap_bed", "cat": "Site", "tier": 1, "name": "Scattered Scraps", "desc": "More scraps can hide in the pit.", "unlock_name": "Scattered Scraps", "unlock_desc": "A second small bone can hide in the pit.", "unlock_action": "Unlock", "cost": 110, "scale": 1.75, "max": 2},
	{"id": "rich_bed", "cat": "Site", "tier": 2, "name": "Rich Bed", "desc": "Extra scraps too.", "unlock_name": "Rich Bed", "unlock_desc": "Large bones can appear in the pit.", "unlock_action": "Unlock", "cost": 480, "scale": 1.8, "max": 3},
	{"id": "site_expand", "cat": "Site", "tier": 2, "name": "Open Ground", "desc": "Stretch the claim much farther.", "cost": 520, "scale": 1.85, "max": 5},
	{"id": "rock_pay", "cat": "Site", "tier": 2, "name": "Stone Bounty", "desc": "Nodules and crystals in stone pay more.", "cost": 280, "scale": 1.7, "max": 6},
	{"id": "money_mult", "cat": "Site", "tier": 2, "name": "Keen Eye", "desc": "Everything you dig is worth more.", "cost": 360, "scale": 1.75, "max": 6},
	{"id": "fossil_value", "cat": "Site", "tier": 2, "name": "Careful Hands", "desc": "Clean fossils sell for more.", "cost": 340, "scale": 1.75, "max": 6},
	{"id": "passive_miner", "cat": "Site", "tier": 3, "name": "Hired Hand", "desc": "A helper you can station on the claim before a shift. Placement comes later.", "unlock_name": "Hired Hand", "unlock_desc": "A helper you can station on the claim before a shift. Placement comes later.", "unlock_action": "Unlock", "cost": 4800, "scale": 1.0, "max": 1, "requires": ["rich_bed", "shovel_super"]},
	{"id": "lighting", "cat": "Exhibit", "tier": 1, "name": "Warm Lights", "desc": "The display earns more from visitors.", "cost": 110, "scale": 1.7, "max": 5},
	{"id": "benches", "cat": "Exhibit", "tier": 1, "name": "Benches", "desc": "Guests sit, linger, and donate.", "cost": 100, "scale": 1.65, "max": 5},
	{"id": "glass_case", "cat": "Exhibit", "tier": 2, "name": "Glass Case", "desc": "A better case adds a steady visitor bonus.", "cost": 280, "scale": 1.7, "max": 6},
	{"id": "labels", "cat": "Exhibit", "tier": 2, "name": "Clear Labels", "desc": "People stay longer and pay more.", "cost": 250, "scale": 1.7, "max": 6},
	{"id": "gift_shop", "cat": "Exhibit", "tier": 2, "name": "Gift Counter", "desc": "Small souvenirs raise income.", "cost": 400, "scale": 1.75, "max": 6},
	{"id": "crowds", "cat": "Exhibit", "tier": 3, "name": "Weekend Crowds", "desc": "More foot traffic every second.", "cost": 900, "scale": 1.8, "max": 6},
	{"id": "restoration", "cat": "Exhibit", "tier": 3, "name": "Cleanup Crew", "desc": "Dirty finds still look decent on display.", "cost": 500, "scale": 1.7, "max": 6},
]


func _ready() -> void:
	_bases = {
		"hands_click_mult": Tuning.hands_click_mult,
		"shovel_click_mult": Tuning.shovel_click_mult,
		"shovel_hold_tick_rate": Tuning.shovel_hold_tick_rate,
		"shovel_radius": Tuning.shovel_radius,
		"pickaxe_click_mult": Tuning.pickaxe_click_mult,
		"pickaxe_hold_tick_rate": Tuning.pickaxe_hold_tick_rate,
		"brush_clean_per_pixel": Tuning.brush_clean_per_pixel,
		"round_seconds": Tuning.base_round_seconds,
		"museum_income_mult": Tuning.museum_income_mult,
		"precision_damage_bonus": 0.0,
		"money_mult": Tuning.money_mult,
		"dirty_income_factor": 1.0,
		"exhibit_flat_income": 0.0,
		"dirt_money_bonus": 0.0,
		"rock_money_bonus": 0.0,
		"matrix_dirt_chance": 0.94,
		"matrix_stone_chance": 0.42,
		"fossil_value_mult": 1.0,
		"integrity_hit_cost": Tuning.integrity_hit_cost,
	}
	for item in catalog:
		levels[item["id"]] = 0
	apply_upgrades()


func _process(delta: float) -> void:
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
			hall_changed.emit()


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
	var roman: PackedStringArray = ["", "I", "II", "III"]
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
	if id.begins_with("pick") or id == "precision":
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
	var item: Dictionary = _item(id)
	if is_unlock_offer(id):
		return str(item["unlock_name"])
	return str(item.get("name", id))


func shop_item_desc(id: String) -> String:
	var item: Dictionary = _item(id)
	if is_unlock_offer(id) and item.has("unlock_desc"):
		return str(item["unlock_desc"])
	return str(item.get("desc", ""))


func shop_row_title(id: String) -> String:
	var item: Dictionary = _item(id)
	if is_unlock_offer(id):
		return shop_display_name(id)
	var level: int = int(levels.get(id, 0))
	var max_level: int = int(item.get("max", 1))
	return "%s    %d / %d" % [shop_display_name(id), level, max_level]


func shop_button_label(id: String) -> String:
	var item: Dictionary = _item(id)
	if is_unlock_offer(id):
		var action: String = str(item.get("unlock_action", "Buy"))
		if action == "Unlock":
			return "Unlock  $%d" % cost_of(id)
		return "Buy %s  $%d" % [str(item["unlock_name"]), cost_of(id)]
	return "Buy  $%d" % cost_of(id)


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
			return "Precision · 1 cell"
		Tuning.TOOL_SHOVEL:
			return "Dirt"
		Tuning.TOOL_PICKAXE:
			return "Stone"
		Tuning.TOOL_BRUSH:
			return "Fossil"
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
	var affordable_unlock: String = ""
	var affordable_rank: String = ""
	var cheapest_unlock: String = ""
	var cheapest_rank: String = ""
	var cheapest_unlock_cost: int = 1 << 30
	var cheapest_rank_cost: int = 1 << 30
	for item in catalog:
		var id: String = str(item["id"])
		if tool_for_upgrade(id) != filter_tool:
			continue
		if not requirements_met(id) or not tier_unlocked(id):
			continue
		if int(levels.get(id, 0)) >= int(item["max"]):
			continue
		var cost: int = cost_of(id)
		var is_new: bool = int(levels.get(id, 0)) <= 0 or is_unlock_offer(id)
		if can_buy(id):
			if is_new and affordable_unlock.is_empty():
				affordable_unlock = id
			elif not is_new and affordable_rank.is_empty():
				affordable_rank = id
		if is_new:
			if cost < cheapest_unlock_cost:
				cheapest_unlock_cost = cost
				cheapest_unlock = id
		elif cost < cheapest_rank_cost:
			cheapest_rank_cost = cost
			cheapest_rank = id
	if not affordable_unlock.is_empty():
		return affordable_unlock
	if not affordable_rank.is_empty():
		return affordable_rank
	if not cheapest_unlock.is_empty():
		return cheapest_unlock
	return cheapest_rank


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
	return PackedStringArray(["Next upgrade", next_goal_rank_name(id), "$%d" % cost])


func next_goal_chip_text(id: String, cost: int) -> String:
	return "Next upgrade · %s · $%d" % [next_goal_rank_name(id), cost]


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
	return id == "round_time" or id == "dirt_pay" or id == "site_size" or id == "scrap_bed" or id == "rich_bed" or id == "site_expand" or id == "rock_pay" or id == "money_mult" or id == "fossil_value" or id == "passive_miner"


func upgrade_feel_line(id: String) -> String:
	match id:
		"hands_click":
			return "Tougher fingers"
		"hands_hold":
			return "Hold to keep digging"
		"shovel_click":
			return "Heavier swings" if int(levels.get("shovel_click", 0)) > 1 else "You have a shovel"
		"shovel_hold":
			return "Faster shoveling"
		"shovel_radius":
			return "Wider scoop"
		"shovel_super":
			return "Super Shovel"
		"shovel_soft":
			return "Softer on bone"
		"pick_click":
			return "Harder strikes" if int(levels.get("pick_click", 0)) > 1 else "You have a pickaxe"
		"pick_hold":
			return "Faster picking"
		"pick_super":
			return "Super Pick"
		"pick_soft":
			return "Kinder to bone"
		"precision":
			return "Fine Point ready"
		"brush_speed":
			return "Faster dusting" if int(levels.get("brush_speed", 0)) > 1 else "You have a brush"
		"brush_master":
			return "Master Brush"
		"round_time":
			return "Clock starts fuller"
		"dirt_pay":
			return "Richer matrix"
		"site_size":
			return "The pit is bigger"
		"scrap_bed":
			return "More scraps in the bed"
		"rich_bed":
			return "Large bones can appear"
		"site_expand":
			return "The pit is bigger"
		"passive_miner":
			return "A helper is waiting"
		"rock_pay":
			return "Richer nodules"
		"money_mult":
			return "Everything is worth more"
		"fossil_value":
			return "Fossils sell for more"
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
	if tier <= 1:
		return "%s I" % cat
	if tier == 2:
		return "%s II" % cat
	return "%s III" % cat


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


func precision_unlocked() -> bool:
	return int(levels.get("precision", 0)) > 0


func apply_upgrades() -> void:
	var shovel_ranks: float = maxf(0.0, _lv("shovel_click") - 1.0)
	var pick_ranks: float = maxf(0.0, _lv("pick_click") - 1.0)
	var brush_ranks: float = maxf(0.0, _lv("brush_speed") - 1.0)
	Tuning.hands_click_mult = float(_bases["hands_click_mult"]) + 0.07 * _lv("hands_click")
	Tuning.shovel_click_mult = float(_bases["shovel_click_mult"]) + 0.20 * shovel_ranks + 0.32 * _lv("shovel_super")
	Tuning.shovel_hold_tick_rate = float(_bases["shovel_hold_tick_rate"]) + 0.55 * _lv("hands_hold") + 0.85 * _lv("shovel_hold") + 0.70 * _lv("shovel_super")
	# Unlock is one cell of reach (a plus). Rank 2 is a 3-wide scoop.
	# Old 0.40/rank stayed under 1.0 through rank 2, so neighbors were skipped.
	var scoop: float = _lv("shovel_radius")
	Tuning.shovel_radius = 0.0 if scoop <= 0.0 else (0.5 + 0.5 * scoop + 0.5 * _lv("shovel_super"))
	Tuning.pickaxe_click_mult = float(_bases["pickaxe_click_mult"]) + 0.16 * pick_ranks + 0.28 * _lv("pick_super")
	Tuning.pickaxe_hold_tick_rate = float(_bases["pickaxe_hold_tick_rate"]) + 0.45 * _lv("pick_hold") + 0.35 * _lv("pick_super")
	Tuning.brush_clean_per_pixel = float(_bases["brush_clean_per_pixel"]) + 0.00055 * brush_ranks + 0.0007 * _lv("brush_master")
	Tuning.round_seconds = float(_bases["round_seconds"]) + 6.0 * _lv("round_time")
	Tuning.museum_income_mult = float(_bases["museum_income_mult"]) + 0.20 * _lv("lighting") + 0.14 * _lv("labels") + 0.28 * _lv("gift_shop") + 0.40 * _lv("crowds")
	Tuning.precision_damage_bonus = 0.28 * maxf(0.0, _lv("precision") - 1.0)
	Tuning.money_mult = float(_bases["money_mult"]) + 0.06 * _lv("money_mult")
	Tuning.dirt_money_bonus = 0.35 * _lv("dirt_pay")
	Tuning.rock_money_bonus = 1.1 * _lv("rock_pay")
	Tuning.matrix_dirt_chance = float(_bases["matrix_dirt_chance"]) + 0.012 * _lv("dirt_pay")
	Tuning.matrix_stone_chance = float(_bases["matrix_stone_chance"]) + 0.055 * _lv("rock_pay")
	Tuning.fossil_value_mult = 1.0 + 0.08 * _lv("fossil_value")
	Tuning.exhibit_flat_income = 0.06 * _lv("glass_case") + 0.04 * _lv("benches") + 0.10 * _lv("crowds")
	Tuning.dirty_income_factor = 1.0 + 0.12 * _lv("restoration")
	Tuning.site_size_rank = int(_lv("site_size") + _lv("site_expand"))
	Tuning.extra_find_slots = int(_lv("scrap_bed") + _lv("rich_bed"))
	Tuning.extra_find_chance = 0.28 + 0.12 * _lv("scrap_bed") + 0.16 * _lv("rich_bed")
	Tuning.big_finds_unlocked = _lv("rich_bed") > 0.0
	Tuning.passive_miner_owned = _lv("passive_miner") > 0.0
	Tuning.integrity_hit_cost = maxf(0.035, float(_bases["integrity_hit_cost"]) - 0.018 * (_lv("shovel_soft") + _lv("pick_soft")))


func install_find(piece_id: String, display_name: String, cleanliness: float, clean: bool) -> String:
	if pieces.has(piece_id):
		var bonus := int(round(100.0 * Tuning.duplicate_cash * (0.5 + cleanliness * 0.5) * Tuning.fossil_value_mult))
		add_money(bonus)
		collection_changed.emit()
		return "Already on display. Extra copy sold for $%d." % bonus
	pieces[piece_id] = {
		"name": display_name,
		"cleanliness": cleanliness,
		"clean": clean,
	}
	if stand_for_piece(piece_id) != "":
		pending_unveils[piece_id] = true
	collection_changed.emit()
	hall_changed.emit()
	if clean:
		return "%s is now on display." % display_name
	return "%s is on display, but it still looks dusty." % display_name


func stand_for_piece(piece_id: String) -> String:
	if piece_id.is_empty():
		return ""
	match piece_id:
		"triceratops_skull":
			return STAND_TRICERATOPS
		_:
			return STAND_SMALL_FINDS


func stand_uses_exhibit_rate(stand_id: String) -> bool:
	return stand_id == STAND_T_REX or stand_id == STAND_TRICERATOPS or stand_id == STAND_BRACHIOSAURUS or stand_id == STAND_VELOCIRAPTOR or stand_id == STAND_STEGOSAURUS


func piece_blurb(piece_id: String) -> String:
	match piece_id:
		"tooth":
			return "A small tooth — first piece for the hall case."
		"vertebra":
			return "A vertebra for the Small Finds case."
		"triceratops_skull":
			return "A skull for the Triceratops bay."
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
	for piece_id in pending_unveils:
		if not bool(pending_unveils[piece_id]):
			continue
		var id: String = str(piece_id)
		if has_piece(id) and stand_for_piece(id) != "":
			return true
	return false


func piece_income(piece_id: String) -> float:
	if not has_piece(piece_id):
		return 0.0
	var piece: Dictionary = pieces[piece_id]
	var stand_id: String = stand_for_piece(piece_id)
	var clean: bool = bool(piece.get("clean", false))
	if stand_uses_exhibit_rate(stand_id):
		if clean:
			return Tuning.piece_income_exhibit
		return Tuning.piece_income_exhibit_dirty * Tuning.dirty_income_factor
	if clean:
		return Tuning.piece_income_clean
	return Tuning.piece_income_dirty * Tuning.dirty_income_factor


func stand_income(stand_id: String) -> float:
	var total: float = 0.0
	for piece_id in pieces:
		if stand_for_piece(str(piece_id)) != stand_id:
			continue
		total += piece_income(str(piece_id))
	if stand_id != "" and stand_id == featured_stand_id:
		total *= Tuning.spotlight_mult
	return total


func unveil_stand(stand_id: String) -> int:
	if not stand_has_pending_unveil(stand_id):
		return 0
	var burst: int = 0
	var waiting: Array[String] = []
	for piece_id in pieces:
		var id: String = str(piece_id)
		if stand_for_piece(id) != stand_id:
			continue
		if not bool(pending_unveils.get(id, false)):
			continue
		waiting.append(id)
		var piece: Dictionary = pieces[id]
		if bool(piece.get("clean", false)):
			burst += Tuning.unveil_burst_clean
		else:
			burst += Tuning.unveil_burst_dirty
	for id in waiting:
		pending_unveils.erase(id)
	unveil_spike_left = Tuning.unveil_spike_seconds
	if burst > 0:
		add_money(burst)
	collection_changed.emit()
	hall_changed.emit()
	return burst


func set_featured_stand(stand_id: String) -> bool:
	if not stand_is_filled(stand_id):
		return false
	featured_stand_id = stand_id
	hall_changed.emit()
	collection_changed.emit()
	return true


func museum_income() -> float:
	var total: float = Tuning.exhibit_flat_income
	for piece_id in pieces:
		var rate: float = piece_income(str(piece_id))
		if stand_for_piece(str(piece_id)) == featured_stand_id and featured_stand_id != "":
			rate *= Tuning.spotlight_mult
		total += rate
	total *= Tuning.museum_income_mult
	if unveil_spike_left > 0.0:
		total *= Tuning.unveil_spike_mult
	return total


func has_piece(piece_id: String) -> bool:
	return pieces.has(piece_id)


func _lv(id: String) -> float:
	return float(levels.get(id, 0))


func _item(id: String) -> Dictionary:
	for item in catalog:
		if str(item["id"]) == id:
			return item
	return {}


func has_save(path: String = SAVE_PATH) -> bool:
	return FileAccess.file_exists(path)


func save_game(path: String = SAVE_PATH) -> bool:
	var data := {
		"version": SAVE_VERSION,
		"money": money,
		"levels": levels.duplicate(),
		"pieces": pieces.duplicate(true),
		"precision_on": precision_on,
		"featured_stand_id": featured_stand_id,
		"pending_unveils": pending_unveils.duplicate(),
		"pending_notices": pending_notices.duplicate(true),
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
	for item in catalog:
		var id: String = str(item["id"])
		levels[id] = int(raw_levels.get(id, 0))
	pieces.clear()
	var raw_pieces: Dictionary = data.get("pieces", {})
	for raw_id in raw_pieces:
		var piece_id: String = str(raw_id)
		var piece: Dictionary = raw_pieces[raw_id]
		pieces[piece_id] = {
			"name": str(piece.get("name", piece_id)),
			"cleanliness": float(piece.get("cleanliness", 0.0)),
			"clean": bool(piece.get("clean", false)),
		}
	precision_on = bool(data.get("precision_on", false))
	featured_stand_id = str(data.get("featured_stand_id", ""))
	pending_unveils.clear()
	var raw_unveils: Dictionary = data.get("pending_unveils", {})
	for raw_id in raw_unveils:
		if bool(raw_unveils[raw_id]):
			pending_unveils[str(raw_id)] = true
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
