class_name MatrixFind
extends RefCounted

## Junk screened out of a popped layer. This is the money — not a dirt sale.

const RARITY_COMMON := 0
const RARITY_UNCOMMON := 1
const RARITY_RARE := 2
const DIRT_COMMON: PackedStringArray = ["shell hash", "pebble", "fish scale", "rust flake", "seed"]
const DIRT_UNCOMMON: PackedStringArray = ["tiny toothlet", "glassy chip", "bone flake", "pyrite fleck"]
const DIRT_RARE: PackedStringArray = ["amber speck", "opal flake", "enamel chip"]
const STONE_UNCOMMON: PackedStringArray = ["nodule", "geode crumb", "crystal shard"]
const STONE_RARE: PackedStringArray = ["quartz nodule", "calcite crystal", "ironstone nodule"]


static func roll(rng: RandomNumberGenerator, layer: int, tool: int = -1) -> Dictionary:
	if tool < 0:
		tool = Tuning.TOOL_HANDS
	var material: int = Tuning.material_at_layer(layer)
	var chance: float = pop_chance(material)
	if rng.randf() > chance:
		return {}
	var rarity: int = _roll_rarity(rng, material, tool)
	var name: String = _pick_name(rng, material, rarity)
	var amount: int = payout_for(layer, rarity, chance, tool)
	if amount <= 0:
		return {}
	return {
		"name": name,
		"amount": amount,
		"rarity": rarity,
	}


static func harvest(find: Dictionary, layer: int, tool: int) -> Dictionary:
	if find.is_empty():
		return {}
	var harvested: Dictionary = find.duplicate()
	var material: int = Tuning.material_at_layer(layer)
	if _is_clear_tool(tool):
		harvested["rarity"] = RARITY_COMMON
		harvested["name"] = _spoil_name(str(find.get("name", "")), material)
		harvested["amount"] = _clear_payout(int(find.get("amount", 0)))
	else:
		harvested["amount"] = maxi(1, int(round(float(find.get("amount", 0)) * maxf(Tuning.matrix_hands_pay, 0.25))))
	if int(harvested.get("amount", 0)) <= 0:
		return {}
	return harvested


static func pop_chance(material: int) -> float:
	if material <= Tuning.MAT_PACKED:
		return clampf(Tuning.matrix_dirt_chance, 0.05, 1.0)
	return clampf(Tuning.matrix_stone_chance, 0.05, 0.85)


static func payout_for(layer: int, rarity: int, chance: float, tool: int = -1) -> int:
	if tool < 0:
		tool = Tuning.TOOL_HANDS
	var base: float = float(Tuning.money_for_layer(layer))
	var rmult: float = 0.78
	match clampi(rarity, RARITY_COMMON, RARITY_RARE):
		RARITY_UNCOMMON:
			rmult = 1.35 if Tuning.material_at_layer(layer) <= Tuning.MAT_PACKED else 1.05
		RARITY_RARE:
			rmult = 2.55 if Tuning.material_at_layer(layer) <= Tuning.MAT_PACKED else 2.0
	var tool_mult: float = Tuning.matrix_clear_pay if _is_clear_tool(tool) else maxf(Tuning.matrix_hands_pay, 0.25)
	return maxi(1, int(round(base * rmult * tool_mult / maxf(chance, 0.25))))


static func float_text(find: Dictionary) -> String:
	return "+$%d" % int(find.get("amount", 0))


static func icon_kind(find_or_name: Variant) -> String:
	var key: String = str(find_or_name).to_lower()
	if find_or_name is Dictionary:
		key = str((find_or_name as Dictionary).get("name", "")).to_lower()
	if key.find("glint") >= 0:
		return "glint"
	if key.find("shell") >= 0:
		return "shell"
	if key.find("pebble") >= 0:
		return "pebble"
	if key.find("scale") >= 0:
		return "scale"
	if key.find("seed") >= 0:
		return "seed"
	if key.find("toothlet") >= 0 or key.find("enamel") >= 0:
		return "speck"
	if key.find("pyrite") >= 0:
		return "sparkle"
	if key.find("amber") >= 0:
		return "amber"
	if key.find("opal") >= 0:
		return "opal"
	if key.find("crystal") >= 0 or key.find("quartz") >= 0 or key.find("calcite") >= 0:
		return "crystal"
	if key.find("nodule") >= 0 or key.find("geode") >= 0 or key.find("ironstone") >= 0:
		return "nodule"
	if key.find("chip") >= 0 or key.find("flake") >= 0 or key.find("fleck") >= 0 or key.find("rust") >= 0:
		return "flake"
	return "pebble"


static func tell_strength(rarity: int) -> float:
	match clampi(rarity, RARITY_COMMON, RARITY_RARE):
		RARITY_UNCOMMON:
			return 0.48
		RARITY_RARE:
			return 0.82
		_:
			return 0.16


static func icon_color(kind: String, rarity: int = RARITY_COMMON) -> Color:
	match kind:
		"shell":
			return Color("D8B48A")
		"scale":
			return Color("8FBE8A")
		"seed":
			return Color("7A5A32")
		"speck":
			return Color("C9B08A")
		"sparkle", "glint":
			return Color("FFE08A")
		"amber":
			return Color("E09030")
		"opal":
			return Color("B8D4E8")
		"crystal":
			return Color("D4EEF6")
		"nodule":
			return Color("8A8680")
		"flake":
			return Color("C47A3A") if rarity <= RARITY_COMMON else Color("C8B090")
		_:
			return Color("9A7A52")


static func draw_icon(c: CanvasItem, kind: String, center: Vector2, radius: float, alpha: float = 1.0, rarity: int = RARITY_COMMON) -> void:
	var color: Color = icon_color(kind, rarity)
	color.a = clampf(alpha, 0.0, 1.0)
	var ink := Color(0.14, 0.1, 0.07, color.a * 0.85)
	match kind:
		"shell":
			c.draw_arc(center, radius, 0.35, PI + 0.35, 14, color, maxf(1.6, radius * 0.42))
			c.draw_arc(center + Vector2(radius * 0.15, radius * 0.08), radius * 0.62, 0.5, PI + 0.1, 10, ink, 1.2)
		"scale":
			var tip := center + Vector2(0, -radius)
			var left := center + Vector2(-radius * 0.85, radius * 0.55)
			var right := center + Vector2(radius * 0.85, radius * 0.55)
			c.draw_colored_polygon(PackedVector2Array([tip, right, left]), color)
		"seed":
			c.draw_circle(center + Vector2(0, radius * 0.15), radius * 0.72, color)
			c.draw_circle(center + Vector2(0, -radius * 0.35), radius * 0.38, color)
		"speck":
			c.draw_circle(center, radius * 0.55, color)
			c.draw_circle(center + Vector2(radius * 0.28, -radius * 0.12), radius * 0.28, color.lightened(0.2))
		"sparkle", "glint":
			c.draw_line(center + Vector2(-radius, 0), center + Vector2(radius, 0), color, 1.8)
			c.draw_line(center + Vector2(0, -radius), center + Vector2(0, radius), color, 1.8)
			c.draw_line(center + Vector2(-radius * 0.6, -radius * 0.6), center + Vector2(radius * 0.6, radius * 0.6), color, 1.2)
			c.draw_circle(center, radius * 0.28, Color("FFF6D0", color.a))
		"amber":
			c.draw_circle(center, radius * 0.85, color)
			c.draw_circle(center + Vector2(-radius * 0.2, -radius * 0.18), radius * 0.28, Color("FFD078", color.a))
		"opal":
			c.draw_circle(center, radius * 0.8, color)
			c.draw_circle(center + Vector2(radius * 0.18, -radius * 0.12), radius * 0.28, Color("E8F6FF", color.a))
		"crystal":
			var peak := center + Vector2(0, -radius)
			var base_l := center + Vector2(-radius * 0.7, radius * 0.7)
			var base_r := center + Vector2(radius * 0.7, radius * 0.7)
			c.draw_colored_polygon(PackedVector2Array([peak, base_r, base_l]), color)
		"nodule":
			c.draw_circle(center, radius * 0.8, color)
			c.draw_circle(center + Vector2(radius * 0.35, radius * 0.1), radius * 0.42, color.darkened(0.12))
			c.draw_circle(center + Vector2(-radius * 0.28, -radius * 0.18), radius * 0.32, color.lightened(0.12))
		"flake":
			var a := center + Vector2(-radius * 0.8, -radius * 0.2)
			var b := center + Vector2(radius * 0.7, -radius * 0.55)
			var d := center + Vector2(radius * 0.55, radius * 0.5)
			var e := center + Vector2(-radius * 0.45, radius * 0.35)
			c.draw_colored_polygon(PackedVector2Array([a, b, d, e]), color)
		_:
			c.draw_circle(center, radius * 0.78, color)
			c.draw_circle(center + Vector2(radius * 0.18, -radius * 0.16), radius * 0.28, color.lightened(0.18))


static func batch_leftover(finds: Array, max_floats: int = 5) -> int:
	var shown: int = 0
	for raw in batch_display(finds, max_floats):
		shown += int(raw.get("amount", 0))
	var total: int = 0
	for raw in finds:
		if raw is Dictionary:
			total += int((raw as Dictionary).get("amount", 0))
	return maxi(0, total - shown)


static func batch_display(finds: Array, max_floats: int = 5) -> Array:
	if finds.is_empty():
		return []
	var sorted: Array = []
	for raw in finds:
		if raw is Dictionary and int(raw.get("amount", 0)) > 0:
			sorted.append((raw as Dictionary).duplicate())
	if sorted.is_empty():
		return []
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ra: int = int(a.get("rarity", 0))
		var rb: int = int(b.get("rarity", 0))
		if ra != rb:
			return ra > rb
		return int(a.get("amount", 0)) > int(b.get("amount", 0))
	)
	var juice: Array = []
	var cap: int = clampi(max_floats, 3, 5)
	for i in sorted.size():
		if juice.size() >= cap:
			break
		juice.append(sorted[i])
	return juice


static func _is_clear_tool(tool: int) -> bool:
	return tool == Tuning.TOOL_SHOVEL or tool == Tuning.TOOL_PICKAXE


static func _clear_payout(amount: int) -> int:
	var spoil: int = maxi(1, int(round(float(maxi(amount, 0)) * clampf(Tuning.matrix_clear_pay, 0.15, 0.85))))
	if spoil >= amount and amount > 1:
		return amount - 1
	return spoil


static func _spoil_name(original: String, material: int) -> String:
	var key: String = original.to_lower()
	if material > Tuning.MAT_PACKED:
		return "nodule"
	for name in DIRT_COMMON:
		if key == name:
			return original
	return "pebble"


static func _roll_rarity(rng: RandomNumberGenerator, material: int, tool: int = -1) -> int:
	if tool < 0:
		tool = Tuning.TOOL_HANDS
	if _is_clear_tool(tool):
		return RARITY_COMMON
	var pick: float = rng.randf()
	var quality: float = clampf(Tuning.matrix_hands_quality, 0.0, 0.55)
	if material > Tuning.MAT_PACKED:
		return RARITY_RARE if pick < 0.20 + quality * 0.28 else RARITY_UNCOMMON
	if pick < 0.05 + quality * 0.12:
		return RARITY_RARE
	if pick < 0.28 + quality * 0.22:
		return RARITY_UNCOMMON
	return RARITY_COMMON


static func _pick_name(rng: RandomNumberGenerator, material: int, rarity: int) -> String:
	var pool: PackedStringArray = DIRT_COMMON
	if material > Tuning.MAT_PACKED:
		pool = STONE_RARE if rarity >= RARITY_RARE else STONE_UNCOMMON
	elif rarity >= RARITY_RARE:
		pool = DIRT_RARE
	elif rarity == RARITY_UNCOMMON:
		pool = DIRT_UNCOMMON
	if pool.is_empty():
		return "pebble"
	return pool[rng.randi_range(0, pool.size() - 1)]
