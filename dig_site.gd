class_name DigSite
extends Node2D

const FossilDataScript := preload("res://fossil_data.gd")
const Lucky := preload("res://lucky_strike.gd")
const Matrix := preload("res://matrix_find.gd")
const ArtCatalogScript := preload("res://art_catalog.gd")
const UiStyle := preload("res://ui_style.gd")
const FindChipScript := preload("res://find_chip.gd")

signal layer_cleared(amount: int, world_pos: Vector2)
signal fossil_cell_exposed(world_pos: Vector2, first: bool)
signal fossil_extracted(fossil_name: String, value: int, condition: int, cleanliness: float, clean: bool, piece_id: String)
signal pickaxe_struck
signal fossil_hit
signal fossil_ready_to_dust(find_index: int)
signal tool_used(tool: int)
signal lucky_struck(amount: int, world_pos: Vector2)
signal lucky_fled
signal bone_sensed(world_pos: Vector2)
## A bone was fully uncovered and its hidden condition (1 Poor .. 5 Perfect) shows.
signal condition_revealed(find_index: int, condition: int, world_pos: Vector2)
## A fragile or opal bone first meets open air.
signal bone_kind_seen(find_index: int, kind: int, world_pos: Vector2)
## Open air cost a crumbling bone one condition step.
signal bone_crumbled(find_index: int, condition: int, world_pos: Vector2)
## A bone was wrapped in a plaster cast and collected.
signal bone_cast(find_index: int, world_pos: Vector2)
## The first cell of a find came into view (its card appears now).
signal find_spotted(find_index: int, world_pos: Vector2)

var input_enabled: bool = true
var current_tool: int = Tuning.TOOL_HANDS
var deepest_layer: int = 0
## Tools never damage bone; kept for callers that still read it.
var integrity: float = 1.0
## Condition (1 Poor .. 5 Perfect) of the focused find.
var condition: int = Tuning.CONDITION_GOOD
var extracted: bool = false
var extracted_clean: bool = false
var fossil: FossilDataScript
var fossil_origin := Vector2i.ZERO
var fossil_layer: int = 0
var fossil_cells: Dictionary = {}
var exposed_cells: Dictionary = {}
var cleanliness: Dictionary = {}
## Per exposed bone cell: a DUST_COLS x DUST_ROWS grid of dust (1 = caked, 0 = wiped).
var dust: Dictionary = {}
var sensed_cells: Dictionary = {}
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
var _cast_hold: float = 0.0
var _cast_index: int = -1

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
	dust.clear()
	sensed_cells.clear()
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
	_cast_hold = 0.0
	_cast_index = -1
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
	_cast_hold = 0.0
	_cast_index = -1
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
	return _find_preview_value(_focused_find())


func live_find_cards() -> Array:
	var cards: Array = []
	for i in finds.size():
		cards.append(_card_for_find(i))
	return cards


func find_centroid(index: int) -> Vector2:
	if index < 0 or index >= finds.size():
		return fossil_centroid()
	return _find_centroid(finds[index])


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
		var extra: FossilDataScript = _pick_extra(pool)
		if extra == null:
			break
		_try_place_find(extra)


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


func _pick_extra(pool: Array) -> FossilDataScript:
	var choices: Array = []
	for extra in pool:
		var data: FossilDataScript = extra as FossilDataScript
		if data == null:
			continue
		var extra_id: String = data.piece_id if data.piece_id != "" else data.name.to_snake_case()
		if _unique_piece_already_in_pit(extra_id):
			continue
		choices.append(data)
	if choices.is_empty():
		return null
	return choices[randi() % choices.size()] as FossilDataScript


func _unique_piece_already_in_pit(piece_id: String) -> bool:
	if piece_id.is_empty() or GameState.piece_need(piece_id) > 1:
		return false
	for find in finds:
		if str(find.get("piece_id", "")) == piece_id:
			return true
	return false


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
			"condition": Tuning.roll_condition(),
			"kind": Tuning.roll_bone_kind(),
			"air": 0.0,
			"crumbled": 0,
			"cast": false,
			"kind_seen": false,
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
	integrity = 1.0
	condition = int(find.get("condition", Tuning.CONDITION_GOOD))
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
		_cast_hold = 0.0
		_redraw_grid_if_dirty()
		return
	tick_crumble(delta)
	var holding := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var aiming := _cell_at(_mouse_world())
	_tick_cast(delta, holding, aiming)
	if _holding_dig and holding and GameState.hold_unlocked() and _is_strike_tool():
		if _is_exposed_fossil(aiming):
			## Uncovered bone is safe from every tool; just pause the swing.
			_hold_time = 0.0
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
		if _brushing and mouse.distance_to(_brush_last) > 0.15:
			brush_stroke(_brush_last, mouse)
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
				brush_stroke(_brush_last, _brush_last)


func _mouse_world() -> Vector2:
	return get_global_mouse_position()


func _in_bounds(cell: Vector2i) -> bool:
	if _top_layer.is_empty():
		return false
	return cell.x >= 0 and cell.y >= 0 and cell.x < _top_layer.size() and cell.y < _top_layer[0].size()


func _max_depth_offset() -> float:
	var plan_last_end: float = Tuning.pit_face_bottom() - Tuning.cell_gap
	var ceiling: float = Tuning.pit_face_bottom() + Tuning.chunk_front - 4.0
	return maxf(0.0, ceiling - plan_last_end)


func _depth_offset(x: int, y: int) -> float:
	if _top_layer.is_empty():
		return 0.0
	var raw: float = float(_layer_at(x, y)) * Tuning.wall_per_layer
	return minf(raw, _depth_cap if _drawing else _max_depth_offset())


func _top_rect(x: int, y: int) -> Rect2:
	return Rect2(
		Tuning.grid_origin.x + float(x) * Tuning.cell_w,
		Tuning.grid_origin.y + float(y) * Tuning.cell_h + _depth_offset(x, y),
		Tuning.cell_w - Tuning.cell_gap,
		Tuning.cell_h - Tuning.cell_gap
	)


func _layer_at(x: int, y: int) -> int:
	if _top_layer.is_empty() or x < 0 or x >= _top_layer.size():
		return Tuning.layer_count
	if y < 0 or y >= _top_layer[x].size():
		return Tuning.layer_count
	return int(_top_layer[x][y])


func cell_center(cell: Vector2i) -> Vector2:
	return _top_rect(cell.x, cell.y).get_center()


func _cell_at(world: Vector2) -> Vector2i:
	## Column x-extents do not depend on depth, so only the aimed column and its
	## neighbors can match; scan those bottom-up like the full-grid search did.
	var col: int = floori((world.x - Tuning.grid_origin.x) / maxf(Tuning.cell_w, 0.001))
	var x_from: int = maxi(col - 1, 0)
	var x_to: int = mini(col + 1, Tuning.grid_w - 1)
	for y in range(Tuning.grid_h - 1, -1, -1):
		for x in range(x_from, x_to + 1):
			if _top_rect(x, y).grow(2.0).has_point(world):
				return Vector2i(x, y)
	var gx := floori((world.x - Tuning.grid_origin.x) / Tuning.cell_w)
	var gy := floori((world.y - Tuning.grid_origin.y) / Tuning.cell_h)
	var fallback := Vector2i(gx, gy)
	if _in_bounds(fallback):
		return fallback
	return Vector2i(-1, -1)


func _tool_cursor_visible_at(world: Vector2) -> bool:
	return _in_bounds(_cell_at(world))


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
		KEY_1:
			return Tuning.TOOL_HANDS
		KEY_2:
			return Tuning.TOOL_SHOVEL
		KEY_3:
			return Tuning.TOOL_PICKAXE
		KEY_4:
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
	else:
		_sense_bone(center)
	var targets: Array[Vector2i] = Tuning.shovel_hit_cells(center, radius)
	_collect_lucky(targets)
	for cell in targets:
		if not _in_bounds(cell):
			continue
		if _is_exposed_fossil(cell):
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


func _sense_bone(center: Vector2i) -> void:
	## Hands are the survey tool: feel for bone under the surrounding cells.
	var radius: float = Tuning.hands_sense_radius
	if radius <= 0.0:
		return
	var fresh: bool = false
	for cell in Tuning.shovel_hit_cells(center, radius):
		if not _in_bounds(cell) or sensed_cells.has(cell) or exposed_cells.has(cell):
			continue
		var find := _find_at(cell)
		if find.is_empty() or bool(find.get("extracted", false)):
			continue
		sensed_cells[cell] = true
		fresh = true
	if fresh:
		_grid_dirty = true
		Sfx.play("sense")
		bone_sensed.emit(cell_center(center))


func is_sensed(cell: Vector2i) -> bool:
	return sensed_cells.has(cell) and not exposed_cells.has(cell)


func _apply_pickaxe(center: Vector2i, style_mult: float, is_click: bool) -> void:
	_strike_finds.clear()
	if not _in_bounds(center):
		return
	var heard := false
	var pick_cells: Array[Vector2i] = Tuning.shovel_hit_cells(center, Tuning.pickaxe_radius)
	_collect_lucky(pick_cells)
	var juice_layer: int = _top_layer[center.x][center.y]
	var struck: int = 0
	var payout: int = 0
	var punch_hits: Array[Vector3i] = []
	for cell in pick_cells:
		if not _in_bounds(cell):
			continue
		if _is_exposed_fossil(cell):
			continue
		var splash := cell != center
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


func brush_radius() -> float:
	return maxf(4.0, Tuning.cell_h * Tuning.brush_radius_frac) + Tuning.brush_reach_px


func brush_strength() -> float:
	## Layers of dirt one pass lifts. Starter brush = half a layer.
	var scale: float = Tuning.brush_base_strength / 0.0015
	return clampf(Tuning.brush_clean_per_pixel * scale, 0.25, Tuning.brush_max_strength)


func dust_layers(cell: Vector2i) -> int:
	var find := _find_at(cell)
	if find.is_empty():
		return 1
	return Tuning.dust_layers_for(int(find.get("layer", 0)))


func brush_stroke(from: Vector2, to: Vector2) -> void:
	## Wipe dust along the stroke. A patch loses one "pass" worth of dirt per
	## full bristle-width of travel, so frame rate and slow dragging don't
	## multiply cleaning; a click without moving is a small dab.
	if exposed_cells.is_empty():
		return
	var radius: float = brush_radius()
	var travel: float = from.distance_to(to)
	var share: float = clampf(travel / (radius * 2.0), Tuning.brush_dab, 1.0)
	var strength: float = brush_strength() * share
	var steps: int = maxi(1, int(ceil(from.distance_to(to) / maxf(radius * 0.5, 1.0))))
	var hit: Dictionary = {}
	var touched: Dictionary = {}
	var lifted: float = 0.0
	for step in steps + 1:
		var p: Vector2 = from.lerp(to, float(step) / float(steps))
		for raw in exposed_cells:
			var cell: Vector2i = raw
			if not dust.has(cell):
				continue
			var find := _find_at(cell)
			if find.is_empty() or bool(find.get("extracted", false)) or bool(find.get("cast", false)):
				continue
			var rect := _top_rect(cell.x, cell.y)
			if _distance_to_rect(p, rect) > radius:
				continue
			lifted += _wipe_cell(cell, rect, p, radius, strength, hit)
			touched[cell] = true
	if touched.is_empty():
		return
	var ready: Array = []
	for raw in touched:
		var cell: Vector2i = raw
		cleanliness[cell] = _dust_clean(cell)
		var find := _find_at(cell)
		if not ready.has(find):
			ready.append(find)
	_grid_dirty = true
	if lifted > 0.0:
		_puff_dust(to, clampf(lifted * 0.05, 0.0, 1.0))
		if from.distance_to(to) > 4.0:
			Sfx.play("dust")
	var first: Vector2i = touched.keys()[0]
	_mark_tool_used(Tuning.TOOL_BRUSH, cell_center(first))
	_focus_find(_find_at(first))
	for raw in ready:
		var find: Dictionary = raw
		if _find_is_fully_exposed(find) and _find_clean(find) >= Tuning.clean_extract_threshold:
			_finish_cleaning(find)
			_extract_find(find, true)


func _wipe_cell(cell: Vector2i, rect: Rect2, p: Vector2, radius: float, strength: float, hit: Dictionary) -> float:
	var grid: PackedFloat32Array = dust[cell]
	var cw: float = rect.size.x / float(Tuning.DUST_COLS)
	var ch: float = rect.size.y / float(Tuning.DUST_ROWS)
	var lifted: float = 0.0
	for row in Tuning.DUST_ROWS:
		for col in Tuning.DUST_COLS:
			var center := rect.position + Vector2((float(col) + 0.5) * cw, (float(row) + 0.5) * ch)
			if center.distance_to(p) > radius:
				continue
			var i: int = row * Tuning.DUST_COLS + col
			var key := Vector3i(cell.x, cell.y, i)
			if hit.has(key):
				continue
			hit[key] = true
			var before: float = grid[i]
			if before <= 0.0:
				continue
			grid[i] = maxf(0.0, before - strength)
			lifted += before - grid[i]
	dust[cell] = grid
	return lifted


func _dust_clean(cell: Vector2i) -> float:
	if not dust.has(cell):
		return float(cleanliness.get(cell, 0.0))
	var grid: PackedFloat32Array = dust[cell]
	var left: float = 0.0
	for v in grid:
		left += v
	var full: float = float(maxi(grid.size(), 1) * dust_layers(cell))
	return clampf(1.0 - left / full, 0.0, 1.0)


func _finish_cleaning(find: Dictionary) -> void:
	## Past the threshold the last flecks fall away on their own.
	var cells: Dictionary = find.get("cells", {})
	for raw in cells:
		var cell: Vector2i = raw
		if dust.has(cell):
			var grid: PackedFloat32Array = dust[cell]
			grid.fill(0.0)
			dust[cell] = grid
		cleanliness[cell] = 1.0


static func _distance_to_rect(point: Vector2, rect: Rect2) -> float:
	var nearest := Vector2(
		clampf(point.x, rect.position.x, rect.end.x),
		clampf(point.y, rect.position.y, rect.end.y)
	)
	return point.distance_to(nearest)


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
	var caked := PackedFloat32Array()
	caked.resize(Tuning.DUST_COLS * Tuning.DUST_ROWS)
	caked.fill(float(dust_layers(cell)))
	dust[cell] = caked
	var layer: int = int(find["layer"])
	if _top_layer[cell.x][cell.y] < layer:
		_top_layer[cell.x][cell.y] = layer
	if layer > deepest_layer:
		deepest_layer = layer
	_focus_find(find)
	_grid_dirty = true
	fossil_cell_exposed.emit(cell_center(cell), first)
	if not bool(find.get("spotted", false)):
		find["spotted"] = true
		find_spotted.emit(int(fossil_cells.get(cell, -1)), cell_center(cell))
	var kind: int = int(find.get("kind", Tuning.BONE_SOLID))
	if Tuning.bone_crumbles(kind) and not bool(find.get("kind_seen", false)):
		find["kind_seen"] = true
		bone_kind_seen.emit(int(fossil_cells.get(cell, -1)), kind, cell_center(cell))
	if first:
		Sfx.play("fossil_ping")
	_grace_left = Tuning.fossil_grace
	if _find_is_fully_exposed(find) and not bool(find.get("ready", false)):
		find["ready"] = true
		pulse_bones()
		var index: int = int(fossil_cells.get(cell, -1))
		fossil_ready_to_dust.emit(index)
		condition_revealed.emit(index, int(find.get("condition", Tuning.CONDITION_GOOD)), _find_centroid(find))


func _find_in_air(find: Dictionary) -> bool:
	var cells: Dictionary = find.get("cells", {})
	for cell in cells:
		if exposed_cells.has(cell):
			return true
	return false


func find_is_crumbling(find: Dictionary) -> bool:
	if find.is_empty() or bool(find.get("extracted", false)) or bool(find.get("cast", false)):
		return false
	return Tuning.bone_crumbles(int(find.get("kind", 0))) and _find_in_air(find)


## Seconds until this bone crumbles again (INF when it is safe).
func crumble_in(find: Dictionary) -> float:
	if not find_is_crumbling(find) or int(find.get("condition", 1)) <= Tuning.CONDITION_POOR:
		return INF
	return Tuning.seconds_to_next_crumble(int(find["kind"]), float(find.get("air", 0.0)))


func tick_crumble(delta: float) -> void:
	## Fragile and opal bones lose condition the longer they sit in open air.
	for i in finds.size():
		var find: Dictionary = finds[i]
		if not find_is_crumbling(find):
			continue
		find["air"] = float(find.get("air", 0.0)) + delta
		var due: int = Tuning.crumbles_after(int(find["kind"]), float(find["air"]))
		while int(find.get("crumbled", 0)) < due and int(find.get("condition", 1)) > Tuning.CONDITION_POOR:
			find["condition"] = int(find["condition"]) - 1
			find["crumbled"] = int(find.get("crumbled", 0)) + 1
			_grid_dirty = true
			if i == _focus_index:
				condition = int(find["condition"])
			Sfx.play("crack")
			bone_crumbled.emit(i, int(find["condition"]), _find_centroid(find))
		if int(find.get("condition", 1)) <= Tuning.CONDITION_POOR:
			find["crumbled"] = maxi(int(find.get("crumbled", 0)), due)


func cast_progress() -> float:
	if _cast_index < 0 or not Tuning.cast_owned():
		return 0.0
	return clampf(_cast_hold / Tuning.cast_hold_seconds(), 0.0, 1.0)


func _castable(find: Dictionary) -> bool:
	## Only bones that crumble can be plastered; it protects, it doesn't collect.
	if find.is_empty() or bool(find.get("extracted", false)) or bool(find.get("cast", false)):
		return false
	return Tuning.bone_crumbles(int(find.get("kind", 0))) and _find_is_fully_exposed(find)


func _tick_cast(delta: float, holding: bool, aiming: Vector2i) -> void:
	## Plaster Cast: hold Hands on a dug-out bone to wrap and collect it.
	var find := _find_at(aiming) if _is_exposed_fossil(aiming) else {}
	if not holding or not _using_hands() or not Tuning.cast_owned() or not _castable(find):
		_cast_hold = 0.0
		_cast_index = -1
		return
	var index: int = finds.find(find)
	if index != _cast_index:
		_cast_index = index
		_cast_hold = 0.0
	_cast_hold += delta
	if _cast_hold >= Tuning.cast_hold_seconds():
		cast_find(index)


func cast_find(index: int) -> void:
	if index < 0 or index >= finds.size():
		return
	var find: Dictionary = finds[index]
	if not _castable(find):
		return
	find["cast"] = true
	_cast_hold = 0.0
	_cast_index = -1
	_grid_dirty = true
	var pos: Vector2 = _find_centroid(find)
	_burst(pos, int(find.get("layer", 0)), true)
	Sfx.play("buy")
	## Wrapped bones stay in the pit, safe from crumbling, and are collected
	## (still dirty) when the shift ends. They can no longer be brushed.
	bone_cast.emit(index, pos)


func _can_harm_fossil() -> bool:
	## Tools never damage bone.
	return false


func pulse_bones() -> void:
	_bone_pulse = 1.0
	_grid_dirty = true
	queue_redraw()


func fossil_centroid() -> Vector2:
	return _find_centroid(_focused_find())


func _find_preview_value(find: Dictionary) -> int:
	if find.is_empty():
		return 0
	var data = find.get("data", null)
	if data == null:
		return 0
	return _find_value(find, data)


func _find_value(find: Dictionary, data) -> int:
	## Value = base x condition x how clean it is.
	var clean := _find_clean(find)
	var cond: float = Tuning.condition_value(int(find.get("condition", Tuning.CONDITION_GOOD)))
	var kind: float = Tuning.bone_kind_value[clampi(int(find.get("kind", 0)), 0, 2)]
	var quality := lerpf(Tuning.unbrushed_value, 1.0, clean)
	var fame: float = GameState.fame_mult() if GameState.has_method("fame_mult") else 1.0
	return int(round(float(data.base_value) * cond * kind * quality * Tuning.fossil_value_mult * fame))


func _find_centroid(find: Dictionary) -> Vector2:
	var cells: Dictionary = find.get("cells", {})
	if cells.is_empty():
		return Tuning.grid_origin + Vector2(float(Tuning.grid_w) * Tuning.cell_w, float(Tuning.grid_h) * Tuning.cell_h) * 0.5
	var sum := Vector2.ZERO
	for cell in cells:
		sum += _safe_cell_center(cell)
	return sum / float(cells.size())


func _safe_cell_center(cell: Vector2i) -> Vector2:
	if _top_layer.is_empty() or cell.x < 0 or cell.x >= _top_layer.size():
		return Tuning.grid_origin + Vector2((float(cell.x) + 0.5) * Tuning.cell_w, (float(cell.y) + 0.5) * Tuning.cell_h)
	return cell_center(cell)


func _card_for_find(index: int) -> Dictionary:
	var find: Dictionary = finds[index]
	var data = find.get("data", null)
	var find_name: String = ""
	if data != null:
		find_name = str(data.name)
	var cells: Dictionary = find.get("cells", {})
	var needed: int = cells.size()
	var exposed: int = 0
	for cell in cells:
		if exposed_cells.has(cell):
			exposed += 1
	var bagged: bool = bool(find.get("extracted", false))
	var fully: bool = needed > 0 and exposed >= needed
	var status: String = "underground"
	if bagged:
		status = "bagged"
	elif fully:
		status = "brush"
	elif exposed > 0:
		status = "uncovering"
	var cond: int = int(find.get("condition", Tuning.CONDITION_GOOD))
	var clean: float = _find_clean(find)
	var piece_id: String = str(find.get("piece_id", ""))
	var named: bool = bagged or fully
	var progress: String = ""
	if named and GameState.has_method("uncover_status_line"):
		progress = str(GameState.uncover_status_line(piece_id))
	return {
		"index": index,
		"name": find_name if named else "Bone",
		"piece_id": piece_id,
		"status": status,
		"stars": cond if named else 0,
		"grade": Tuning.condition_label(cond) if named else "",
		"condition": cond if named else 0,
		"kind": int(find.get("kind", Tuning.BONE_SOLID)),
		"kind_name": Tuning.bone_kind_name(int(find.get("kind", Tuning.BONE_SOLID))),
		"crumble_in": crumble_in(find),
		"crumbled": int(find.get("crumbled", 0)),
		"cast": bool(find.get("cast", false)),
		"dirt": Tuning.dirt_label(clean) if exposed > 0 or bagged else "",
		"value": _find_preview_value(find),
		"fate": str(find.get("fate", "")),
		"progress": progress,
		"integrity": 1.0,
		"clean": clean,
		"exposed": exposed,
		"needed": needed,
		"centroid": _find_centroid(find),
		"fully_exposed": fully,
		"extracted": bagged,
		"data": data,
	}


func set_find_fate(piece_id: String, fate: String) -> void:
	for find in finds:
		if str(find.get("piece_id", "")) == piece_id:
			find["fate"] = fate


func find_index_for(piece_id: String) -> int:
	for i in finds.size():
		if str(finds[i].get("piece_id", "")) == piece_id:
			return i
	return -1


func _hit_fossil(_cell: Vector2i) -> void:
	## Bone breaking was removed: condition comes from the ground, not the tool.
	pass


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
	var cond: int = int(find.get("condition", Tuning.CONDITION_GOOD))
	find["extracted"] = true
	find["extracted_clean"] = clean >= Tuning.clean_extract_threshold
	_focus_find(find)
	var data: FossilDataScript = find["data"]
	var value: int = _find_value(find, data)
	extracted = true
	extracted_clean = bool(find["extracted_clean"])
	fossil = data
	condition = cond
	Sfx.play("extract")
	fossil_extracted.emit(data.name, value, cond, clean, bool(find["extracted_clean"]), str(find.get("piece_id", "")))


func _play_hit(layer: int) -> void:
	if not Tuning.tool_works_on(current_tool, layer):
		Sfx.play("tool_refuse")
		return
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
	var juice_cap: int = 2 if Tuning.material_at_layer(juice_layer) <= Tuning.MAT_PACKED else 5
	_matrix_juice = Matrix.batch_display(_strike_finds, juice_cap)
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
	var squash := Vector2(0.22, 0.32)
	match kind:
		PUNCH_BONE:
			squash = Vector2(0.06, 0.16)
		PUNCH_FIRM:
			squash = Vector2(0.10, 0.14)
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
	_particles.amount = (36 if rock else 28) if fat else (28 if rock else 20)
	_particles.scale_amount_min = 1.8 if rock else 1.15
	_particles.scale_amount_max = 3.2 if rock else 2.0
	_particles.lifetime = 0.62 if rock else 0.42
	_particles.initial_velocity_min = 48.0 if rock else 44.0
	_particles.initial_velocity_max = 150.0 if rock else 130.0
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


var _drawing: bool = false
var _depth_cap: float = 0.0
var _rects: Array[Rect2] = []
var _rects_h: int = 0
var _cell_tex: Dictionary = {}


func _draw() -> void:
	_draw_chunk()
	if _top_layer.is_empty():
		return
	var width: int = _top_layer.size()
	var height: int = _top_layer[0].size()
	## A 16x10 redraw used to recompute every rect (and resolve cell art) 3-4x
	## per cell through autoload lookups. Build the punched rects once per draw.
	_depth_cap = _max_depth_offset()
	_drawing = true
	_rects_h = height
	_rects.resize(width * height)
	for x in width:
		for y in height:
			_rects[x * height + y] = _punched_rect(_top_rect(x, y), Vector2i(x, y))
	_cell_tex.clear()
	for y in height:
		for x in width:
			_draw_cell_sides(x, y)
			_draw_top(x, y)
	_drawing = false
	_draw_bone_pulse()
	_draw_find_markers()
	_draw_lucky()


func _chunk_top() -> Rect2:
	return SiteBackdrop.pit_cutout()


func north_face_h() -> float:
	return maxf(Tuning.grid_origin.y - _chunk_top().position.y, Tuning.chunk_pad)


func north_face_rect() -> Rect2:
	var top := _chunk_top()
	return Rect2(top.position.x, top.position.y, top.size.x, north_face_h())


func west_face_rect() -> Rect2:
	var top := _chunk_top()
	return Rect2(top.position.x, top.position.y, Tuning.chunk_pad, top.size.y + Tuning.chunk_front)


func east_face_rect() -> Rect2:
	var top := _chunk_top()
	return Rect2(top.end.x - Tuning.chunk_pad, top.position.y, Tuning.chunk_pad, top.size.y + Tuning.chunk_front)


const STRATA_TEXELS := 8
static var _strata_tex: Dictionary = {}


func _draw_strata_stack(rect: Rect2, start_layer: int, in_shadow: bool = true) -> void:
	## One textured rect per wall instead of two draw calls per layer; the
	## pit walls alone used to be ~900 canvas commands at the 16x10 claim.
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var from_layer: int = clampi(start_layer, 0, Tuning.layer_count)
	var remaining: int = Tuning.layer_count - from_layer
	if remaining <= 0:
		draw_rect(rect, Color("1A1410"))
		return
	var tex: Texture2D = _strata_texture(in_shadow)
	var src := Rect2(0.0, float(from_layer * STRATA_TEXELS), 1.0, float(remaining * STRATA_TEXELS))
	draw_texture_rect_region(tex, rect, src)


static func _strata_texture(in_shadow: bool) -> Texture2D:
	if _strata_tex.has(in_shadow):
		return _strata_tex[in_shadow]
	var layers: int = Tuning.layer_count
	var image := Image.create(1, layers * STRATA_TEXELS, false, Image.FORMAT_RGBA8)
	for layer in layers:
		var dirt: Color = Tuning.shaft_interior_color(layer) if in_shadow else Tuning.color_for_layer(layer).darkened(0.28)
		for t in STRATA_TEXELS:
			var line: bool = t == 0 and layer > 0
			image.set_pixel(0, layer * STRATA_TEXELS + t, dirt.darkened(0.14) if line else dirt)
	var tex := ImageTexture.create_from_image(image)
	_strata_tex[in_shadow] = tex
	return tex


func _column_start_layer(x: int, y: int) -> int:
	if _top_layer.is_empty() or x < 0 or x >= _top_layer.size():
		return 0
	if y < 0 or y >= _top_layer[x].size():
		return 0
	return int(_top_layer[x][y])


func _min_column_layer(x: int) -> int:
	if _top_layer.is_empty() or x < 0 or x >= _top_layer.size():
		return 0
	var lowest: int = Tuning.layer_count
	for y in _top_layer[x].size():
		lowest = mini(lowest, int(_top_layer[x][y]))
	return lowest if lowest < Tuning.layer_count else 0


func _draw_shaft_face(face: Rect2, start_layer: int, inner_from_left: bool) -> void:
	if face.size.x <= 0.0 or face.size.y <= 0.0:
		return
	var line := Tuning.chunk_line_color()
	_draw_strata_stack(face, start_layer, true)
	var wall := Tuning.shaft_interior_color(start_layer)
	var shade_w: float = maxf(4.0, face.size.x * 0.45)
	if inner_from_left:
		draw_rect(Rect2(face.position.x, face.position.y, shade_w, face.size.y), wall.darkened(0.16))
		draw_rect(Rect2(face.end.x - 2.0, face.position.y, 2.0, face.size.y), wall.lightened(0.18))
		draw_line(Vector2(face.position.x, face.position.y), Vector2(face.position.x, face.end.y), line, Tuning.chunk_line_width())
	else:
		draw_rect(Rect2(face.end.x - shade_w, face.position.y, shade_w, face.size.y), wall.darkened(0.16))
		draw_rect(Rect2(face.position.x, face.position.y, 2.0, face.size.y), wall.lightened(0.18))
		draw_line(Vector2(face.end.x, face.position.y), Vector2(face.end.x, face.end.y), line, Tuning.chunk_line_width())


func north_face_fill_color() -> Color:
	return Tuning.shaft_interior_color(0)


func shaft_wall_color(x: int, y: int) -> Color:
	if not _in_bounds(Vector2i(x, y)):
		return Tuning.shaft_interior_color(0)
	var cell := Vector2i(x, y)
	if _is_exposed_fossil(cell):
		return _bone_color(cell).darkened(0.42)
	var layer: int = int(_top_layer[x][y])
	return Tuning.shaft_interior_color(layer)


func _north_face_column_rect(x: int) -> Rect2:
	var face := north_face_rect()
	var left: float = Tuning.grid_origin.x + float(x) * Tuning.cell_w
	var right: float = left + Tuning.cell_w
	if x <= 0:
		left = face.position.x
	if x >= Tuning.grid_w - 1:
		right = face.end.x
	return Rect2(left, face.position.y, maxf(right - left, 0.0), face.size.y)


func _draw_north_face() -> void:
	var face := north_face_rect()
	if face.size.y <= 0.0:
		return
	var line := Tuning.chunk_line_color()
	var cols: int = _top_layer.size() if not _top_layer.is_empty() else Tuning.grid_w
	for x in cols:
		var col := _north_face_column_rect(x)
		var start: int = _column_start_layer(x, 0)
		var wall := shaft_wall_color(x, 0)
		_draw_strata_stack(col, start, true)
		draw_rect(Rect2(col.position.x, col.position.y, col.size.x, 2.0), wall.lightened(0.22))
	draw_line(Vector2(face.position.x, face.position.y), Vector2(face.end.x, face.position.y), line, 2.0)
	draw_line(Vector2(face.position.x, face.end.y), Vector2(face.end.x, face.end.y), line, 2.0)


func _draw_west_face() -> void:
	var face := west_face_rect()
	_draw_shaft_face(face, _min_column_layer(0), true)


func _draw_east_face() -> void:
	var face := east_face_rect()
	var last_x: int = (_top_layer.size() - 1) if not _top_layer.is_empty() else Tuning.grid_w - 1
	_draw_shaft_face(face, _min_column_layer(last_x), false)


func _draw_chunk() -> void:
	var top := _chunk_top()
	var floor := Rect2(
		Tuning.grid_origin,
		Vector2(float(Tuning.grid_w) * Tuning.cell_w, float(Tuning.grid_h) * Tuning.cell_h)
	)
	var front := Rect2(top.position.x, top.end.y, top.size.x, Tuning.chunk_front)
	var line := Tuning.chunk_line_color()
	draw_rect(floor, Tuning.chunk_top_color().darkened(0.08))
	_draw_strata_stack(front, 0, false)
	_draw_west_face()
	_draw_east_face()
	_draw_north_face()
	draw_rect(Rect2(top.position, Vector2(top.size.x, top.size.y + Tuning.chunk_front)), line, false, Tuning.chunk_line_width())


func _drawn_rect(x: int, y: int) -> Rect2:
	var i: int = x * _rects_h + y
	if _drawing and i >= 0 and i < _rects.size() and y < _rects_h:
		return _rects[i]
	return _punched_rect(_top_rect(x, y), Vector2i(x, y))


func _draw_cell_sides(x: int, y: int) -> void:
	if y + 1 >= Tuning.grid_h:
		return
	var top := _drawn_rect(x, y)
	var below := _drawn_rect(x, y + 1)
	var drop := below.position.y - top.end.y
	if drop <= Tuning.cell_gap + 1.0:
		return
	var step := Rect2(top.position.x, top.end.y, top.size.x, drop)
	var face := _cell_face_color(x, y)
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


const BONE_FLASH := Color("FFF4D2")
const VOID_CELL := Color("1A1410")


func _draw_top(x: int, y: int) -> void:
	var cell := Vector2i(x, y)
	var rect := _drawn_rect(x, y)
	var layer: int = _top_layer[x][y]
	var color: Color
	var painted: bool = false
	var bone: bool = exposed_cells.has(cell)
	if bone:
		color = _bone_color(cell)
		if _bone_pulse > 0.0:
			color = color.lerp(BONE_FLASH, _bone_pulse * 0.7)
	elif layer >= Tuning.layer_count:
		color = VOID_CELL
	else:
		color = Tuning.color_for_layer(layer)
		painted = _draw_cell_art(layer, rect)
	if not painted:
		draw_rect(rect, color)
	draw_rect(rect, Tuning.cell_line, false, 1.5)
	var edge := 0.18
	if bone:
		edge += float(cleanliness.get(cell, 0.0)) * 0.22
	draw_rect(rect.grow(-1.0), color.lightened(edge), false, 1.0)
	if y == 0:
		_draw_north_cell_shade(rect, color)
	_draw_cracks(rect, cell, layer)
	if not bone and layer < Tuning.layer_count:
		_draw_inclusion(rect, cell)
	if not bone and sensed_cells.has(cell):
		_draw_sensed(rect)
	if bone:
		_draw_bone_mark(rect, cell, 1.0)
		var host := _find_at(cell)
		if int(host.get("kind", 0)) == Tuning.BONE_OPAL:
			_draw_opal_glints(rect, cell)
		if bool(host.get("cast", false)):
			_draw_plaster(rect, cell)
		else:
			_draw_dust(rect, cell)


func _draw_cell_art(layer: int, rect: Rect2) -> bool:
	var material: int = Tuning.material_at_layer(layer)
	if not _cell_tex.has(material):
		_cell_tex[material] = ArtCatalogScript.texture("cells", ArtCatalogScript.cell_id_for_material(material))
	var tex: Texture2D = _cell_tex[material]
	if tex == null or rect.size.x < 1.0 or rect.size.y < 1.0:
		return false
	draw_texture_rect(tex, rect, false)
	return true


func _draw_north_cell_shade(rect: Rect2, _color: Color) -> void:
	var h: float = minf(rect.size.y * 0.42, 16.0)
	if h <= 0.0:
		return
	var steps := 5
	var slice: float = h / float(steps)
	for i in steps:
		var fade: float = 1.0 - float(i) / float(steps)
		var wash := Color(0.10, 0.07, 0.05, 0.26 * fade)
		draw_rect(Rect2(rect.position.x, rect.position.y + float(i) * slice, rect.size.x, slice + 0.6), wash)


func _draw_sensed(rect: Rect2) -> void:
	## Bone felt below: ivory corner ticks plus a small bone glyph.
	var ink := Color("FFF1C4", 0.85)
	var tick: float = minf(rect.size.x, rect.size.y) * 0.22
	var r := rect.grow(-3.0)
	for corner in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
		var sx: float = 1.0 if corner.x <= r.get_center().x else -1.0
		var sy: float = 1.0 if corner.y <= r.get_center().y else -1.0
		draw_line(corner, corner + Vector2(tick * sx, 0.0), ink, 2.0)
		draw_line(corner, corner + Vector2(0.0, tick * sy), ink, 2.0)
	var c := rect.get_center()
	var half: float = minf(rect.size.x * 0.18, 12.0)
	var knob: float = maxf(2.0, half * 0.32)
	var bone := Color("F7E9C6", 0.75)
	draw_line(c - Vector2(half, 0.0), c + Vector2(half, 0.0), bone, knob * 1.1)
	for end in [c - Vector2(half, 0.0), c + Vector2(half, 0.0)]:
		draw_circle(end + Vector2(0.0, -knob * 0.6), knob, bone)
		draw_circle(end + Vector2(0.0, knob * 0.6), knob, bone)


func _draw_find_markers() -> void:
	## Outline + numbered dot per find, matching its card in the Finds tray.
	var font: Font = UiStyle.display_font()
	for i in finds.size():
		var find: Dictionary = finds[i]
		var cells: Dictionary = find.get("cells", {})
		var shown: Array = []
		for raw in cells:
			if exposed_cells.has(raw):
				shown.append(raw)
		if shown.is_empty():
			continue
		var col: Color = FindChipScript.color_for(i)
		for raw in shown:
			var cell: Vector2i = raw
			draw_rect(_top_rect(cell.x, cell.y).grow(1.0), col, false, 2.5)
		var first: Vector2i = shown[0]
		var r := _top_rect(first.x, first.y)
		var c := r.position + Vector2(10.0, 10.0)
		draw_circle(c, 9.0, col)
		draw_arc(c, 9.0, 0.0, TAU, 20, Color("1B1410"), 1.5)
		var text := str(i + 1)
		var tw: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		draw_string(font, c + Vector2(-tw * 0.5, 4.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("1B1410"))


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


func _crack_stroke_width() -> float:
	return 1.4


func _dirt_crack_count(damaged: float) -> int:
	return int(round(clampf(damaged, 0.0, 1.0) * 3.0))


func _draw_cracks(rect: Rect2, cell: Vector2i, layer: int) -> void:
	var crack_count := 0
	var crack_color := Color(0.12, 0.08, 0.05, 0.7)
	if _is_exposed_fossil(cell):
		## Old wear from the ground: poorer bones show more cracks once wiped.
		var cond: int = int(_find_at(cell).get("condition", Tuning.CONDITION_GOOD))
		crack_count = maxi(0, 4 - cond)
		crack_color = Color(0.25, 0.16, 0.1, 0.85)
	elif layer < Tuning.layer_count:
		var hp: float = float(_hp[cell.x][cell.y])
		var max_hp := Tuning.hp_for_layer(layer)
		if hp >= max_hp:
			return
		var damaged := 1.0 - clampf(hp / max_hp, 0.0, 1.0)
		crack_count = _dirt_crack_count(damaged)
	_stroke_cracks(rect, crack_count, crack_color)


func _stroke_cracks(rect: Rect2, count: int, color: Color) -> void:
	if count <= 0:
		return
	var seed: int = int(rect.position.x * 17 + rect.position.y * 31 + count * 9)
	var width: float = _crack_stroke_width()
	for i in count:
		var a := rect.position + Vector2(_hash01(seed, i * 4) * rect.size.x, _hash01(seed, i * 4 + 1) * rect.size.y)
		var b := rect.position + Vector2(_hash01(seed, i * 4 + 2) * rect.size.x, _hash01(seed, i * 4 + 3) * rect.size.y)
		draw_line(a, b, color, width)


## Cheap stable noise for per-frame draw code (no RandomNumberGenerator allocs).
static func _hash01(seed: int, i: int) -> float:
	var h: int = (seed * 73856093) ^ ((i + 1) * 19349663)
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(h & 0xFFFF) / 65535.0


const BONE_BY_CONDITION: PackedColorArray = [
	Color("9C8A74"),
	Color("BFA888"),
	Color("D9C29C"),
	Color("EEDDB6"),
	Color("FBF1D6"),
]


const OPAL_BONE := Color("CFE4EE")
const CHALK_BONE := Color("D6CFC4")


func _bone_color(cell: Vector2i) -> Color:
	## The bone under the dust: better condition reads brighter and warmer.
	var find := _find_at(cell)
	var cond: int = int(find.get("condition", Tuning.CONDITION_GOOD))
	var color: Color = BONE_BY_CONDITION[clampi(cond, 1, 5) - 1]
	match int(find.get("kind", Tuning.BONE_SOLID)):
		Tuning.BONE_OPAL:
			color = color.lerp(OPAL_BONE, 0.55)
		Tuning.BONE_FRAGILE:
			color = color.lerp(CHALK_BONE, 0.45)
	return color


func _draw_bone_mark(rect: Rect2, cell: Vector2i, clean: float) -> void:
	var find := _find_at(cell)
	var data: FossilDataScript = find.get("data", fossil) as FossilDataScript
	var piece_id: String = str(find.get("piece_id", ""))
	if piece_id.is_empty() and data != null:
		piece_id = data.piece_id if data.piece_id != "" else data.name.to_snake_case()
	var origin: Vector2i = find.get("origin", fossil_origin) as Vector2i
	var offset: Vector2i = cell - origin
	var src := Rect2(float(offset.x) * 64.0, float(offset.y) * 40.0, 64.0, 40.0)
	var tint: Color = Color("5A4330").lerp(Color.WHITE, clampf(clean, 0.0, 1.0))
	if piece_id != "" and ArtCatalogScript.draw_region_if_present(self, "bones", piece_id, rect, src, tint):
		return
	var mark := Color("8A7355").lerp(Color("FFF4D6"), clean)
	if data != null:
		data.draw_silhouette(self, rect.grow(-6.0), mark)
		return
	draw_rect(rect.grow(-8.0), mark, false, 2.0)


func _draw_inclusion(rect: Rect2, cell: Vector2i) -> void:
	if _pending.is_empty() or not _in_bounds(cell):
		return
	var raw: Variant = _pending[cell.x][cell.y]
	if not (raw is Dictionary) or (raw as Dictionary).is_empty():
		return
	var find: Dictionary = raw
	var rarity: int = int(find.get("rarity", 0))
	var strength: float = Matrix.tell_strength(rarity)
	var seed: int = int(cell.x * 91 + cell.y * 53 + rarity * 17 + int(find.get("amount", 0)))
	var pos := rect.position + Vector2(
		5.0 + _hash01(seed, 0) * maxf(6.0, rect.size.x - 10.0),
		5.0 + _hash01(seed, 1) * maxf(6.0, rect.size.y - 10.0)
	)
	if rarity <= Matrix.RARITY_COMMON:
		draw_circle(pos, 1.35, Color(0.22, 0.15, 0.1, 0.38 + strength * 0.2))
		return
	## icon_kind string-matches the name; resolve it once per rolled find.
	if not find.has("_icon"):
		find["_icon"] = Matrix.icon_kind(find)
	var kind: String = find["_icon"]
	var radius: float = 2.4 + strength * 3.2
	Matrix.draw_icon(self, kind, pos, radius, 0.42 + strength * 0.38, rarity)


const OPAL_FLECKS: PackedColorArray = [Color("FF9ECF"), Color("7FE6F2"), Color("A6F28A"), Color("C9A6FF")]


func _draw_opal_glints(rect: Rect2, cell: Vector2i) -> void:
	## Rainbow flecks read as gemstone, not gold.
	var seed: int = cell.x * 29 + cell.y * 61 + 3
	for i in 5:
		var p := rect.position + Vector2(6.0 + _hash01(seed, i * 2) * (rect.size.x - 12.0), 5.0 + _hash01(seed, i * 2 + 1) * (rect.size.y - 10.0))
		var r: float = 2.0 + _hash01(seed, 9 + i) * 2.5
		draw_circle(p, r, Color(OPAL_FLECKS[i % OPAL_FLECKS.size()], 0.75))


const PLASTER := Color("EFEAE0")
const PLASTER_LINE := Color("C9C0B0")


func _draw_plaster(rect: Rect2, cell: Vector2i) -> void:
	## Plaster straps over a still-visible bone: you can tell what it is, and
	## that it is wrapped (like a cast on an arm), at a glance.
	var strap_w: float = maxf(6.0, rect.size.x * 0.16)
	var slant: float = rect.size.x * 0.12
	for t in [0.28, 0.66]:
		var x: float = rect.position.x + rect.size.x * t + (float(cell.y % 2) - 0.5) * 4.0
		var pts := PackedVector2Array([
			Vector2(x, rect.position.y + 1.0),
			Vector2(x + strap_w, rect.position.y + 1.0),
			Vector2(x + strap_w - slant, rect.end.y - 1.0),
			Vector2(x - slant, rect.end.y - 1.0),
		])
		draw_colored_polygon(pts, Color(PLASTER, 0.92))
		draw_line(pts[0], pts[3], PLASTER_LINE, 1.0)
		draw_line(pts[1], pts[2], PLASTER_LINE, 1.0)
	draw_rect(rect.grow(-1.0), PLASTER, false, 2.5)


## Dirt layers from the surface down: loose dust, caked dirt, clay, crust.
const DUST_LAYER_COLORS: PackedColorArray = [
	Color("9A7C58"),
	Color("6E5236"),
	Color("5A4230"),
	Color("3E3024"),
]


const BONE_RIM := Color("F2E3BE")


func _draw_dust(rect: Rect2, cell: Vector2i) -> void:
	## Dirt sits on the bone as lumpy clumps, not tiles: bone shows between them
	## as you brush, and the bone's shape presses up through what is left.
	if not dust.has(cell):
		return
	var grid: PackedFloat32Array = dust[cell]
	var cw: float = rect.size.x / float(Tuning.DUST_COLS)
	var ch: float = rect.size.y / float(Tuning.DUST_ROWS)
	var lump: float = maxf(cw, ch) * 0.72
	var inner: Rect2 = rect.grow(-lump * 0.55)
	var seed: int = cell.x * 41 + cell.y * 73 + 11
	var left: float = 0.0
	for row in Tuning.DUST_ROWS:
		for col in Tuning.DUST_COLS:
			var i: int = row * Tuning.DUST_COLS + col
			var amount: float = grid[i]
			left += amount
			if amount <= 0.02:
				continue
			## Remaining layers pick the color; the last partial layer thins out.
			var depth: int = clampi(int(ceil(amount)) - 1, 0, DUST_LAYER_COLORS.size() - 1)
			var shade: Color = DUST_LAYER_COLORS[depth].lerp(Color.BLACK, 0.08 * _hash01(seed, i))
			shade.a = 1.0 if amount >= 1.0 else 0.35 + 0.65 * amount
			var jitter := Vector2(_hash01(seed, i * 3) - 0.5, _hash01(seed, i * 3 + 1) - 0.5) * lump * 0.5
			var center := rect.position + Vector2((float(col) + 0.5) * cw, (float(row) + 0.5) * ch) + jitter
			center = Vector2(clampf(center.x, inner.position.x, inner.end.x), clampf(center.y, inner.position.y, inner.end.y))
			var r: float = lump * (0.75 + 0.25 * minf(amount, 1.0)) * (0.85 + 0.3 * _hash01(seed, i * 3 + 2))
			## Keep clumps inside the cell so dirt never spills onto neighbors.
			var room: float = minf(minf(center.x - rect.position.x, rect.end.x - center.x), minf(center.y - rect.position.y, rect.end.y - center.y))
			draw_circle(center, minf(r, room + 1.0), shade)
	var full: float = float(grid.size() * maxi(dust_layers(cell), 1))
	var dirty: float = clampf(left / maxf(full, 1.0), 0.0, 1.0)
	if dirty <= 0.02:
		return
	## The bone's outline pressed up through the dirt, like a fossil in rock.
	var data = _find_at(cell).get("data", null)
	if data != null and data.has_method("draw_silhouette"):
		var shape: Rect2 = rect.grow(-6.0)
		data.draw_silhouette(self, Rect2(shape.position + Vector2(1.5, 1.5), shape.size), Color(0.12, 0.08, 0.05, 0.35 * dirty))
		data.draw_silhouette(self, shape, Color(BONE_RIM, 0.28 * dirty + 0.10))
	## A thin bone-colored rim says "there is a fossil under this dirt".
	draw_rect(rect.grow(-1.5), Color(BONE_RIM, 0.65), false, 2.0)


func _draw_fx(c: CanvasItem) -> void:
	_draw_boost_ring(c)
	_draw_crumble_timers(c)
	_draw_tool_cursor(c)
	_draw_cast_ring(c)


func _draw_crumble_timers(c: CanvasItem) -> void:
	## Over each crumbling bone: a plate reading "-1 [star] 6s" with a draining
	## bar, red when close. With Plaster Cast owned, a prompt says how to save it.
	var font: Font = UiStyle.display_font()
	for find in finds:
		var left: float = crumble_in(find)
		if left == INF:
			continue
		var kind: int = int(find.get("kind", 0))
		var span: float = Tuning.crumble_step[kind] if float(find.get("air", 0.0)) >= Tuning.crumble_first[kind] else Tuning.crumble_first[kind]
		var frac: float = clampf(left / maxf(span, 0.1), 0.0, 1.0)
		var urgent: bool = left <= 3.0
		var color := Color("FF6A4A") if urgent else (Color("9FE3F0") if kind == Tuning.BONE_OPAL else Color("F2E6C4"))
		var anchor: Vector2 = _find_centroid(find) + Vector2(0, -Tuning.cell_h * 0.5 - 16.0)
		var secs: String = "%ds" % int(ceil(left))
		var fs: int = 13
		var minus_w: float = font.get_string_size("-1", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var secs_w: float = font.get_string_size(secs, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var star_w: float = 14.0
		var w: float = minus_w + star_w + secs_w + 22.0
		var plate := Rect2(anchor - Vector2(w * 0.5, 11.0), Vector2(w, 22.0))
		c.draw_rect(plate, Color(0.1, 0.07, 0.05, 0.85))
		c.draw_rect(plate, color, false, 1.5)
		c.draw_rect(Rect2(plate.position.x + 2.0, plate.end.y - 4.0, (plate.size.x - 4.0) * frac, 2.0), color)
		var x: float = plate.position.x + 6.0
		c.draw_string(font, Vector2(x, anchor.y + 4.5), "-1", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)
		x += minus_w + 2.0
		_fx_star(c, Vector2(x + star_w * 0.5, anchor.y - 0.5), 6.0, color)
		x += star_w + 4.0
		c.draw_string(font, Vector2(x, anchor.y + 4.5), secs, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)
		if Tuning.cast_owned() and _castable(find):
			var tip := "Hold Hands: plaster (keeps stars, stays dirty)"
			var tw: float = font.get_string_size(tip, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
			var tip_rect := Rect2(Vector2(anchor.x - tw * 0.5 - 6.0, plate.end.y + 3.0), Vector2(tw + 12.0, 18.0))
			c.draw_rect(tip_rect, Color(PLASTER, 0.92))
			c.draw_string(font, Vector2(tip_rect.position.x + 6.0, tip_rect.end.y - 5.0), tip, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("3A2A1C"))


func _fx_star(c: CanvasItem, center: Vector2, r: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for k in 10:
		var ang: float = -PI * 0.5 + float(k) * PI / 5.0
		var rad: float = r if k % 2 == 0 else r * 0.45
		pts.append(center + Vector2(cos(ang), sin(ang)) * rad)
	c.draw_colored_polygon(pts, color)


func _draw_cast_ring(c: CanvasItem) -> void:
	var progress: float = cast_progress()
	if progress <= 0.0:
		return
	var pos := _mouse_world()
	c.draw_arc(pos, 18.0, -PI * 0.5, -PI * 0.5 + TAU * progress, 32, PLASTER, 5.0)
	c.draw_arc(pos, 18.0, 0.0, TAU, 32, Color(PLASTER, 0.25), 1.5)


func _draw_boost_ring(c: CanvasItem) -> void:
	if _boost_flash <= 0.0:
		return
	var radius: float = 16.0 + (1.0 - _boost_flash) * 52.0
	c.draw_arc(_boost_pos, radius, 0.0, TAU, 36, Color("FFE08A", _boost_flash * 0.9), 3.5)
	c.draw_arc(_boost_pos, radius * 0.62, 0.0, TAU, 28, Color("FFF4D2", _boost_flash * 0.45), 2.0)


func aiming_spoils_bone(_world: Vector2 = Vector2.INF) -> bool:
	## Tools can no longer damage bone, so there is nothing to warn about.
	return false


func _draw_tool_cursor(c: CanvasItem) -> void:
	var pos := _mouse_world()
	if not _tool_cursor_visible_at(pos):
		return
	var warn: bool = aiming_spoils_bone(pos)
	var color := Color("F2E6C4")
	var boosted := has_boosted_tool(current_tool)
	if _using_hands():
		color = Color("E8C9A0")
		c.draw_circle(pos, 5.0, color)
		c.draw_arc(pos, 9.0, 0.0, TAU, 16, color, 2.0)
		_draw_cursor_label(c, pos, "HANDS", color)
		return
	match current_tool:
		Tuning.TOOL_SHOVEL:
			color = Color("E24B4B") if warn else (Color("FFE08A") if boosted else Color("D4A017"))
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
			color = Color("E24B4B") if warn else (Color("FF7A5C") if boosted else Color("D94A3D"))
			if Tuning.pickaxe_radius <= 1.0:
				var reach: float = 14.0 if boosted else 10.0
				c.draw_line(pos + Vector2(-reach, 0), pos + Vector2(reach, 0), color, 4.0 if boosted else 3.0)
				c.draw_line(pos + Vector2(0, -reach), pos + Vector2(0, reach), color, 4.0 if boosted else 3.0)
			else:
				var ring: float = Tuning.pickaxe_radius * Tuning.cell_w * 0.45
				c.draw_arc(pos, ring, 0.0, TAU, 24, color, 3.2 if boosted else 2.0)
				c.draw_line(pos + Vector2(-8, 0), pos + Vector2(8, 0), color, 3.0)
				c.draw_line(pos + Vector2(0, -8), pos + Vector2(0, 8), color, 3.0)
		Tuning.TOOL_BRUSH:
			color = Color("A6E4F5") if boosted else Color("7EC8E3")
			## The ring is the real bristle width: dust inside it gets wiped.
			var bristles: float = brush_radius()
			c.draw_circle(pos, bristles, Color(0.5, 0.8, 0.9, 0.16 if boosted else 0.12))
			c.draw_arc(pos, bristles, 0.0, TAU, 28, color, 2.5 if boosted else 2.0)
	_draw_cursor_label(c, pos, Tuning.TOOL_NAMES[current_tool], color)


func _draw_cursor_label(c: CanvasItem, pos: Vector2, label: String, color: Color) -> void:
	## Game font with a dark outline so the tag reads on tan dirt and grey stone.
	var font: Font = UiStyle.display_font()
	var at: Vector2 = pos + Vector2(12, -10)
	c.draw_string_outline(font, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 4, Color(0.1, 0.07, 0.05, 0.85))
	c.draw_string(font, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, color)


class _FxOverlay extends Node2D:
	var host: Node2D

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if host != null and host.has_method("_draw_fx"):
			host.call("_draw_fx", self)
