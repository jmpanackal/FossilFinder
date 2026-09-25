class_name DigSite
extends Node2D

const FossilDataScript := preload("res://fossil_data.gd")
const Lucky := preload("res://lucky_strike.gd")
const Matrix := preload("res://matrix_find.gd")

signal layer_cleared(amount: int, world_pos: Vector2)
signal fossil_cell_exposed(world_pos: Vector2, first: bool)
signal fossil_extracted(fossil_name: String, value: int, integrity: float, cleanliness: float, clean: bool, piece_id: String)
signal pickaxe_struck
signal fossil_hit
signal fossil_ready_to_dust
signal tool_used(tool: int)
signal lucky_struck(amount: int, world_pos: Vector2)
signal lucky_fled

var input_enabled: bool = true
var current_tool: int = Tuning.TOOL_HANDS
var deepest_layer: int = 0
var integrity: float = 1.0
var extracted: bool = false
var extracted_clean: bool = false
var fossil: FossilDataScript
var fossil_origin := Vector2i.ZERO
var fossil_layer: int = 0
var fossil_cells: Dictionary = {}
var exposed_cells: Dictionary = {}
var cleanliness: Dictionary = {}
var finds: Array = []
var _focus_index: int = 0

var _top_layer: Array = []
var _hp: Array = []
var _hold_time: float = 0.0
var _holding_dig: bool = false
var _brush_last := Vector2.ZERO
var _brushing: bool = false
var _signaled_ready_to_dust: bool = false
var _bone_pulse: float = 0.0
var _grace_left: float = 0.0
var _fossil_hold: float = 0.0
var _particles: CPUParticles2D
var _dust_particles: CPUParticles2D
var _dirt_tex: ImageTexture
var _rock_tex: ImageTexture
var _dust_tex: ImageTexture
var _boosted_tools: Array[int] = []
var _boost_flash: float = 0.0
var _boost_pos := Vector2.ZERO
var _lucky_times: PackedFloat32Array = PackedFloat32Array()
var _lucky_next: int = 0
var _lucky_cell := Vector2i(-1, -1)
var _lucky_left: float = 0.0
var _lucky_elapsed: float = 0.0
var _lucky_flee: float = 0.0
var _lucky_flee_cell := Vector2i(-1, -1)
var _grid_dirty: bool = true
var _fx: _FxOverlay
var _punches: Dictionary = {}
var _matrix_rng: RandomNumberGenerator
var _strike_finds: Array = []
var _matrix_juice: Array = []
var _pending: Array = []

const PUNCH_DIRT := 0
const PUNCH_FIRM := 1
const PUNCH_BONE := 2
const PUNCH_ECHO_NEAR := 0.38
const PUNCH_ECHO_FAR := 0.07
const PUNCH_ECHO_TIME := 0.52
const PUNCH_ECHO_TIME_FAR := 0.28


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
	_dust_tex = _make_square_texture(2)
	_dust_particles = CPUParticles2D.new()
	_dust_particles.one_shot = true
	_dust_particles.explosiveness = 0.7
	_dust_particles.lifetime = 0.45
	_dust_particles.amount = 14
	_dust_particles.direction = Vector2(0, -1)
	_dust_particles.spread = 70.0
	_dust_particles.gravity = Vector2(0, -30)
	_dust_particles.initial_velocity_min = 18.0
	_dust_particles.initial_velocity_max = 46.0
	_dust_particles.color = Color("E8D7B0")
	_dust_particles.texture = _dust_tex
	_dust_particles.emitting = false
	add_child(_dust_particles)
	_fx = _FxOverlay.new()
	_fx.host = self
	_fx.z_index = 10
	add_child(_fx)
	Tuning.apply_cell_metrics()
	start_round()


func start_round() -> void:
	Tuning.apply_site_layout()
	if not GameState.owns_tool(current_tool):
		current_tool = Tuning.TOOL_HANDS
	_top_layer = _filled_grid(0)
	_hp = _filled_grid_float(0.0)
	for x in Tuning.grid_w:
		for y in Tuning.grid_h:
			_hp[x][y] = Tuning.hp_for_layer(0)
	deepest_layer = 0
	integrity = 1.0
	extracted = false
	extracted_clean = false
	exposed_cells.clear()
	cleanliness.clear()
	finds.clear()
	_focus_index = 0
	_signaled_ready_to_dust = false
	_bone_pulse = 0.0
	_grace_left = 0.0
	_fossil_hold = 0.0
	_place_fossils()
	_hold_time = 0.0
	_holding_dig = false
	_brushing = false
	_boost_flash = 0.0
	_boosted_tools.clear()
	_reset_lucky()
	_punches.clear()
	_strike_finds.clear()
	_matrix_juice.clear()
	if _matrix_rng == null:
		_matrix_rng = RandomNumberGenerator.new()
	_matrix_rng.randomize()
	_seed_pending()
	_grid_dirty = true
	queue_redraw()


func cancel_input() -> void:
	_holding_dig = false
	_brushing = false
	_hold_time = 0.0
	_fossil_hold = 0.0


func set_boosted_tools(tools: Array) -> void:
	_boosted_tools.clear()
	for raw in tools:
		var tool: int = int(raw)
		if not _boosted_tools.has(tool):
			_boosted_tools.append(tool)


func has_boosted_tool(tool: int) -> bool:
	return _boosted_tools.has(tool)


func _reset_lucky() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_lucky_times = Lucky.plan_shift(rng, Tuning.round_seconds)
	_lucky_next = 0
	_lucky_cell = Vector2i(-1, -1)
	_lucky_left = 0.0
	_lucky_elapsed = 0.0
	_lucky_flee = 0.0
	_lucky_flee_cell = Vector2i(-1, -1)


func _tick_lucky(delta: float) -> void:
	if _lucky_flee > 0.0:
		_lucky_flee = maxf(0.0, _lucky_flee - delta * 3.5)
	if not input_enabled:
		if _lucky_cell.x >= 0:
			_burrow_lucky()
		return
	_lucky_elapsed += delta
	if _lucky_left > 0.0:
		_lucky_left = maxf(0.0, _lucky_left - delta)
		if _lucky_left <= 0.0:
			_burrow_lucky()
		return
	if _lucky_next >= _lucky_times.size():
		return
	if _lucky_elapsed < _lucky_times[_lucky_next]:
		return
	_spawn_lucky()
	_lucky_next += 1


func _spawn_lucky() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var blocked: Array[Vector2i] = []
	for cell in exposed_cells:
		blocked.append(cell)
	_lucky_cell = Lucky.pick_cell(rng, Tuning.grid_w, Tuning.grid_h, blocked)
	if _lucky_cell.x < 0:
		return
	_lucky_left = Tuning.lucky_duration


func _burrow_lucky() -> void:
	if _lucky_cell.x < 0:
		return
	_lucky_flee_cell = _lucky_cell
	_lucky_flee = 1.0
	_lucky_cell = Vector2i(-1, -1)
	_lucky_left = 0.0
	lucky_fled.emit()


func _collect_lucky(cells: Array[Vector2i]) -> void:
	if _lucky_cell.x < 0 or not Lucky.can_hit_with(current_tool):
		return
	for cell in cells:
		if cell != _lucky_cell:
			continue
		var amount: int = Lucky.burst_payout(Tuning.money_for_layer(0))
		var pos := cell_center(_lucky_cell)
		_lucky_cell = Vector2i(-1, -1)
		_lucky_left = 0.0
		lucky_struck.emit(amount, pos)
		return


func lucky_is_active() -> bool:
	return _lucky_cell.x >= 0


func take_matrix_juice() -> Array:
	var juice: Array = _matrix_juice.duplicate()
	_matrix_juice.clear()
	return juice


func pending_find(cell: Vector2i) -> Dictionary:
	if _pending.is_empty() or not _in_bounds(cell):
		return {}
	var raw: Variant = _pending[cell.x][cell.y]
	if raw is Dictionary:
		return (raw as Dictionary).duplicate()
	return {}


func _seed_pending() -> void:
	_pending.clear()
	_pending.resize(Tuning.grid_w)
	for x in Tuning.grid_w:
		var col: Array = []
		col.resize(Tuning.grid_h)
		for y in Tuning.grid_h:
			var layer: int = 0
			if not _top_layer.is_empty() and x < _top_layer.size() and y < _top_layer[x].size():
				layer = int(_top_layer[x][y])
			col[y] = _roll_matrix(layer)
		_pending[x] = col


func _refresh_pending(cell: Vector2i) -> void:
	if _pending.is_empty() or not _in_bounds(cell):
		return
	var layer: int = int(_top_layer[cell.x][cell.y])
	if layer >= Tuning.layer_count:
		_pending[cell.x][cell.y] = {}
		return
	_pending[cell.x][cell.y] = _roll_matrix(layer)


func _draw_lucky() -> void:
	var cell := _lucky_cell
	var pulse: float = 1.0
	if cell.x < 0:
		if _lucky_flee <= 0.0:
			return
		cell = _lucky_flee_cell
		pulse = _lucky_flee
	if not _in_bounds(cell):
		return
	var rect := _top_rect(cell.x, cell.y)
	var beat: float = 0.55 + 0.45 * absf(sin(float(Time.get_ticks_msec()) * 0.012))
	var grow: float = (3.0 + beat * 3.0) * pulse
	var amber := Color("FFB020", (0.55 + beat * 0.4) * pulse)
	var gold := Color("FFE08A", (0.7 + beat * 0.3) * pulse)
	draw_rect(rect.grow(grow), amber)
	draw_rect(rect, Color("FFCC44", 0.38 * pulse))
	draw_rect(rect.grow(2.0 * pulse), gold, false, 2.5 + beat * 2.0)
	var flake: float = minf(rect.size.x, rect.size.y) * (0.10 + beat * 0.04)
	var center := rect.get_center()
	draw_circle(center, flake, Color("FFF6D0", pulse))
	draw_line(center + Vector2(-flake * 2.4, 0), center + Vector2(flake * 2.4, 0), gold, 1.6)
	draw_line(center + Vector2(0, -flake * 2.4), center + Vector2(0, flake * 2.4), gold, 1.6)
	draw_arc(center, flake * 1.8, 0.0, TAU, 22, Color("FFE08A", 0.85 * pulse), 2.0)


func fossil_exposure() -> float:
	if fossil_cells.is_empty():
		return 0.0
	return float(exposed_cells.size()) / float(fossil_cells.size())


func fossil_cleanliness() -> float:
	return _find_clean(_focused_find())


func preview_value() -> int:
	var find := _focused_find()
	if find.is_empty():
		return 0
	var data = find.get("data", null)
	if data == null:
		return 0
	var clean := _find_clean(find)
	var intact: float = float(find.get("integrity", 1.0))
	var quality := lerpf(Tuning.unbrushed_value, 1.0, clean)
	return int(round(float(data.base_value) * intact * quality * Tuning.fossil_value_mult))


func is_fully_exposed() -> bool:
	for find in finds:
		if not bool(find.get("extracted", false)) and _find_is_fully_exposed(find):
			return true
	return false


func has_visible_find() -> bool:
	for find in finds:
		var cells: Dictionary = find.get("cells", {})
		for cell in cells:
			if exposed_cells.has(cell):
				return true
	return false


func focused_find_name() -> String:
	var data = _focused_find().get("data", null)
	if data == null:
		return ""
	return str(data.name)


func focused_find_extracted() -> bool:
	return bool(_focused_find().get("extracted", false))


func set_tool(tool: int) -> void:
	if tool < 0 or tool > Tuning.TOOL_HANDS or tool == current_tool:
		return
	if not GameState.owns_tool(tool):
		return
	current_tool = tool
	_holding_dig = false
	_hold_time = 0.0
	Sfx.play("ui")


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


func _place_fossils() -> void:
	finds.clear()
	fossil_cells.clear()
	var main_data: FossilDataScript = _choose_main_find()
	if not _try_place_find(main_data):
		var starter: FossilDataScript = load("res://t_rex_tooth.tres") as FossilDataScript
		_try_place_find(starter)
	if not finds.is_empty():
		fossil = finds[0]["data"]
		fossil_origin = finds[0]["origin"]
		fossil_layer = int(finds[0]["layer"])
	var extras: int = 0
	for _i in Tuning.extra_find_slots:
		if randf() <= Tuning.extra_find_chance:
			extras += 1
	var pool: Array = []
	for path in Tuning.extra_fossil_paths:
		var extra: FossilDataScript = load(str(path)) as FossilDataScript
		if extra != null and _can_spawn(extra):
			pool.append(extra)
	for path in Tuning.main_fossil_paths:
		var extra: FossilDataScript = load(str(path)) as FossilDataScript
		if extra == null or not _can_spawn(extra) or not _is_small_seasonal(extra):
			continue
		var extra_id: String = extra.piece_id if extra.piece_id != "" else extra.name.to_snake_case()
		if GameState.piece_needs_more(extra_id):
			pool.append(extra)
			continue
		if extra.occupied_cells() == 1 and randf() < Tuning.extra_complete_set_chance:
			pool.append(extra)
	for _j in extras:
		if pool.is_empty():
			break
		_try_place_find(pool[randi() % pool.size()])


func _choose_main_find() -> FossilDataScript:
	var options: Array = []
	var seen: Dictionary = {}
	for path in Tuning.main_fossil_paths:
		_append_spawnable(options, seen, str(path))
	_append_spawnable(options, seen, Tuning.fossil_path)
	if options.is_empty():
		return load("res://t_rex_tooth.tres") as FossilDataScript
	var missing: Array = []
	for data in options:
		var piece: FossilDataScript = data as FossilDataScript
		var id: String = piece.piece_id if piece.piece_id != "" else piece.name.to_snake_case()
		if GameState.piece_needs_more(id):
			missing.append(piece)
	var pool: Array = missing if not missing.is_empty() else options
	return pool[randi() % pool.size()] as FossilDataScript


func _append_spawnable(options: Array, seen: Dictionary, path: String) -> void:
	if path.is_empty() or seen.has(path):
		return
	seen[path] = true
	var data: FossilDataScript = load(path) as FossilDataScript
	if data != null and _can_spawn(data):
		options.append(data)


func _can_spawn(data: FossilDataScript) -> bool:
	if data == null:
		return false
	if not Tuning.piece_can_spawn(data, Tuning.site_size_rank, Tuning.big_finds_unlocked):
		return false
	var box: Vector2i = data.bounding_size()
	if box.x > Tuning.grid_w or box.y > Tuning.grid_h:
		return false
	if box.x >= Tuning.grid_w and box.y >= Tuning.grid_h:
		return false
	return true


func _is_scrap(data: FossilDataScript) -> bool:
	if data == null:
		return false
	return not data.is_skull() and data.occupied_cells() < 6


func _is_small_seasonal(data: FossilDataScript) -> bool:
	if data == null or data.is_skull():
		return false
	return data.occupied_cells() <= 3


func _try_place_find(data: FossilDataScript) -> bool:
	if data == null:
		return false
	var offsets: Array[Vector2i] = data.cell_offsets()
	if offsets.is_empty():
		return false
	var max_x := 0
	var max_y := 0
	for offset in offsets:
		max_x = maxi(max_x, offset.x)
		max_y = maxi(max_y, offset.y)
	if Tuning.grid_w - 1 - max_x < 0 or Tuning.grid_h - 1 - max_y < 0:
		return false
	for _attempt in 24:
		var origin := Vector2i(
			randi_range(0, Tuning.grid_w - 1 - max_x),
			randi_range(0, Tuning.grid_h - 1 - max_y)
		)
		var blocked := false
		for offset in offsets:
			if fossil_cells.has(origin + offset):
				blocked = true
				break
		if blocked:
			continue
		var layer := randi_range(data.min_layer, data.max_layer)
		var cells := {}
		for offset in offsets:
			var cell: Vector2i = origin + offset
			cells[cell] = true
			fossil_cells[cell] = finds.size()
		finds.append({
			"data": data,
			"piece_id": data.piece_id if data.piece_id != "" else data.name.to_snake_case(),
			"origin": origin,
			"layer": layer,
			"cells": cells,
			"integrity": 1.0,
			"extracted": false,
			"extracted_clean": false,
			"ready": false,
		})
		return true
	return false


func _find_at(cell: Vector2i) -> Dictionary:
	if not fossil_cells.has(cell):
		return {}
	var index: int = int(fossil_cells[cell])
	if index < 0 or index >= finds.size():
		return {}
	return finds[index]


func _focused_find() -> Dictionary:
	if _focus_index >= 0 and _focus_index < finds.size():
		return finds[_focus_index]
	if not finds.is_empty():
		return finds[0]
	return {}


func _find_clean(find: Dictionary) -> float:
	if find.is_empty():
		return 0.0
	var cells: Dictionary = find["cells"]
	if cells.is_empty():
		return 0.0
	var total := 0.0
	for cell in cells:
		total += float(cleanliness.get(cell, 0.0))
	return total / float(cells.size())


func _find_is_fully_exposed(find: Dictionary) -> bool:
	if find.is_empty():
		return false
	var cells: Dictionary = find["cells"]
	for cell in cells:
		if not exposed_cells.has(cell):
			return false
	return cells.size() > 0


func _focus_find(find: Dictionary) -> void:
	if find.is_empty():
		return
	_focus_index = finds.find(find)
	integrity = float(find.get("integrity", 1.0))
	fossil = find.get("data", fossil)
	fossil_layer = int(find.get("layer", fossil_layer))
	fossil_origin = find.get("origin", fossil_origin)


func _process(delta: float) -> void:
	if _grace_left > 0.0:
		_grace_left = maxf(0.0, _grace_left - delta)
	if _bone_pulse > 0.0:
		_bone_pulse = maxf(0.0, _bone_pulse - delta * 0.85)
	if _boost_flash > 0.0:
		_boost_flash = maxf(0.0, _boost_flash - delta * 1.8)
	_tick_lucky(delta)
	_tick_punches(delta)
	if not input_enabled:
		_redraw_grid_if_dirty()
		return
	var holding := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var aiming := _cell_at(_mouse_world())
	if _holding_dig and holding and GameState.hold_unlocked() and _is_strike_tool():
		if _is_exposed_fossil(aiming):
			_hold_time = 0.0
			if _can_harm_fossil():
				_fossil_hold += delta
				var gap := Tuning.hold_interval(Tuning.fossil_hold_tick_rate)
				if _fossil_hold >= gap:
					_fossil_hold = minf(_fossil_hold - gap, gap * 0.5)
					_hit_fossil(aiming)
			else:
				_fossil_hold = 0.0
		else:
			_fossil_hold = 0.0
			_hold_time += delta
			var interval := Tuning.hold_interval(_hold_rate())
			if _hold_time >= interval:
				_hold_time = minf(_hold_time - interval, interval * 0.5)
				_strike_current(false)
	else:
		_holding_dig = false
		_hold_time = 0.0
		_fossil_hold = 0.0
	if current_tool == Tuning.TOOL_BRUSH and holding:
		var mouse := _mouse_world()
		if _brushing:
			var travel := mouse.distance_to(_brush_last)
			if travel > 0.15:
				_apply_brush(mouse, travel)
		_brush_last = mouse
		_brushing = true
	else:
		_brushing = false
	_redraw_grid_if_dirty()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var next_tool: int = _tool_from_hotkey(event.physical_keycode)
		if next_tool >= 0:
			set_tool(next_tool)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_cycle_tool(-1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_cycle_tool(1)
		elif event.button_index == MOUSE_BUTTON_LEFT and input_enabled:
			if _is_strike_tool():
				_strike_current(true)
				_hold_time = 0.0
				_holding_dig = GameState.hold_unlocked()
			elif current_tool == Tuning.TOOL_BRUSH:
				_brush_last = _mouse_world()
				_brushing = true


func _mouse_world() -> Vector2:
	return get_global_mouse_position()


func _in_bounds(cell: Vector2i) -> bool:
	if _top_layer.is_empty():
		return false
	return cell.x >= 0 and cell.y >= 0 and cell.x < _top_layer.size() and cell.y < _top_layer[0].size()


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


func _cycle_tool(step: int) -> void:
	var tools: Array[int] = GameState.owned_tool_ids()
	if tools.is_empty():
		return
	var idx: int = tools.find(current_tool)
	if idx < 0:
		set_tool(tools[0])
		return
	set_tool(tools[posmod(idx + step, tools.size())])


func _tool_from_hotkey(keycode: int) -> int:
	match keycode:
		KEY_0:
			return Tuning.TOOL_HANDS
		KEY_1:
			return Tuning.TOOL_SHOVEL
		KEY_2:
			return Tuning.TOOL_PICKAXE
		KEY_3:
			return Tuning.TOOL_BRUSH
		_:
			return -1


func _is_strike_tool() -> bool:
	return current_tool == Tuning.TOOL_HANDS or current_tool == Tuning.TOOL_SHOVEL or current_tool == Tuning.TOOL_PICKAXE


func _using_hands() -> bool:
	return current_tool == Tuning.TOOL_HANDS


func _hold_rate() -> float:
	if current_tool == Tuning.TOOL_PICKAXE:
		return Tuning.pickaxe_hold_tick_rate
	return Tuning.shovel_hold_tick_rate


func _style_mult(is_click: bool) -> float:
	if _using_hands():
		if is_click:
			return Tuning.hands_click_mult
		return Tuning.hands_hold_mult
	if current_tool == Tuning.TOOL_PICKAXE:
		return Tuning.pickaxe_click_mult if is_click else Tuning.pickaxe_hold_mult
	return Tuning.shovel_click_mult if is_click else Tuning.shovel_hold_mult


func _strike_current(is_click: bool) -> void:
	var cell := _cell_at(_mouse_world())
	var mult := _style_mult(is_click)
	if current_tool == Tuning.TOOL_SHOVEL or current_tool == Tuning.TOOL_HANDS:
		_apply_shovel(cell, mult, is_click)
	elif current_tool == Tuning.TOOL_PICKAXE:
		_apply_pickaxe(cell, mult, is_click)


func _apply_shovel(center: Vector2i, style_mult: float, is_click: bool) -> void:
	_strike_finds.clear()
	if not _in_bounds(center):
		return
	var heard := false
	var juice_layer: int = _top_layer[center.x][center.y]
	var struck: int = 0
	var payout: int = 0
	var punch_hits: Array[Vector3i] = []
	var radius: float = 0.0
	if not _using_hands():
		radius = Tuning.shovel_radius
	var targets: Array[Vector2i] = Tuning.shovel_hit_cells(center, radius)
	_collect_lucky(targets)
	for cell in targets:
		if not _in_bounds(cell):
			continue
		if _is_exposed_fossil(cell):
			if is_click and cell == center and _can_harm_fossil():
				_hit_fossil(cell)
			continue
		var layer: int = _top_layer[cell.x][cell.y]
		var damage := Tuning.damage_for(Tuning.TOOL_SHOVEL, layer) * style_mult
		var gained: int = _damage_cell(cell, Tuning.TOOL_SHOVEL, damage)
		if gained < 0:
			continue
		punch_hits.append(Vector3i(cell.x, cell.y, _punch_kind_for_layer(layer)))
		payout += gained
		struck += 1
		if not heard:
			juice_layer = layer
			heard = true
	_begin_strike_punches(center, punch_hits)
	_finish_strike(center, juice_layer, payout, struck, heard)
	_mark_tool_used(current_tool, cell_center(center))


func _apply_pickaxe(center: Vector2i, style_mult: float, is_click: bool) -> void:
	_strike_finds.clear()
	if not _in_bounds(center):
		return
	var heard := false
	var offsets: Array[Vector2i] = [
		Vector2i(0, 0),
		Vector2i(0, -1),
		Vector2i(0, 1),
		Vector2i(-1, 0),
		Vector2i(1, 0),
	]
	var pick_cells: Array[Vector2i] = []
	for offset in offsets:
		pick_cells.append(center + offset)
	_collect_lucky(pick_cells)
	var juice_layer: int = _top_layer[center.x][center.y]
	var struck: int = 0
	var payout: int = 0
	var punch_hits: Array[Vector3i] = []
	for offset in offsets:
		var cell: Vector2i = center + offset
		if not _in_bounds(cell):
			continue
		if _is_exposed_fossil(cell):
			if is_click and cell == center and _can_harm_fossil():
				_hit_fossil(cell)
			continue
		var splash := offset != Vector2i.ZERO
		var layer: int = _top_layer[cell.x][cell.y]
		var damage := Tuning.pickaxe_cell_damage(layer, splash, style_mult)
		var gained: int = _damage_cell(cell, Tuning.TOOL_PICKAXE, damage)
		if gained < 0:
			continue
		punch_hits.append(Vector3i(cell.x, cell.y, _punch_kind_for_layer(layer)))
		payout += gained
		struck += 1
		if not heard:
			juice_layer = layer
			heard = true
	_begin_strike_punches(center, punch_hits)
	_finish_strike(center, juice_layer, payout, struck, heard)
	pickaxe_struck.emit()
	_mark_tool_used(Tuning.TOOL_PICKAXE, cell_center(center))


func _apply_brush(world: Vector2, travel: float) -> void:
	var cell := _cell_at(world)
	if not _is_exposed_fossil(cell):
		return
	var before: float = float(cleanliness.get(cell, 0.0))
	if before >= 1.0:
		return
	var after := clampf(before + travel * Tuning.brush_clean_per_pixel, 0.0, 1.0)
	cleanliness[cell] = after
	_grid_dirty = true
	_puff_dust(cell_center(cell), after - before)
	_mark_tool_used(Tuning.TOOL_BRUSH, cell_center(cell))
	if travel > 4.0:
		Sfx.play("dust")
	_focus_find(_find_at(cell))
	var find := _find_at(cell)
	if not find.is_empty() and _find_is_fully_exposed(find) and _find_clean(find) >= Tuning.clean_extract_threshold:
		_extract_find(find, true)


func _damage_cell(cell: Vector2i, tool: int, override_damage: float = -1.0) -> int:
	if not _in_bounds(cell):
		return -1
	if _is_exposed_fossil(cell):
		return -1
	var layer: int = _top_layer[cell.x][cell.y]
	if layer >= Tuning.layer_count:
		return -1
	var buried := _find_at(cell)
	if not buried.is_empty() and layer >= int(buried["layer"]):
		return -1
	var damage := override_damage
	if damage < 0.0:
		damage = Tuning.damage_for(tool, layer)
	if damage <= 0.0:
		return -1
	var start_material := Tuning.material_at_layer(layer)
	_hp[cell.x][cell.y] -= damage
	_grid_dirty = true
	var payout: int = 0
	var cleared := 0
	while _hp[cell.x][cell.y] <= 0.0:
		layer = _top_layer[cell.x][cell.y]
		if layer >= Tuning.layer_count:
			break
		var host := _find_at(cell)
		if not host.is_empty() and layer == int(host["layer"]):
			_reveal_fossil_cell(cell)
			_hp[cell.x][cell.y] = 9999.0
			break
		payout += _clear_layer(cell)
		cleared += 1
		layer = _top_layer[cell.x][cell.y]
		if layer >= Tuning.layer_count:
			_hp[cell.x][cell.y] = 0.0
			break
		host = _find_at(cell)
		if not host.is_empty() and layer == int(host["layer"]):
			_reveal_fossil_cell(cell)
			_hp[cell.x][cell.y] = 9999.0
			break
		_hp[cell.x][cell.y] += Tuning.hp_for_layer(layer)
		if tool == Tuning.TOOL_PICKAXE and start_material <= Tuning.MAT_PACKED and cleared >= 1:
			_hp[cell.x][cell.y] = Tuning.hp_for_layer(layer)
			break
	return payout


func _clear_layer(cell: Vector2i) -> int:
	var layer: int = _top_layer[cell.x][cell.y]
	var find: Dictionary = Matrix.harvest(pending_find(cell), layer, current_tool)
	_top_layer[cell.x][cell.y] = layer + 1
	if _top_layer[cell.x][cell.y] > deepest_layer:
		deepest_layer = _top_layer[cell.x][cell.y]
	_refresh_pending(cell)
	_grid_dirty = true
	if find.is_empty():
		return 0
	find["origin"] = cell_center(cell)
	_strike_finds.append(find)
	return int(find.get("amount", 0))


func _roll_matrix(layer: int) -> Dictionary:
	if _matrix_rng == null:
		_matrix_rng = RandomNumberGenerator.new()
		_matrix_rng.randomize()
	return Matrix.roll(_matrix_rng, layer)


func _reveal_fossil_cell(cell: Vector2i) -> void:
	if exposed_cells.has(cell):
		return
	var find := _find_at(cell)
	if find.is_empty() or bool(find.get("extracted", false)):
		return
	var first := exposed_cells.is_empty()
	exposed_cells[cell] = true
	cleanliness[cell] = 0.0
	var layer: int = int(find["layer"])
	if _top_layer[cell.x][cell.y] < layer:
		_top_layer[cell.x][cell.y] = layer
	if layer > deepest_layer:
		deepest_layer = layer
	_focus_find(find)
	_grid_dirty = true
	fossil_cell_exposed.emit(cell_center(cell), first)
	if first:
		Sfx.play("fossil_ping")
	_grace_left = Tuning.fossil_grace
	if _find_is_fully_exposed(find) and not bool(find.get("ready", false)):
		find["ready"] = true
		pulse_bones()
		fossil_ready_to_dust.emit()


func _can_harm_fossil() -> bool:
	if _grace_left > 0.0:
		return false
	var find := _find_at(_cell_at(_mouse_world()))
	return not find.is_empty() and not bool(find.get("extracted", false))


func pulse_bones() -> void:
	_bone_pulse = 1.0
	_grid_dirty = true
	queue_redraw()


func fossil_centroid() -> Vector2:
	var find := _focused_find()
	var cells: Dictionary = find.get("cells", {})
	if cells.is_empty():
		return Tuning.grid_origin + Vector2(Tuning.grid_w * Tuning.cell_w, Tuning.grid_h * Tuning.cell_h) * 0.5
	var sum := Vector2.ZERO
	for cell in cells:
		sum += cell_center(cell)
	return sum / float(cells.size())


func _hit_fossil(cell: Vector2i) -> void:
	var find := _find_at(cell)
	if find.is_empty() or bool(find.get("extracted", false)):
		return
	var cost: float = Tuning.integrity_hit_for(current_tool)
	if cost <= 0.0:
		return
	find["integrity"] = maxf(Tuning.integrity_floor, float(find["integrity"]) - cost)
	_focus_find(find)
	_begin_punch(cell, PUNCH_BONE)
	_bone_pulse = maxf(_bone_pulse, 0.7)
	_burst(cell_center(cell), int(find["layer"]))
	Sfx.play("crack")
	fossil_hit.emit()
	_grid_dirty = true
	queue_redraw()


func extract_now(require_clean: bool) -> void:
	for find in finds:
		if bool(find.get("extracted", false)):
			continue
		if not _find_is_fully_exposed(find):
			continue
		if require_clean and _find_clean(find) < Tuning.clean_extract_threshold:
			continue
		_extract_find(find, require_clean)


func _extract_find(find: Dictionary, _require_clean: bool) -> void:
	if find.is_empty() or bool(find.get("extracted", false)):
		return
	if not _find_is_fully_exposed(find):
		return
	var clean := _find_clean(find)
	var intact: float = float(find.get("integrity", 1.0))
	find["extracted"] = true
	find["extracted_clean"] = clean >= Tuning.clean_extract_threshold
	_focus_find(find)
	var data: FossilDataScript = find["data"]
	var quality := lerpf(Tuning.unbrushed_value, 1.0, clean)
	var value := int(round(float(data.base_value) * intact * quality * Tuning.fossil_value_mult))
	extracted = true
	extracted_clean = bool(find["extracted_clean"])
	fossil = data
	integrity = intact
	Sfx.play("extract")
	fossil_extracted.emit(data.name, value, intact, clean, bool(find["extracted_clean"]), str(find.get("piece_id", "")))


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


func _finish_strike(center: Vector2i, juice_layer: int, payout: int, struck: int, play_sfx: bool) -> void:
	_matrix_juice = Matrix.batch_display(_strike_finds)
	_strike_finds.clear()
	if struck > 0:
		_burst(cell_center(center), juice_layer, struck > 1)
	if play_sfx:
		_play_hit(juice_layer)
	if payout > 0:
		Sfx.play("layer_clear")
		layer_cleared.emit(payout, cell_center(center))
	if struck > 0 or payout > 0:
		_grid_dirty = true


func _begin_strike_punches(center: Vector2i, hits: Array[Vector3i]) -> void:
	var n: int = hits.size()
	if n <= 0:
		return
	var aim_weight: float = 1.0 + minf(0.16, maxf(0.0, float(n - 1)) * 0.018)
	var reach: float = 0.0
	for rec in hits:
		var cell := Vector2i(rec.x, rec.y)
		reach = maxf(reach, Vector2(cell).distance_to(Vector2(center)))
	for rec in hits:
		var cell := Vector2i(rec.x, rec.y)
		var kind: int = rec.z
		if cell == center:
			_begin_punch(cell, kind, aim_weight)
		else:
			_begin_punch(cell, kind, _punch_echo_weight(center, cell, reach))


func _punch_echo_weight(center: Vector2i, cell: Vector2i, reach: float) -> float:
	var dist: float = Vector2(cell).distance_to(Vector2(center))
	var span: float = maxf(reach - 1.0, 0.001)
	var t: float = clampf((dist - 1.0) / span, 0.0, 1.0)
	var eased: float = t * t * (3.0 - 2.0 * t)
	return lerpf(PUNCH_ECHO_NEAR, PUNCH_ECHO_FAR, eased)


func _begin_punch(cell: Vector2i, kind: int, weight: float = 1.0) -> void:
	if not _in_bounds(cell):
		return
	_punches[cell] = Vector3(0.0, float(kind), weight)
	_grid_dirty = true


func _tick_punches(delta: float) -> void:
	if _punches.is_empty():
		return
	var stale: Array[Vector2i] = []
	for cell in _punches:
		var rec: Vector3 = _punches[cell]
		rec.x += delta
		if rec.x >= _punch_duration(int(rec.y), rec.z):
			stale.append(cell)
		else:
			_punches[cell] = rec
	for cell in stale:
		_punches.erase(cell)
	_grid_dirty = true


func _punch_kind_for_layer(layer: int) -> int:
	if Tuning.material_at_layer(layer) == Tuning.MAT_LOOSE:
		return PUNCH_DIRT
	return PUNCH_FIRM


func _punch_duration(kind: int, weight: float = 1.0) -> float:
	var base: float = 0.11
	match kind:
		PUNCH_BONE:
			base = 0.065
		PUNCH_FIRM:
			base = 0.09
	if weight >= 0.99:
		return base
	var u: float = clampf(
		(weight - PUNCH_ECHO_FAR) / maxf(PUNCH_ECHO_NEAR - PUNCH_ECHO_FAR, 0.001),
		0.0,
		1.0
	)
	return base * lerpf(PUNCH_ECHO_TIME_FAR, PUNCH_ECHO_TIME, u)


func _punch_squash(kind: int, weight: float = 1.0) -> Vector2:
	var squash := Vector2(0.16, 0.22)
	match kind:
		PUNCH_BONE:
			squash = Vector2(0.04, 0.11)
		PUNCH_FIRM:
			squash = Vector2(0.07, 0.09)
	return squash * maxf(weight, 0.0)


func _punch_envelope(u: float) -> float:
	if u <= 0.0 or u >= 1.0:
		return 0.0
	if u < 0.22:
		var rise: float = u / 0.22
		return 1.0 - (1.0 - rise) * (1.0 - rise)
	if u < 0.58:
		var mid: float = (u - 0.22) / 0.36
		var smooth: float = mid * mid * (3.0 - 2.0 * mid)
		return lerpf(1.0, -0.2, smooth)
	var settle: float = (u - 0.58) / 0.42
	return lerpf(-0.2, 0.0, 1.0 - (1.0 - settle) * (1.0 - settle))


func _punch_scale(kind: int, age: float, weight: float = 1.0) -> Vector2:
	var duration: float = _punch_duration(kind, weight)
	if age < 0.0 or age >= duration:
		return Vector2.ONE
	var env: float = _punch_envelope(age / duration)
	var squash: Vector2 = _punch_squash(kind, weight)
	return Vector2(1.0 + squash.x * env, 1.0 - squash.y * env)


func _punched_rect(rect: Rect2, cell: Vector2i) -> Rect2:
	if not _punches.has(cell):
		return rect
	var rec: Vector3 = _punches[cell]
	var punch: Vector2 = _punch_scale(int(rec.y), rec.x, rec.z)
	if punch == Vector2.ONE:
		return rect
	var center: Vector2 = rect.get_center()
	var size: Vector2 = Vector2(rect.size.x * punch.x, rect.size.y * punch.y)
	return Rect2(center - size * 0.5, size)


func _redraw_grid_if_dirty() -> void:
	if _grid_dirty or _bone_pulse > 0.0 or _lucky_flee > 0.0 or lucky_is_active() or not _punches.is_empty():
		_grid_dirty = false
		queue_redraw()


func _burst(world_pos: Vector2, layer: int, fat: bool = false) -> void:
	var rock := Tuning.material_at_layer(layer) == Tuning.MAT_ROCK
	_particles.position = to_local(world_pos)
	_particles.color = Tuning.particle_color_for_layer(layer)
	_particles.texture = _rock_tex if rock else _dirt_tex
	_particles.amount = (22 if rock else 14) if fat else (16 if rock else 10)
	_particles.scale_amount_min = 1.4 if rock else 0.8
	_particles.scale_amount_max = 2.4 if rock else 1.4
	_particles.lifetime = 0.5 if rock else 0.32
	_particles.restart()
	_particles.emitting = true


func _puff_dust(world_pos: Vector2, amount: float) -> void:
	var extra: int = 10 if has_boosted_tool(Tuning.TOOL_BRUSH) else 0
	_dust_particles.position = to_local(world_pos)
	_dust_particles.amount = 10 + extra + int(amount * 40.0)
	_dust_particles.color = Color("E8D7B0").lerp(Color("FBF3DC"), clampf(amount * 8.0, 0.0, 1.0))
	_dust_particles.restart()
	_dust_particles.emitting = true


func _mark_tool_used(tool: int, world_pos: Vector2) -> void:
	if has_boosted_tool(tool):
		_boost_flash = 1.0
		_boost_pos = world_pos
	tool_used.emit(tool)


func _make_square_texture(size: int) -> ImageTexture:
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	return ImageTexture.create_from_image(image)


func _draw() -> void:
	_draw_chunk()
	if _top_layer.is_empty():
		return
	var width: int = _top_layer.size()
	var height: int = _top_layer[0].size()
	for y in height:
		for x in width:
			_draw_cell_sides(x, y)
			_draw_top(x, y)
	_draw_bone_pulse()
	_draw_lucky()


func _chunk_top() -> Rect2:
	var pad := Tuning.chunk_pad
	return Rect2(
		Tuning.grid_origin.x - pad,
		Tuning.grid_origin.y - pad,
		float(Tuning.grid_w) * Tuning.cell_w + pad * 2.0,
		float(Tuning.grid_h) * Tuning.cell_h + pad
	)


func _draw_chunk() -> void:
	var top := _chunk_top()
	var body := Rect2(top.position, Vector2(top.size.x, top.size.y + Tuning.chunk_front))
	var right := Rect2(body.end.x, body.position.y, Tuning.cell_side, body.size.y)
	var front := Rect2(body.position.x, top.end.y, body.size.x, Tuning.chunk_front)
	var surface := Tuning.chunk_top_color()
	var side := Tuning.chunk_side_color()
	var line := Tuning.chunk_line_color()
	draw_rect(right, side)
	draw_rect(right, line, false, 3.0)
	draw_rect(top, surface)
	draw_rect(front, side)
	draw_rect(body, line, false, 3.0)


func _draw_cell_sides(x: int, y: int) -> void:
	var top := _punched_rect(_top_rect(x, y), Vector2i(x, y))
	var face := _cell_face_color(x, y)
	if y + 1 >= Tuning.grid_h:
		return
	var below := _punched_rect(_top_rect(x, y + 1), Vector2i(x, y + 1))
	var drop := below.position.y - top.end.y
	if drop <= Tuning.cell_gap + 1.0:
		return
	var step := Rect2(top.position.x, top.end.y, top.size.x, drop)
	draw_rect(step, face)
	draw_rect(step, Tuning.chunk_line_color(), false, 1.0)


func _cell_face_color(x: int, y: int) -> Color:
	var cell := Vector2i(x, y)
	if _is_exposed_fossil(cell):
		return _bone_color(cell).darkened(0.28)
	var layer: int = _top_layer[x][y]
	if layer >= Tuning.layer_count:
		return Color("1A1410")
	return Tuning.color_for_layer(layer).darkened(0.32)


func _draw_top(x: int, y: int) -> void:
	var cell := Vector2i(x, y)
	var rect := _punched_rect(_top_rect(x, y), cell)
	var layer: int = _top_layer[x][y]
	var color: Color
	if _is_exposed_fossil(cell):
		color = _bone_color(cell)
		if _bone_pulse > 0.0:
			color = color.lerp(Color("FFF4D2"), _bone_pulse * 0.7)
	elif layer >= Tuning.layer_count:
		color = Color("1A1410")
	else:
		color = Tuning.color_for_layer(layer)
	draw_rect(rect, color)
	draw_rect(rect, Tuning.cell_line, false, 1.5)
	var edge := 0.18
	if _is_exposed_fossil(cell):
		edge += float(cleanliness.get(cell, 0.0)) * 0.22
	draw_rect(rect.grow(-1.0), color.lightened(edge), false, 1.0)
	_draw_cracks(rect, cell, layer)
	if not _is_exposed_fossil(cell) and layer < Tuning.layer_count:
		_draw_inclusion(rect, cell)
	if _is_exposed_fossil(cell):
		_draw_bone_mark(rect, cell, float(cleanliness.get(cell, 0.0)))
		_draw_dust_specks(rect, cell, float(cleanliness.get(cell, 0.0)))


func _draw_bone_pulse() -> void:
	if _bone_pulse <= 0.0 or exposed_cells.is_empty():
		return
	var glow := Color("FFF1C4", 0.15 + _bone_pulse * 0.55)
	for cell in exposed_cells:
		var rect := _punched_rect(_top_rect(cell.x, cell.y), cell).grow(2.0 + _bone_pulse * 3.0)
		draw_rect(rect, glow, false, 2.0 + _bone_pulse * 2.5)
	var center := fossil_centroid()
	var ring := 18.0 + (1.0 - _bone_pulse) * 56.0
	draw_arc(center, ring, 0.0, TAU, 40, Color("E4B75A", _bone_pulse * 0.85), 3.0)
	draw_arc(center, ring * 0.62, 0.0, TAU, 32, Color("FFF4D2", _bone_pulse * 0.45), 2.0)


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


func _bone_color(cell: Vector2i) -> Color:
	var clean: float = float(cleanliness.get(cell, 0.0))
	var dusty := Color("5A4330")
	var dull := Color("C2A27C")
	var ivory := Color("F7E9C6")
	var color := dusty.lerp(dull, clampf(clean * 1.35, 0.0, 1.0))
	if clean > 0.45:
		color = color.lerp(ivory, clampf((clean - 0.45) / 0.55, 0.0, 1.0))
	return color.lerp(Color("8A6A3E"), (1.0 - integrity) * 0.4)


func _draw_bone_mark(rect: Rect2, cell: Vector2i, clean: float) -> void:
	var find := _find_at(cell)
	var data: FossilDataScript = find.get("data", fossil) as FossilDataScript
	var mark := Color("8A7355").lerp(Color("FFF4D6"), clean)
	if data != null:
		data.draw_silhouette(self, rect.grow(-6.0), mark)
		return
	draw_rect(rect.grow(-8.0), mark, false, 2.0)


func _draw_inclusion(rect: Rect2, cell: Vector2i) -> void:
	var find: Dictionary = pending_find(cell)
	if find.is_empty():
		return
	var rarity: int = int(find.get("rarity", 0))
	var strength: float = Matrix.tell_strength(rarity)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(cell.x * 91 + cell.y * 53 + rarity * 17 + int(find.get("amount", 0)))
	var pos := rect.position + Vector2(
		5.0 + rng.randf() * maxf(6.0, rect.size.x - 10.0),
		5.0 + rng.randf() * maxf(6.0, rect.size.y - 10.0)
	)
	if rarity <= Matrix.RARITY_COMMON:
		draw_circle(pos, 1.35, Color(0.22, 0.15, 0.1, 0.38 + strength * 0.2))
		return
	var kind: String = Matrix.icon_kind(find)
	var radius: float = 2.4 + strength * 3.2
	Matrix.draw_icon(self, kind, pos, radius, 0.42 + strength * 0.38, rarity)


func _draw_dust_specks(rect: Rect2, cell: Vector2i, clean: float) -> void:
	var specks := int(round((1.0 - clean) * 10.0))
	if specks <= 0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = int(cell.x * 41 + cell.y * 73 + 11)
	for i in specks:
		var pos := rect.position + Vector2(6.0 + rng.randf() * (rect.size.x - 12.0), 6.0 + rng.randf() * (rect.size.y - 12.0))
		draw_circle(pos, 1.6, Color(0.28, 0.2, 0.12, 0.55))


func _draw_fx(c: CanvasItem) -> void:
	_draw_boost_ring(c)
	_draw_tool_cursor(c)


func _draw_boost_ring(c: CanvasItem) -> void:
	if _boost_flash <= 0.0:
		return
	var radius: float = 16.0 + (1.0 - _boost_flash) * 52.0
	c.draw_arc(_boost_pos, radius, 0.0, TAU, 36, Color("FFE08A", _boost_flash * 0.9), 3.5)
	c.draw_arc(_boost_pos, radius * 0.62, 0.0, TAU, 28, Color("FFF4D2", _boost_flash * 0.45), 2.0)


func _draw_tool_cursor(c: CanvasItem) -> void:
	var pos := _mouse_world()
	var color := Color("F2E6C4")
	var boosted := has_boosted_tool(current_tool)
	if _using_hands():
		color = Color("E8C9A0")
		c.draw_circle(pos, 5.0, color)
		c.draw_arc(pos, 9.0, 0.0, TAU, 16, color, 2.0)
		c.draw_string(ThemeDB.fallback_font, pos + Vector2(12, -10), "HANDS", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, color)
		return
	match current_tool:
		Tuning.TOOL_SHOVEL:
			color = Color("FFE08A") if boosted else Color("D4A017")
			c.draw_circle(pos, 6.0 if boosted else 5.0, color)
			if Tuning.shovel_radius <= 0.0:
				c.draw_arc(pos, 10.0, 0.0, TAU, 16, color, 2.0)
			else:
				var ring: float = Tuning.shovel_radius * Tuning.cell_w * 0.45
				c.draw_arc(pos, ring, 0.0, TAU, 24, color, 3.2 if boosted else 2.0)
				if boosted:
					var wobble: float = 5.0 + sin(float(Time.get_ticks_msec()) * 0.012) * 2.0
					c.draw_arc(pos, ring + wobble, 0.0, TAU, 28, Color("FFF4D2", 0.5), 2.0)
		Tuning.TOOL_PICKAXE:
			color = Color("FF7A5C") if boosted else Color("D94A3D")
			var reach: float = 14.0 if boosted else 10.0
			c.draw_line(pos + Vector2(-reach, 0), pos + Vector2(reach, 0), color, 4.0 if boosted else 3.0)
			c.draw_line(pos + Vector2(0, -reach), pos + Vector2(0, reach), color, 4.0 if boosted else 3.0)
		Tuning.TOOL_BRUSH:
			color = Color("A6E4F5") if boosted else Color("7EC8E3")
			var puff: float = 11.0 if boosted else 7.0
			c.draw_circle(pos, puff, Color(0.5, 0.8, 0.9, 0.28 if boosted else 0.25))
			c.draw_arc(pos, puff + 2.0, 0.0, TAU, 20, color, 2.5 if boosted else 2.0)
	var label: String = Tuning.TOOL_NAMES[current_tool]
	c.draw_string(ThemeDB.fallback_font, pos + Vector2(12, -10), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, color)


class _FxOverlay extends Node2D:
	var host: Node2D

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if host != null and host.has_method("_draw_fx"):
			host.call("_draw_fx", self)
