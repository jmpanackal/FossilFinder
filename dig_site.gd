class_name DigSite
extends Node2D

const FossilDataScript := preload("res://fossil_data.gd")

signal layer_cleared(amount: int, world_pos: Vector2)
signal fossil_cell_exposed(world_pos: Vector2, first: bool)
signal fossil_extracted(fossil_name: String, value: int, integrity: float)
signal pickaxe_struck
signal fossil_hit

var input_enabled: bool = true
var current_tool: int = Tuning.TOOL_SHOVEL
var deepest_layer: int = 0
var integrity: float = 1.0
var extracted: bool = false
var fossil: FossilDataScript
var fossil_origin := Vector2i.ZERO
var fossil_layer: int = 0
var fossil_cells: Dictionary = {}
var exposed_cells: Dictionary = {}

var _top_layer: Array = []
var _hp: Array = []
var _shovel_accum: float = 0.0
var _brush_last := Vector2.ZERO
var _brushing: bool = false
var _particles: CPUParticles2D
var _dirt_tex: ImageTexture
var _rock_tex: ImageTexture


func _ready() -> void:
	_dirt_tex = _make_square_texture(3)
	_rock_tex = _make_square_texture(6)
	_particles = CPUParticles2D.new()
	_particles.one_shot = true
	_particles.explosiveness = 1.0
	_particles.lifetime = 0.4
	_particles.amount = 12
	_particles.direction = Vector2(0, -1)
	_particles.spread = 180.0
	_particles.gravity = Vector2(0, 240)
	_particles.initial_velocity_min = 36.0
	_particles.initial_velocity_max = 110.0
	_particles.emitting = false
	add_child(_particles)
	start_round()


func start_round() -> void:
	_top_layer = _filled_grid(0)
	_hp = _filled_grid_float(0.0)
	for x in Tuning.grid_w:
		for y in Tuning.grid_h:
			_hp[x][y] = Tuning.hp_for_layer(0)
	deepest_layer = 0
	integrity = 1.0
	extracted = false
	exposed_cells.clear()
	_place_fossil()
	_shovel_accum = 0.0
	_brushing = false
	queue_redraw()


func fossil_exposure() -> float:
	if fossil_cells.is_empty():
		return 0.0
	return float(exposed_cells.size()) / float(fossil_cells.size())


func _filled_grid(value: int) -> Array:
	var grid: Array = []
	grid.resize(Tuning.grid_w)
	for x in Tuning.grid_w:
		var col: Array = []
		col.resize(Tuning.grid_h)
		col.fill(value)
		grid[x] = col
	return grid


func _filled_grid_float(value: float) -> Array:
	var grid: Array = []
	grid.resize(Tuning.grid_w)
	for x in Tuning.grid_w:
		var col: Array = []
		col.resize(Tuning.grid_h)
		col.fill(value)
		grid[x] = col
	return grid


func _place_fossil() -> void:
	fossil_cells.clear()
	if fossil == null:
		fossil = load(Tuning.fossil_path) as FossilDataScript
	if fossil == null:
		push_error("Missing fossil resource")
		return
	var offsets: Array[Vector2i] = fossil.cell_offsets()
	var max_x := 0
	var max_y := 0
	for offset in offsets:
		max_x = maxi(max_x, offset.x)
		max_y = maxi(max_y, offset.y)
	fossil_origin = Vector2i(
		randi_range(0, Tuning.grid_w - 1 - max_x),
		randi_range(0, Tuning.grid_h - 1 - max_y)
	)
	fossil_layer = randi_range(fossil.min_layer, fossil.max_layer)
	for offset in offsets:
		fossil_cells[fossil_origin + offset] = true


func _process(delta: float) -> void:
	if not input_enabled:
		return
	if current_tool == Tuning.TOOL_SHOVEL and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_shovel_accum += delta
		var interval := 1.0 / Tuning.shovel_tick_rate
		while _shovel_accum >= interval:
			_shovel_accum -= interval
			_apply_shovel(_cell_at(_mouse_world()))
	else:
		_shovel_accum = 0.0
	if current_tool == Tuning.TOOL_BRUSH and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var mouse := _mouse_world()
		if _brushing:
			var travel := mouse.distance_to(_brush_last)
			if travel > 0.15:
				_apply_brush(mouse, travel)
		_brush_last = mouse
		_brushing = true
	else:
		_brushing = false
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_1:
			current_tool = Tuning.TOOL_SHOVEL
		elif event.physical_keycode == KEY_2:
			current_tool = Tuning.TOOL_PICKAXE
		elif event.physical_keycode == KEY_3:
			current_tool = Tuning.TOOL_BRUSH
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			current_tool = (current_tool + 2) % 3
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			current_tool = (current_tool + 1) % 3
		elif event.button_index == MOUSE_BUTTON_LEFT and input_enabled:
			if current_tool == Tuning.TOOL_PICKAXE:
				_apply_pickaxe(_cell_at(_mouse_world()))
			elif current_tool == Tuning.TOOL_BRUSH:
				_brush_last = _mouse_world()
				_brushing = true


func _mouse_world() -> Vector2:
	return get_global_mouse_position()


func _in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < Tuning.grid_w and cell.y < Tuning.grid_h


func _top_rect(x: int, y: int) -> Rect2:
	var depth: int = _top_layer[x][y]
	return Rect2(
		Tuning.grid_origin.x + float(x) * Tuning.cell_w,
		Tuning.grid_origin.y + float(y) * Tuning.cell_h + float(depth) * Tuning.wall_per_layer,
		Tuning.cell_w - Tuning.cell_gap,
		Tuning.cell_h - Tuning.cell_gap
	)


func cell_center(cell: Vector2i) -> Vector2:
	return _top_rect(cell.x, cell.y).get_center()


func _cell_at(world: Vector2) -> Vector2i:
	for y in range(Tuning.grid_h - 1, -1, -1):
		for x in Tuning.grid_w:
			if _top_rect(x, y).grow(2.0).has_point(world):
				return Vector2i(x, y)
	var gx := floori((world.x - Tuning.grid_origin.x) / Tuning.cell_w)
	var gy := floori((world.y - Tuning.grid_origin.y) / Tuning.cell_h)
	var fallback := Vector2i(gx, gy)
	if _in_bounds(fallback):
		return fallback
	return Vector2i(-1, -1)


func _is_fossil_cell(cell: Vector2i) -> bool:
	return fossil_cells.has(cell)


func _is_exposed_fossil(cell: Vector2i) -> bool:
	return exposed_cells.has(cell)


func _apply_shovel(center: Vector2i) -> void:
	if not _in_bounds(center):
		return
	var heard := false
	var radius := int(ceili(Tuning.shovel_radius))
	for x in range(center.x - radius, center.x + radius + 1):
		for y in range(center.y - radius, center.y + radius + 1):
			var cell := Vector2i(x, y)
			if not _in_bounds(cell):
				continue
			if Vector2(cell).distance_to(Vector2(center)) <= Tuning.shovel_radius:
				var layer: int = _top_layer[cell.x][cell.y]
				_damage_cell(cell, Tuning.TOOL_SHOVEL, -1.0, not heard)
				if not heard and layer < Tuning.layer_count:
					heard = true


func _apply_pickaxe(cell: Vector2i) -> void:
	if not _in_bounds(cell):
		return
	_damage_cell(cell, Tuning.TOOL_PICKAXE)
	pickaxe_struck.emit()


func _apply_brush(world: Vector2, travel: float) -> void:
	var center := _cell_at(world)
	if not _in_bounds(center):
		return
	for x in range(center.x - 1, center.x + 2):
		for y in range(center.y - 1, center.y + 2):
			var cell := Vector2i(x, y)
			if not _in_bounds(cell):
				continue
			if _is_exposed_fossil(cell):
				continue
			if not _adjacent_to_exposed_fossil(cell):
				continue
			var layer: int = _top_layer[cell.x][cell.y]
			if layer >= Tuning.layer_count:
				continue
			var damage := Tuning.damage_for(Tuning.TOOL_BRUSH, layer) * travel * Tuning.brush_damage_per_pixel
			_damage_cell(cell, Tuning.TOOL_BRUSH, damage, travel > 6.0)


func _adjacent_to_exposed_fossil(cell: Vector2i) -> bool:
	for ox in range(-1, 2):
		for oy in range(-1, 2):
			if ox == 0 and oy == 0:
				continue
			if _is_exposed_fossil(cell + Vector2i(ox, oy)):
				return true
	return false


func _damage_cell(cell: Vector2i, tool: int, override_damage: float = -1.0, play_sfx: bool = true) -> void:
	if not _in_bounds(cell):
		return
	if _is_exposed_fossil(cell):
		if tool != Tuning.TOOL_BRUSH:
			_hit_fossil(cell)
		return
	var layer: int = _top_layer[cell.x][cell.y]
	if layer >= Tuning.layer_count:
		return
	if _is_fossil_cell(cell) and layer >= fossil_layer:
		return
	var damage := override_damage
	if damage < 0.0:
		damage = Tuning.damage_for(tool, layer)
	if damage <= 0.0:
		return
	_hp[cell.x][cell.y] -= damage
	_burst(cell_center(cell), layer)
	if play_sfx:
		_play_hit(layer)
	while _hp[cell.x][cell.y] <= 0.0:
		layer = _top_layer[cell.x][cell.y]
		if layer >= Tuning.layer_count:
			break
		if _is_fossil_cell(cell) and layer == fossil_layer:
			_reveal_fossil_cell(cell)
			_hp[cell.x][cell.y] = 9999.0
			break
		_clear_layer(cell)
		layer = _top_layer[cell.x][cell.y]
		if layer >= Tuning.layer_count:
			_hp[cell.x][cell.y] = 0.0
			break
		if _is_fossil_cell(cell) and layer == fossil_layer:
			_reveal_fossil_cell(cell)
			_hp[cell.x][cell.y] = 9999.0
			break
		_hp[cell.x][cell.y] += Tuning.hp_for_layer(layer)


func _clear_layer(cell: Vector2i) -> void:
	var layer: int = _top_layer[cell.x][cell.y]
	var amount := Tuning.money_for_layer(layer)
	_top_layer[cell.x][cell.y] = layer + 1
	if _top_layer[cell.x][cell.y] > deepest_layer:
		deepest_layer = _top_layer[cell.x][cell.y]
	Sfx.play("layer_clear")
	layer_cleared.emit(amount, cell_center(cell))


func _reveal_fossil_cell(cell: Vector2i) -> void:
	if exposed_cells.has(cell):
		return
	var first := exposed_cells.is_empty()
	exposed_cells[cell] = true
	if _top_layer[cell.x][cell.y] < fossil_layer:
		_top_layer[cell.x][cell.y] = fossil_layer
	if fossil_layer > deepest_layer:
		deepest_layer = fossil_layer
	fossil_cell_exposed.emit(cell_center(cell), first)
	if first:
		Sfx.play("fossil_ping")
	_check_extraction()


func _hit_fossil(cell: Vector2i) -> void:
	if extracted:
		return
	integrity = maxf(Tuning.integrity_floor, integrity - Tuning.integrity_hit_cost)
	_burst(cell_center(cell), fossil_layer)
	Sfx.play("crack")
	fossil_hit.emit()


func _check_extraction() -> void:
	if extracted or fossil_cells.size() == 0:
		return
	if exposed_cells.size() < fossil_cells.size():
		return
	extracted = true
	var value := int(round(float(fossil.base_value) * integrity))
	Sfx.play("extract")
	fossil_extracted.emit(fossil.name, value, integrity)


func _play_hit(layer: int) -> void:
	match Tuning.material_at_layer(layer):
		Tuning.MAT_LOOSE:
			Sfx.play("hit_dirt")
		Tuning.MAT_PACKED:
			Sfx.play("hit_packed")
		Tuning.MAT_CLAY:
			Sfx.play("hit_clay")
		_:
			Sfx.play("hit_rock")


func _burst(world_pos: Vector2, layer: int) -> void:
	var rock := Tuning.material_at_layer(layer) == Tuning.MAT_ROCK
	_particles.position = to_local(world_pos)
	_particles.color = Tuning.particle_color_for_layer(layer)
	_particles.texture = _rock_tex if rock else _dirt_tex
	_particles.amount = 16 if rock else 10
	_particles.scale_amount_min = 1.4 if rock else 0.8
	_particles.scale_amount_max = 2.4 if rock else 1.4
	_particles.lifetime = 0.5 if rock else 0.32
	_particles.restart()
	_particles.emitting = true


func _make_square_texture(size: int) -> ImageTexture:
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	return ImageTexture.create_from_image(image)


func _draw() -> void:
	_draw_ground()
	for y in Tuning.grid_h:
		for x in Tuning.grid_w:
			_draw_walls(x, y)
			_draw_top(x, y)
	_draw_tool_cursor()


func _draw_ground() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color("2B2118"))
	draw_rect(Rect2(Tuning.grid_origin.x - 10, Tuning.grid_origin.y - 10, Tuning.grid_w * Tuning.cell_w + 20, Tuning.grid_h * Tuning.cell_h + Tuning.layer_count * Tuning.wall_per_layer + 20), Color("3A2C20"))


func _south_depth(x: int, y: int) -> int:
	if y + 1 >= Tuning.grid_h:
		return Tuning.layer_count
	return _top_layer[x][y + 1]


func _draw_walls(x: int, y: int) -> void:
	var my_depth: int = _top_layer[x][y]
	var south := _south_depth(x, y)
	if south <= my_depth:
		return
	var top := _top_rect(x, y)
	var drop := float(south - my_depth) * Tuning.wall_per_layer
	if y + 1 < Tuning.grid_h:
		var south_top := _top_rect(x, y + 1)
		drop = maxf(drop, south_top.position.y - top.end.y)
	var wall := Rect2(top.position.x, top.end.y, top.size.x, maxf(drop, 2.0))
	var wall_color := Tuning.color_for_layer(my_depth).darkened(0.35)
	draw_rect(wall, wall_color)
	draw_rect(wall, wall_color.darkened(0.2), false, 1.0)


func _draw_top(x: int, y: int) -> void:
	var cell := Vector2i(x, y)
	var rect := _top_rect(x, y)
	var layer: int = _top_layer[x][y]
	var color: Color
	if _is_exposed_fossil(cell):
		color = Color("E8D5B0").lerp(Color("8A6A3E"), 1.0 - integrity)
	elif layer >= Tuning.layer_count:
		color = Color("1A1410")
	else:
		color = Tuning.color_for_layer(layer)
	draw_rect(rect, color)
	draw_rect(rect, color.lightened(0.18), false, 1.0)
	_draw_cracks(rect, cell, layer)
	if _is_exposed_fossil(cell):
		_draw_bone_mark(rect)


func _draw_cracks(rect: Rect2, cell: Vector2i, layer: int) -> void:
	var crack_count := 0
	var crack_color := Color(0.12, 0.08, 0.05, 0.7)
	if _is_exposed_fossil(cell):
		crack_count = int(round((1.0 - integrity) / 0.18))
		crack_color = Color(0.25, 0.16, 0.1, 0.85)
	elif layer < Tuning.layer_count:
		var max_hp := Tuning.hp_for_layer(layer)
		var damaged := 1.0 - clampf(float(_hp[cell.x][cell.y]) / max_hp, 0.0, 1.0)
		crack_count = int(round(damaged * 3.0))
	_stroke_cracks(rect, crack_count, crack_color)


func _stroke_cracks(rect: Rect2, count: int, color: Color) -> void:
	if count <= 0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = int(rect.position.x * 17 + rect.position.y * 31 + count * 9)
	for i in count:
		var a := rect.position + Vector2(rng.randf() * rect.size.x, rng.randf() * rect.size.y)
		var b := rect.position + Vector2(rng.randf() * rect.size.x, rng.randf() * rect.size.y)
		draw_line(a, b, color, 1.4)


func _draw_bone_mark(rect: Rect2) -> void:
	var inset := rect.grow(-8)
	draw_rect(inset, Color("F3E6C8"), false, 2.0)


func _draw_tool_cursor() -> void:
	var pos := _mouse_world()
	var color := Color("F2E6C4")
	match current_tool:
		Tuning.TOOL_SHOVEL:
			color = Color("D4A017")
			draw_circle(pos, 5.0, color)
			draw_arc(pos, Tuning.shovel_radius * Tuning.cell_w * 0.45, 0.0, TAU, 24, color, 2.0)
		Tuning.TOOL_PICKAXE:
			color = Color("D94A3D")
			draw_line(pos + Vector2(-8, -8), pos + Vector2(8, 8), color, 3.0)
			draw_line(pos + Vector2(8, -8), pos + Vector2(-8, 8), color, 3.0)
		Tuning.TOOL_BRUSH:
			color = Color("7EC8E3")
			draw_circle(pos, 7.0, Color(0.5, 0.8, 0.9, 0.25))
			draw_arc(pos, 8.0, 0.0, TAU, 20, color, 2.0)
	var label: String = Tuning.TOOL_NAMES[current_tool]
	draw_string(ThemeDB.fallback_font, pos + Vector2(12, -10), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, color)
