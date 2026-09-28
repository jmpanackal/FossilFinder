extends Node

## Every gameplay number lives here so feel can be tuned in one place.

const TOOL_SHOVEL := 0
const TOOL_PICKAXE := 1
const TOOL_BRUSH := 2
const TOOL_HANDS := 3
const TOOL_NAMES: PackedStringArray = ["SHOVEL", "PICKAXE", "BRUSH", "HANDS"]


func hotkey_for_tool(tool: int) -> String:
	match tool:
		TOOL_HANDS:
			return "1"
		TOOL_SHOVEL:
			return "2"
		TOOL_PICKAXE:
			return "3"
		TOOL_BRUSH:
			return "4"
		_:
			return ""


func hud_rail_w() -> float:
	return 184.0

const MAT_LOOSE := 0
const MAT_PACKED := 1
const MAT_CLAY := 2
const MAT_ROCK := 3
const MAT_NAMES := ["Loose dirt", "Packed dirt", "Clay", "Soft rock"]

var base_grid_w: int = 5
var base_grid_h: int = 4
var base_cell_w: float = 64.0
var base_cell_h: float = 40.0
var grid_w: int = 5
var grid_h: int = 4
var site_size_rank: int = 0
var extra_find_slots: int = 0
var extra_find_chance: float = 0.0
var main_fossil_paths: PackedStringArray = [
	"res://t_rex_tooth.tres",
	"res://t_rex_jaw.tres",
	"res://t_rex_femur.tres",
	"res://t_rex_ribcage.tres",
	"res://t_rex_tail.tres",
	"res://t_rex_skull.tres",
	"res://triceratops_tooth.tres",
	"res://triceratops_vertebra.tres",
	"res://triceratops_nose_horn.tres",
	"res://triceratops_brow_horns.tres",
	"res://triceratops_hind_limb.tres",
	"res://triceratops_tail.tres",
	"res://triceratops_skull.tres",
	"res://stegosaurus_foot.tres",
	"res://stegosaurus_plate.tres",
	"res://stegosaurus_femur.tres",
	"res://stegosaurus_thagomizer.tres",
	"res://stegosaurus_torso.tres",
	"res://stegosaurus_skull.tres",
	"res://velociraptor_claw.tres",
	"res://velociraptor_skull.tres",
	"res://velociraptor_femur.tres",
	"res://velociraptor_tail.tres",
	"res://velociraptor_ribs.tres",
	"res://brachiosaurus_tooth.tres",
	"res://brachiosaurus_tail.tres",
	"res://brachiosaurus_skull.tres",
	"res://brachiosaurus_humerus.tres",
	"res://brachiosaurus_femur.tres",
	"res://brachiosaurus_neck.tres",
]
var extra_fossil_paths: PackedStringArray = [
	"res://trilobite.tres",
	"res://amber_insect.tres",
	"res://cycad.tres",
	"res://fossil_flower.tres",
]
var big_finds_unlocked: bool = false
var passive_miner_owned: bool = false
var lucky_shift_chance: float = 0.70
var lucky_second_chance: float = 0.35
var lucky_first_delay_min: float = 6.0
var lucky_duration: float = 8.0
var lucky_max_per_shift: int = 2
var lucky_burst_mult: int = 16
## Rank 0 is a small search pit (20 cells). Later ranks grow toward the old 16×10 site.
var site_layouts: Array[Vector2i] = [
	Vector2i(5, 4),
	Vector2i(6, 4),
	Vector2i(8, 5),
	Vector2i(10, 6),
	Vector2i(11, 7),
	Vector2i(12, 8),
	Vector2i(13, 8),
	Vector2i(14, 9),
	Vector2i(16, 10),
]
var layer_count: int = 24
var meters_per_layer: float = 0.5

var cell_w: float = 64.0
var cell_h: float = 40.0
var cell_gap: float = 3.0
var base_wall_per_layer: float = 2.2
var wall_per_layer: float = 2.2
var front_lip: float = 10.0
var chunk_pad: float = 18.0
var chunk_front: float = 64.0
var cell_side: float = 12.0
var cell_line: Color = Color("241C16")
var grid_origin := Vector2(128, 86)
const DESIGN_W := 1280.0
const DESIGN_H := 720.0
var view_w: float = 1280.0
var view_h: float = 720.0
var hud_h: float = 96.0
var find_bar_h: float = 130.0
var fossil_grace: float = 0.55
var fossil_hold_tick_rate: float = 1.6
var base_round_seconds: float = 40.0

var material_hp := [1.0, 3.0, 7.0, 14.0]
var material_money := [1, 2, 4, 8]
var material_colors := [
	Color("C4A36A"),
	Color("8B5E34"),
	Color("B85C38"),
	Color("8A8680"),
]
var material_particle_colors := [
	Color("E6C48A"),
	Color("A56E3C"),
	Color("D46A42"),
	Color("C8C4BE"),
]
var depth_darken: float = 0.028

## Rows = tools (shovel, pickaxe, brush). Columns = materials.
## Pickaxe is weak on dirt so one click cannot farm the surface.
var damage_matrix := [
	[1.6, 1.2, 0.16, 0.05],
	[0.40, 0.65, 4.2, 8.0],
	[0.0, 0.0, 0.0, 0.0],
]

var shovel_radius: float = 0.0
var brush_clean_per_pixel: float = 0.0015
## Bristle reach in pixels past the aimed cell. 0 = one cell.
var brush_reach_px: float = 0.0
var brush_splash: float = 0.6
## Hands feel for bone (Bone Sense upgrade): cells within this radius that
## hide an unexposed fossil get marked. 0 = not owned.
var hands_sense_radius: float = 0.0

## Click vs hold. Later upgrades can raise one path without touching the other.
var hands_click_mult: float = 0.40
var hands_hold_mult: float = 0.85
var shovel_click_mult: float = 0.70
var shovel_hold_mult: float = 1.0
var shovel_hold_tick_rate: float = 2.4
var pickaxe_click_mult: float = 0.85
var pickaxe_hold_mult: float = 1.0
var pickaxe_hold_tick_rate: float = 1.8
var pickaxe_splash_mult: float = 0.7
var pickaxe_radius: float = 1.0
## Floor so max Steady Shoveling stays snappy without 60 ticks/sec.
var hold_min_interval: float = 0.065

var round_seconds: float = 40.0
## Tools never break bone. Kept at 0 so old callers read "no damage".
var integrity_hit_cost: float = 0.0
var hands_integrity_mult: float = 0.0
var integrity_floor: float = 0.25
var unbrushed_value: float = 0.5
## Wiping dust: a bone counts as clean once this much of it is uncovered.
var clean_extract_threshold: float = 0.96

var shake_enabled: bool = true
var shake_strength: float = 8.0
var shake_time: float = 0.18

var fossil_path: String = "res://triceratops_skull.tres"
var precision_damage_bonus: float = 0.0
var money_mult: float = 1.0
var museum_income_mult: float = 1.0
var piece_income_clean: float = 0.08
var piece_income_dirty: float = 0.03
var piece_income_exhibit: float = 0.09
var piece_income_exhibit_dirty: float = 0.035
var dirty_income_factor: float = 1.0
var exhibit_flat_income: float = 0.0
var donation_base: float = 0.02
var donation_mult: float = 1.0
var donation_flat: float = 0.0
var visitor_flat: int = 0
var visitor_draw_scrap_clean: int = 4
var visitor_draw_scrap_dirty: int = 2
var visitor_draw_exhibit_clean: int = 5
var visitor_draw_exhibit_dirty: int = 2
var unveil_surge_visitors: int = 8
var duplicate_cash: float = 0.4
var set_complete_sale_mult: float = 2.0
## Finishing every piece of a stand: permanent visitor multiplier + lump sum.
var complete_stand_mult: float = 2.0
var skeleton_bonus_mult: float = 2.0
## Masterpiece: complete stand, every piece at least this condition (4 = Great).
var masterpiece_min_condition: int = 4
var masterpiece_mult: float = 1.5
var masterpiece_bonus_mult: float = 2.0
## Repair Workshop never repairs past this condition (Perfect only comes from the ground).
var workshop_max_condition: int = 4
var extra_complete_set_chance: float = 0.22
var dirt_money_bonus: float = 0.0
var rock_money_bonus: float = 0.0
var matrix_dirt_chance: float = 0.48
var matrix_stone_chance: float = 0.55
var matrix_hands_quality: float = 0.0
var matrix_hands_pay: float = 1.0
var matrix_clear_pay: float = 0.50
var fossil_value_mult: float = 1.0
var spotlight_mult: float = 1.0
var unveil_burst_clean: int = 40
var unveil_burst_dirty: int = 18
var unveil_spike_seconds: float = 24.0
var unveil_spike_mult: float = 2.0
var unveil_rush_stack_cap: int = 5
var unveil_rush_strength: float = 1.0

## Condition: how well a bone survived in the ground. Rolled when the pit is
## made, hidden until the bone is fully uncovered. 1 = Poor ... 5 = Perfect.
const CONDITION_POOR := 1
const CONDITION_GOOD := 3
const CONDITION_PERFECT := 5
const CONDITION_NAMES: PackedStringArray = ["Poor", "Fair", "Good", "Great", "Perfect"]
## Plain-language explanation shown in hints, so no one needs the jargon.
const CONDITION_HINT := "Condition is how well a bone survived in the ground. Better condition sells for more and draws more museum visitors."
var condition_weights: PackedFloat32Array = [14.0, 26.0, 32.0, 20.0, 8.0]
## Each point shifts the odds toward better-condition bones.
var condition_luck: float = 0.0
var condition_value_mult: PackedFloat32Array = [0.5, 0.75, 1.0, 1.4, 2.0]
var condition_visitor_mult: PackedFloat32Array = [0.5, 0.75, 1.0, 1.5, 2.0]
## Brush: dust on each bone cell is a small grid wiped where the brush passes.
const DUST_COLS := 8
const DUST_ROWS := 5
var brush_radius_frac: float = 0.24
## Layers of dirt caked on a bone, by how deep it was buried.
var dust_layers_by_material: PackedInt32Array = [3, 3, 4, 5]
## Dirt one brush pass lifts per layer: starter brush = half a layer.
var brush_base_strength: float = 0.5
var brush_max_strength: float = 1.5
## A click without moving lifts this share of a pass.
var brush_dab: float = 0.12


## Bone kinds. Most bones are solid; some crumble once they meet open air.
const BONE_SOLID := 0
const BONE_FRAGILE := 1
const BONE_OPAL := 2
const BONE_KIND_NAMES: PackedStringArray = ["Solid", "Fragile", "Opal"]
## Plain-language one-liners shown the first time each kind turns up.
const BONE_KIND_HINTS: PackedStringArray = [
	"",
	"It dries out in open air: loses a star every 10s once uncovered. Dig it out and brush it fast.",
	"Bone that turned into opal, a rainbow gemstone. Worth 2.5x, but it cracks as it dries: loses a star every 6s once uncovered.",
]
var bone_kind_weights: PackedFloat32Array = [74.0, 20.0, 6.0]
## Seconds in open air before the first crumble, then between crumbles.
var crumble_first: PackedFloat32Array = [0.0, 12.0, 6.0]
var crumble_step: PackedFloat32Array = [0.0, 10.0, 6.0]
var bone_kind_value: PackedFloat32Array = [1.0, 1.0, 2.5]
## Plaster Cast: seconds of holding Hands on a dug-out bone to wrap it, by rank.
var cast_hold_by_rank: PackedFloat32Array = [1.4, 1.0, 0.6]
var cast_rank: int = 0


func bone_kind_name(kind: int) -> String:
	return BONE_KIND_NAMES[clampi(kind, 0, BONE_KIND_NAMES.size() - 1)]


func bone_crumbles(kind: int) -> bool:
	return kind == BONE_FRAGILE or kind == BONE_OPAL


func roll_bone_kind(rng: RandomNumberGenerator = null) -> int:
	var total: float = 0.0
	for w in bone_kind_weights:
		total += w
	var roll: float = (rng.randf() if rng != null else randf()) * total
	for i in bone_kind_weights.size():
		roll -= bone_kind_weights[i]
		if roll <= 0.0:
			return i
	return BONE_SOLID


## How many crumbles a bone of this kind has taken after `seconds` in open air.
func crumbles_after(kind: int, seconds: float) -> int:
	if not bone_crumbles(kind) or seconds < crumble_first[kind]:
		return 0
	return 1 + int(floor((seconds - crumble_first[kind]) / maxf(crumble_step[kind], 0.1)))


func seconds_to_next_crumble(kind: int, seconds: float) -> float:
	if not bone_crumbles(kind):
		return INF
	if seconds < crumble_first[kind]:
		return crumble_first[kind] - seconds
	var into: float = fmod(seconds - crumble_first[kind], maxf(crumble_step[kind], 0.1))
	return crumble_step[kind] - into


func cast_owned() -> bool:
	return cast_rank > 0


func cast_hold_seconds() -> float:
	if cast_rank <= 0:
		return INF
	return cast_hold_by_rank[clampi(cast_rank, 1, cast_hold_by_rank.size()) - 1]


func dust_layers_for(layer: int) -> int:
	return dust_layers_by_material[material_at_layer(layer)]


func condition_name(condition: int) -> String:
	return CONDITION_NAMES[clampi(condition, 1, 5) - 1]


func condition_label(condition: int) -> String:
	return "%s condition" % condition_name(condition)


func condition_value(condition: int) -> float:
	return condition_value_mult[clampi(condition, 1, 5) - 1]


func condition_visitors(condition: int) -> float:
	return condition_visitor_mult[clampi(condition, 1, 5) - 1]


func condition_odds(luck: float = -1.0) -> PackedFloat32Array:
	## Luck tilts weight from Poor/Fair toward Great/Perfect.
	var l: float = condition_luck if luck < 0.0 else luck
	var odds := PackedFloat32Array()
	var total: float = 0.0
	for i in condition_weights.size():
		var w: float = condition_weights[i] * pow(1.0 + l, float(i - 2))
		odds.append(w)
		total += w
	for i in odds.size():
		odds[i] = odds[i] / maxf(total, 0.001)
	return odds


func roll_condition(rng: RandomNumberGenerator = null) -> int:
	var roll: float = rng.randf() if rng != null else randf()
	var odds := condition_odds()
	for i in odds.size():
		roll -= odds[i]
		if roll <= 0.0:
			return i + 1
	return CONDITION_PERFECT


func great_or_better_chance(luck: float = -1.0) -> float:
	var odds := condition_odds(luck)
	return odds[3] + odds[4]


## Stars and grade text come from condition (1..5).
func preservation_stars(condition: float, _cleanliness: float = 1.0) -> int:
	return clampi(int(round(condition)), 1, 5)


func preservation_grade(condition: float, _cleanliness: float = 1.0) -> String:
	return condition_label(preservation_stars(condition))


func dirt_label(cleanliness: float) -> String:
	var clean := clampf(cleanliness, 0.0, 1.0)
	var pct: int = 100 if clean >= 0.99 else int(round(clean * 100.0))
	return "Brushed %d%%" % pct


func summary_dirt_line(cleanliness: float, _owns_brush: bool) -> String:
	if cleanliness >= 0.99:
		return ""
	return "still dirty"


func material_at_layer(layer: int) -> int:
	if layer <= 5:
		return MAT_LOOSE
	if layer <= 11:
		return MAT_PACKED
	if layer <= 17:
		return MAT_CLAY
	return MAT_ROCK


func hp_for_layer(layer: int) -> float:
	return float(material_hp[material_at_layer(layer)])


func money_for_layer(layer: int) -> int:
	## Expected matrix-find value for this layer, not a dirt/rock sale.
	var material := material_at_layer(layer)
	var amount := float(material_money[material])
	if material <= MAT_PACKED:
		amount += dirt_money_bonus
	else:
		amount += rock_money_bonus
	return int(round(amount * money_mult))


var _layer_colors: PackedColorArray = PackedColorArray()


func color_for_layer(layer: int) -> Color:
	## Called per cell per redraw; the ramp only depends on layer_count.
	if _layer_colors.size() != layer_count:
		_layer_colors.resize(layer_count)
		for i in layer_count:
			_layer_colors[i] = _layer_color_uncached(i)
	return _layer_colors[clampi(layer, 0, layer_count - 1)]


func _layer_color_uncached(layer: int) -> Color:
	## Per-layer steps in two job families: warm shovel dirt, then cool pick stone.
	var idx: int = clampi(layer, 0, layer_count - 1)
	if idx <= 11:
		return _ramp_color(idx, 0, 11, [
			Color("C4A36A"),
			Color("A07840"),
			Color("7A4A28"),
		])
	return _ramp_color(idx, 12, layer_count - 1, [
		Color("6A7484"),
		Color("4A5666"),
		Color("2A3848"),
	])


func _ramp_color(layer: int, from_layer: int, to_layer: int, stops: PackedColorArray) -> Color:
	var span: int = maxi(to_layer - from_layer, 1)
	var t: float = clampf(float(layer - from_layer) / float(span), 0.0, 1.0)
	var scaled: float = t * float(stops.size() - 1)
	var i: int = clampi(int(floor(scaled)), 0, stops.size() - 2)
	return stops[i].lerp(stops[i + 1], scaled - float(i))


func tool_works_on(tool: int, layer: int) -> bool:
	var material: int = material_at_layer(layer)
	if tool == TOOL_SHOVEL or tool == TOOL_HANDS:
		return material <= MAT_PACKED
	if tool == TOOL_PICKAXE:
		return material >= MAT_CLAY
	return false


func particle_color_for_layer(layer: int) -> Color:
	return material_particle_colors[material_at_layer(layer)]


func damage_for(tool: int, layer: int) -> float:
	return float(damage_matrix[tool][material_at_layer(layer)])


func site_layout_for_rank(rank: int) -> Vector2i:
	if site_layouts.is_empty():
		return Vector2i(base_grid_w, base_grid_h)
	var idx: int = clampi(rank, 0, site_layouts.size() - 1)
	return site_layouts[idx]


func spawn_max_cells_for_rank(rank: int) -> int:
	var r: int = maxi(rank, 0)
	if r <= 0:
		return 1
	if r == 1:
		return 3
	if r == 2:
		return 6
	if r == 3:
		return 8
	if r == 4:
		return 10
	if r == 5:
		return 12
	if r == 6:
		return 14
	return 18


func spawn_max_box_for_rank(rank: int) -> Vector2i:
	var r: int = maxi(rank, 0)
	if r <= 0:
		return Vector2i(1, 1)
	if r == 1:
		return Vector2i(3, 2)
	if r == 2:
		return Vector2i(4, 3)
	if r == 3:
		return Vector2i(5, 4)
	if r == 4:
		return Vector2i(6, 5)
	if r == 5:
		return Vector2i(7, 5)
	if r == 6:
		return Vector2i(8, 6)
	return Vector2i(10, 7)


func piece_can_spawn(data: FossilData, rank: int, rich_bed: bool) -> bool:
	if data == null:
		return false
	var cells: int = data.occupied_cells()
	if cells <= 0:
		return false
	var box: Vector2i = data.bounding_size()
	if cells > spawn_max_cells_for_rank(rank):
		return false
	var cap: Vector2i = spawn_max_box_for_rank(rank)
	if box.x > cap.x or box.y > cap.y:
		return false
	var pit: Vector2i = site_layout_for_rank(rank)
	if box.x > pit.x or box.y > pit.y:
		return false
	if box.x >= pit.x and box.y >= pit.y:
		return false
	if rank < data.min_rank:
		return false
	if data.needs_rich_bed or data.is_skull() or cells >= 6:
		return rich_bed
	return true


func reference_pit_size() -> Vector2:
	var max_layout: Vector2i = Vector2i(16, 10)
	if not site_layouts.is_empty():
		max_layout = site_layouts[site_layouts.size() - 1]
	return Vector2(float(max_layout.x) * base_cell_w, float(max_layout.y) * base_cell_h)


func play_view_size(visible: Vector2) -> Vector2:
	## Content-scale expand grows one axis. Raw window pixels scale both
	## (1080p is exactly 1.5x 1280×720) and must not become the pit world.
	if visible.x < DESIGN_W * 0.5 or visible.y < DESIGN_H * 0.5:
		return Vector2(DESIGN_W, DESIGN_H)
	var sx: float = visible.x / DESIGN_W
	var sy: float = visible.y / DESIGN_H
	if sx > 1.15 and sy > 1.15:
		return Vector2(DESIGN_W, DESIGN_H)
	return visible


func hold_interval(tick_rate: float) -> float:
	return maxf(hold_min_interval, 1.0 / maxf(tick_rate, 0.2))


func shovel_hit_cells(center: Vector2i, radius: float, precision: bool = false) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if precision or radius <= 0.0:
		cells.append(center)
		return cells
	var reach: int = int(ceili(radius))
	for x in range(center.x - reach, center.x + reach + 1):
		for y in range(center.y - reach, center.y + reach + 1):
			var cell := Vector2i(x, y)
			if Vector2(cell).distance_to(Vector2(center)) > radius:
				continue
			cells.append(cell)
	return cells


func fitted_pit_size() -> Vector2:
	var footprint: Vector2 = reference_pit_size()
	var max_w: float = maxf(view_w - 90.0, 160.0)
	var max_h: float = maxf(view_h - hud_h - find_bar_h - chunk_front - 24.0, 120.0)
	var scale: float = minf(1.0, minf(max_w / footprint.x, max_h / footprint.y))
	return footprint * scale


func apply_cell_metrics() -> void:
	var pit: Vector2 = fitted_pit_size()
	cell_w = pit.x / float(maxi(grid_w, 1))
	cell_h = pit.y / float(maxi(grid_h, 1))
	wall_per_layer = base_wall_per_layer * (cell_h / base_cell_h)
	center_grid()


func apply_site_layout() -> void:
	var layout: Vector2i = site_layout_for_rank(site_size_rank)
	grid_w = maxi(layout.x, 4)
	grid_h = maxi(layout.y, 3)
	apply_cell_metrics()


func center_grid() -> void:
	var top := hud_h + chunk_pad
	grid_origin = Vector2(hud_rail_w() + chunk_pad, top)


func pit_face_bottom() -> float:
	return grid_origin.y + float(grid_h) * cell_h


func pit_grid_size() -> Vector2:
	return Vector2(float(grid_w) * cell_w, float(grid_h) * cell_h)


func pit_grid_rect() -> Rect2:
	return Rect2(grid_origin, pit_grid_size())


func footer_top() -> float:
	return pit_face_bottom() + chunk_front + 8.0


func footer_chip_inset() -> float:
	return grid_origin.x


func footer_menu_gutter() -> float:
	return footer_chip_inset()


func footer_goal_h() -> float:
	return 44.0


func footer_find_gap() -> float:
	return 2.0


func footer_find_top() -> float:
	return footer_top() + footer_find_gap()


func integrity_hit_for(_tool: int) -> float:
	## Tools never damage bone; condition is set by the ground, not by you.
	return 0.0


func chunk_top_color() -> Color:
	return color_for_layer(0)


func chunk_side_color() -> Color:
	return color_for_layer(0).darkened(0.32)


func shaft_interior_color(layer: int = 0) -> Color:
	## Local dirt hue, darkened hard enough that undug tan still reads as a hole.
	if layer >= layer_count:
		return Color("1A1410")
	var source := color_for_layer(maxi(layer, 0))
	var wall := source.darkened(0.42)
	var tan := color_for_layer(0)
	var cap := tan.get_luminance() * 0.70
	var wall_l := wall.get_luminance()
	if wall_l > cap:
		var scale := cap / maxf(wall_l, 0.001)
		wall = Color(wall.r * scale, wall.g * scale, wall.b * scale, wall.a)
	return wall


func chunk_line_color() -> Color:
	return cell_line


func chunk_line_width() -> float:
	return 1.5


func pickaxe_cell_damage(layer: int, is_splash: bool, style_mult: float) -> float:
	var base := damage_for(TOOL_PICKAXE, layer) * style_mult
	if not is_splash:
		return base
	var material := material_at_layer(layer)
	if material <= MAT_PACKED:
		return minf(base, hp_for_layer(layer))
	return base * pickaxe_splash_mult
