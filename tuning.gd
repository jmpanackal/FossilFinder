extends Node

## Every gameplay number lives here so feel can be tuned in one place.

const TOOL_SHOVEL := 0
const TOOL_PICKAXE := 1
const TOOL_BRUSH := 2
const TOOL_NAMES: PackedStringArray = ["SHOVEL", "PICKAXE", "BRUSH"]

const MAT_LOOSE := 0
const MAT_PACKED := 1
const MAT_CLAY := 2
const MAT_ROCK := 3
const MAT_NAMES := ["Loose dirt", "Packed dirt", "Clay", "Soft rock"]

var grid_w: int = 16
var grid_h: int = 10
var layer_count: int = 24
var meters_per_layer: float = 0.5

var cell_w: float = 70.0
var cell_h: float = 44.0
var cell_gap: float = 3.0
var wall_per_layer: float = 4.0
var grid_origin := Vector2(80, 62)

var material_hp := [1.0, 3.0, 6.0, 12.0]
var material_money := [1, 3, 6, 12]
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
var damage_matrix := [
	[1.0, 1.0, 0.22, 0.07],
	[12.0, 8.0, 8.0, 10.0],
	[1.2, 1.2, 1.2, 1.2],
]

var shovel_radius: float = 1.35
var shovel_tick_rate: float = 8.0
var brush_damage_per_pixel: float = 0.028

var round_seconds: float = 60.0
var integrity_hit_cost: float = 0.10
var integrity_floor: float = 0.25

var shake_enabled: bool = true
var shake_strength: float = 5.0
var shake_time: float = 0.12

var fossil_path: String = "res://triceratops_skull.tres"


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
	return int(material_money[material_at_layer(layer)])


func color_for_layer(layer: int) -> Color:
	var color: Color = material_colors[material_at_layer(layer)]
	return color.darkened(clampf(float(layer) * depth_darken, 0.0, 0.72))


func particle_color_for_layer(layer: int) -> Color:
	return material_particle_colors[material_at_layer(layer)]


func damage_for(tool: int, layer: int) -> float:
	return float(damage_matrix[tool][material_at_layer(layer)])
