class_name LuckyStrike
extends RefCounted

## Mid-shift glint in the matrix. Cash burst only — no hired diggers.


static func plan_shift(rng: RandomNumberGenerator, round_seconds: float) -> PackedFloat32Array:
	var times := PackedFloat32Array()
	if rng.randf() > Tuning.lucky_shift_chance:
		return times
	var duration: float = Tuning.lucky_duration
	var earliest: float = Tuning.lucky_first_delay_min
	var latest: float = maxf(earliest + 0.5, round_seconds - duration - 1.0)
	if latest <= earliest:
		return times
	var first: float = rng.randf_range(earliest, latest)
	times.append(first)
	if times.size() >= Tuning.lucky_max_per_shift:
		return times
	if rng.randf() >= Tuning.lucky_second_chance:
		return times
	var second_min: float = first + duration + 2.0
	if second_min >= latest:
		return times
	times.append(rng.randf_range(second_min, latest))
	return times


static func pick_cell(rng: RandomNumberGenerator, grid_w: int, grid_h: int, blocked: Array = []) -> Vector2i:
	var open: Array[Vector2i] = []
	for x in grid_w:
		for y in grid_h:
			var cell := Vector2i(x, y)
			if blocked.has(cell):
				continue
			open.append(cell)
	if open.is_empty():
		return Vector2i(-1, -1)
	return open[rng.randi_range(0, open.size() - 1)]


static func burst_payout(base_money: int) -> int:
	return maxi(12, base_money * Tuning.lucky_burst_mult)


static func toast_title() -> String:
	return "Glint in the matrix"


static func float_text(amount: int) -> String:
	return "+$%d" % amount


static func icon_kind() -> String:
	return "glint"


static func can_hit_with(tool: int) -> bool:
	return tool == Tuning.TOOL_HANDS or tool == Tuning.TOOL_SHOVEL or tool == Tuning.TOOL_PICKAXE


static func miss_payout() -> int:
	return 0
