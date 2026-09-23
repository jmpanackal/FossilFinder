extends Node

## Every gameplay number lives here so feel can be tuned in one place.

const TOOL_SHOVEL := 0
const TOOL_PICKAXE := 1
const TOOL_BRUSH := 2
const TOOL_HANDS := 3
const TOOL_NAMES: PackedStringArray = ["SHOVEL", "PICKAXE", "BRUSH"]

const MAT_LOOSE := 0
const MAT_PACKED := 1
const MAT_CLAY := 2
const MAT_ROCK := 3
const MAT_NAMES := ["Loose dirt", "Packed dirt", "Clay", "Soft rock"]

var base_grid_w: int = 1
var base_grid_h: int = 1
var base_cell_w: float = 64.0
var base_cell_h: float = 40.0
var grid_w: int = 1
var grid_h: int = 1
var site_size_rank: int = 0
var extra_find_slots: int = 0
var extra_find_chance: float = 0.0
var extra_fossil_paths: PackedStringArray = ["res://tooth.tres", "res://vertebra.tres"]
var big_finds_unlocked: bool = false
var passive_miner_owned: bool = false
var site_layouts: Array[Vector2i] = [
	Vector2i(1, 1),
	Vector2i(2, 2),
	Vector2i(3, 2),
	Vector2i(4, 3),
	Vector2i(6, 4),
	Vector2i(8, 5),
	Vector2i(10, 6),
	Vector2i(13, 8),
	Vector2i(16, 10),
]
var layer_count: int = 24
var meters_per_layer: float = 0.5

var cell_w: float = 64.0
var cell_h: float = 40.0
var cell_gap: float = 3.0
var wall_per_layer: float = 2.2
var front_lip: float = 10.0
var chunk_pad: float = 18.0
var chunk_front: float = 64.0
var cell_side: float = 12.0
var grid_origin := Vector2(128, 86)
var view_w: float = 1280.0
var view_h: float = 720.0
var hud_h: float = 96.0
var find_bar_h: float = 58.0
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
	[0.55, 0.65, 3.2, 5.0],
	[0.0, 0.0, 0.0, 0.0],
]

var shovel_radius: float = 0.0
var brush_clean_per_pixel: float = 0.0015

## Click vs hold. Later upgrades can raise one path without touching the other.
var hands_click_mult: float = 0.40
var hands_hold_mult: float = 0.85
var shovel_click_mult: float = 0.70
var shovel_hold_mult: float = 1.0
var shovel_hold_tick_rate: float = 2.4
var pickaxe_click_mult: float = 0.85
var pickaxe_hold_mult: float = 1.0
var pickaxe_hold_tick_rate: float = 1.4
var pickaxe_splash_mult: float = 0.4

var round_seconds: float = 40.0
var integrity_hit_cost: float = 0.10
var integrity_floor: float = 0.25
var unbrushed_value: float = 0.5
var clean_extract_threshold: float = 0.999

var shake_enabled: bool = true
var shake_strength: float = 5.0
var shake_time: float = 0.12

var fossil_path: String = "res://triceratops_skull.tres"
var precision_damage_bonus: float = 0.0
var money_mult: float = 1.0
var museum_income_mult: float = 1.0
var piece_income_clean: float = 0.025
var piece_income_dirty: float = 0.01
var piece_income_exhibit: float = 0.09
var piece_income_exhibit_dirty: float = 0.035
var dirty_income_factor: float = 1.0
var exhibit_flat_income: float = 0.0
var duplicate_cash: float = 0.4
var dirt_money_bonus: float = 0.0
var rock_money_bonus: float = 0.0
var fossil_value_mult: float = 1.0
var spotlight_mult: float = 2.0
var unveil_burst_clean: int = 40
var unveil_burst_dirty: int = 18
var unveil_spike_seconds: float = 5.0
var unveil_spike_mult: float = 2.0

## Break grades only. Dirt is tracked separately.
const PRESERVATION_GRADES: PackedStringArray = [
	"Well preserved",
	"Mostly intact",
	"Weathered",
	"Broken",
	"Crushed",
]


func preservation_stars(integrity: float, _cleanliness: float = 1.0) -> int:
	var intact := clampf(integrity, 0.0, 1.0)
	if intact >= 0.95:
		return 5
	if intact >= 0.80:
		return 4
	if intact >= 0.60:
		return 3
	if intact >= 0.40:
		return 2
	return 1


func preservation_grade(integrity: float, _cleanliness: float = 1.0) -> String:
	return PRESERVATION_GRADES[5 - preservation_stars(integrity)]


func dirt_label(cleanliness: float) -> String:
	if cleanliness >= 0.99:
		return "Clean"
	return "Dust  %d%%" % int(round((1.0 - clampf(cleanliness, 0.0, 1.0)) * 100.0))


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
	var material := material_at_layer(layer)
	var amount := float(material_money[material])
	if material <= MAT_PACKED:
		amount += dirt_money_bonus
	else:
		amount += rock_money_bonus
	return int(round(amount * money_mult))


func color_for_layer(layer: int) -> Color:
	var color: Color = material_colors[material_at_layer(layer)]
	return color.darkened(clampf(float(layer) * depth_darken, 0.0, 0.72))


func particle_color_for_layer(layer: int) -> Color:
	return material_particle_colors[material_at_layer(layer)]


func damage_for(tool: int, layer: int) -> float:
	return float(damage_matrix[tool][material_at_layer(layer)])


func site_layout_for_rank(rank: int) -> Vector2i:
	if site_layouts.is_empty():
		return Vector2i(1, 1)
	var idx: int = clampi(rank, 0, site_layouts.size() - 1)
	return site_layouts[idx]


func apply_site_layout() -> void:
	var layout: Vector2i = site_layout_for_rank(site_size_rank)
	grid_w = layout.x
	grid_h = layout.y
	var max_w: float = view_w - 90.0
	var max_h: float = view_h - hud_h - find_bar_h - chunk_front - 24.0
	var preferred: float = base_cell_w
	if grid_w <= 1:
		preferred = 168.0
	elif grid_w <= 2:
		preferred = 128.0
	elif grid_w <= 4:
		preferred = 88.0
	cell_w = minf(preferred, max_w / float(grid_w))
	cell_h = minf(preferred * (base_cell_h / base_cell_w), cell_w * (base_cell_h / base_cell_w))
	if float(grid_h) * cell_h > max_h:
		cell_h = max_h / float(grid_h)
		cell_w = cell_h * (base_cell_w / base_cell_h)
	center_grid()


func center_grid() -> void:
	var width := float(grid_w) * cell_w + cell_side
	var pit_h := float(grid_h) * cell_h + chunk_front + chunk_pad
	var top := hud_h + 10.0
	var bottom := view_h - find_bar_h - 8.0
	var y := top + maxf(0.0, (bottom - top - pit_h) * 0.5)
	grid_origin = Vector2((view_w - width) * 0.5 + chunk_pad * 0.25, y)


func pickaxe_cell_damage(layer: int, is_splash: bool, style_mult: float) -> float:
	var base := damage_for(TOOL_PICKAXE, layer) * style_mult
	if not is_splash:
		return base
	var material := material_at_layer(layer)
	if material <= MAT_PACKED:
		return minf(base, hp_for_layer(layer))
	return base * pickaxe_splash_mult
