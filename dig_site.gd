class_name DigSite
extends Node2D

const FossilDataScript := preload("res://fossil_data.gd")

signal layer_cleared(amount: int, world_pos: Vector2)
signal fossil_cell_exposed(world_pos: Vector2, first: bool)
signal fossil_extracted(fossil_name: String, value: int, integrity: float, cleanliness: float, clean: bool, piece_id: String)
signal pickaxe_struck
signal fossil_hit
signal fossil_ready_to_dust
signal tool_used(tool: int)

var input_enabled: bool = true
var current_tool: int = Tuning.TOOL_SHOVEL
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
	Tuning.center_grid()
	start_round()


func start_round() -> void:
	Tuning.apply_site_layout()
	if current_tool != Tuning.TOOL_SHOVEL and not GameState.owns_tool(current_tool):
		current_tool = Tuning.TOOL_SHOVEL
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
	queue_redraw()


func set_boosted_tools(tools: Array) -> void:
	_boosted_tools.clear()
	for raw in tools:
		var tool: int = int(raw)
		if not _boosted_tools.has(tool):
			_boosted_tools.append(tool)


func has_boosted_tool(tool: int) -> bool:
	return _boosted_tools.has(tool)


func fossil_exposure() -> float:
	if fossil_cells.is_empty():
		return 0.0
	return float(exposed_cells.size()) / float(fossil_cells.size())


func fossil_cleanliness() -> float:
	return _find_clean(_focused_find())


func preview_value() -> int:
	var find := _focused_find()
	if find.is_empty() or bool(find.get("extracted", false)):
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
		if bool(find.get("extracted", false)):
			continue
		var cells: Dictionary = find.get("cells", {})
		for cell in cells:
			if exposed_cells.has(cell):
				return true
	return false


func set_tool(tool: int) -> void:
	if tool < 0 or tool > 2 or tool == current_tool:
		return
	if tool != Tuning.TOOL_SHOVEL and not GameState.owns_tool(tool):
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
		var tooth: FossilDataScript = load("res://tooth.tres") as FossilDataScript
		_try_place_find(tooth)
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
		if extra != null and _find_fits(extra):
			pool.append(extra)
	for _j in extras:
		if pool.is_empty():
			break
		_try_place_find(pool[randi() % pool.size()])


func _choose_main_find() -> FossilDataScript:
	var skull: FossilDataScript = load(Tuning.fossil_path) as FossilDataScript
	if GameState.big_finds_unlocked() and _find_fits(skull):
		return skull
	var options: Array = []
	for path in Tuning.extra_fossil_paths:
		var extra: FossilDataScript = load(str(path)) as FossilDataScript
		if extra != null and _find_fits(extra):
			options.append(extra)
	if options.is_empty():
		return load("res://tooth.tres") as FossilDataScript
	return options[randi() % options.size()]


func _find_fits(data: FossilDataScript) -> bool:
	if data == null:
		return false
	var max_x: int = 0
	var max_y: int = 0
	for offset in data.cell_offsets():
		max_x = maxi(max_x, offset.x)
		max_y = maxi(max_y, offset.y)
	return max_x < Tuning.grid_w and max_y < Tuning.grid_h


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
	if not input_enabled:
		queue_redraw()
		return
	var holding := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var aiming := _cell_at(_mouse_world())
	if _holding_dig and holding and GameState.hold_unlocked() and (current_tool == Tuning.TOOL_SHOVEL or current_tool == Tuning.TOOL_PICKAXE):
		if _is_exposed_fossil(aiming):
			_hold_time = 0.0
			if _can_harm_fossil():
				_fossil_hold += delta
				var gap := 1.0 / maxf(Tuning.fossil_hold_tick_rate, 0.2)
				while _fossil_hold >= gap:
					_fossil_hold -= gap
					_hit_fossil(aiming)
			else:
				_fossil_hold = 0.0
		else:
			_fossil_hold = 0.0
			_hold_time += delta
			var interval := 1.0 / _hold_rate()
			while _hold_time >= interval:
				_hold_time -= interval
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
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_1:
			set_tool(Tuning.TOOL_SHOVEL)
		elif event.physical_keycode == KEY_2:
			set_tool(Tuning.TOOL_PICKAXE)
		elif event.physical_keycode == KEY_3:
			set_tool(Tuning.TOOL_BRUSH)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_cycle_tool(-1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_cycle_tool(1)
		elif event.button_index == MOUSE_BUTTON_LEFT and input_enabled:
			if current_tool == Tuning.TOOL_SHOVEL or current_tool == Tuning.TOOL_PICKAXE:
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


func _using_hands() -> bool:
	return current_tool == Tuning.TOOL_SHOVEL and not GameState.owns_tool(Tuning.TOOL_SHOVEL)


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
	if current_tool == Tuning.TOOL_SHOVEL:
		_apply_shovel(cell, mult, is_click)
	elif current_tool == Tuning.TOOL_PICKAXE:
		_apply_pickaxe(cell, mult, is_click)


func _apply_shovel(center: Vector2i, style_mult: float, is_click: bool) -> void:
	if not _in_bounds(center):
		return
	var heard := false
	var radius: int = 0
	if not _using_hands() and not GameState.precision_on:
		radius = int(ceili(Tuning.shovel_radius))
	for x in range(center.x - radius, center.x + radius + 1):
		for y in range(center.y - radius, center.y + radius + 1):
			var cell := Vector2i(x, y)
			if not _in_bounds(cell):
				continue
			if GameState.precision_on and cell != center:
				continue
			if (not GameState.precision_on) and Vector2(cell).distance_to(Vector2(center)) > Tuning.shovel_radius:
				continue
			if _is_exposed_fossil(cell):
				if is_click and cell == center and _can_harm_fossil():
					_hit_fossil(cell)
				continue
			var layer: int = _top_layer[cell.x][cell.y]
			var damage := Tuning.damage_for(Tuning.TOOL_SHOVEL, layer) * style_mult
			if GameState.precision_on:
				damage *= 1.0 + Tuning.precision_damage_bonus
			_damage_cell(cell, Tuning.TOOL_SHOVEL, damage, not heard)
			if not heard and layer < Tuning.layer_count:
				heard = true
	_mark_tool_used(Tuning.TOOL_SHOVEL, cell_center(center))


func _apply_pickaxe(center: Vector2i, style_mult: float, is_click: bool) -> void:
	if not _in_bounds(center):
		return
	var heard := false
	var offsets: Array[Vector2i] = [Vector2i.ZERO]
	if not GameState.precision_on:
		offsets = [
			Vector2i(0, 0),
			Vector2i(0, -1),
			Vector2i(0, 1),
			Vector2i(-1, 0),
			Vector2i(1, 0),
		]
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
		if GameState.precision_on:
			damage *= 1.0 + Tuning.precision_damage_bonus
		_damage_cell(cell, Tuning.TOOL_PICKAXE, damage, not heard)
		if not heard and layer < Tuning.layer_count:
			heard = true
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
	_puff_dust(cell_center(cell), after - before)
	_mark_tool_used(Tuning.TOOL_BRUSH, cell_center(cell))
	if travel > 4.0:
		Sfx.play("dust")
	_focus_find(_find_at(cell))
	var find := _find_at(cell)
	if not find.is_empty() and _find_is_fully_exposed(find) and _find_clean(find) >= Tuning.clean_extract_threshold:
		_extract_find(find, true)


func _damage_cell(cell: Vector2i, tool: int, override_damage: float = -1.0, play_sfx: bool = true) -> void:
	if not _in_bounds(cell):
		return
	if _is_exposed_fossil(cell):
		return
	var layer: int = _top_layer[cell.x][cell.y]
	if layer >= Tuning.layer_count:
		return
	var buried := _find_at(cell)
	if not buried.is_empty() and layer >= int(buried["layer"]):
		return
	var damage := override_damage
	if damage < 0.0:
		damage = Tuning.damage_for(tool, layer)
	if damage <= 0.0:
		return
	var start_material := Tuning.material_at_layer(layer)
	_hp[cell.x][cell.y] -= damage
	_burst(cell_center(cell), layer)
	if play_sfx:
		_play_hit(layer)
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
		_clear_layer(cell)
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
	find["integrity"] = maxf(Tuning.integrity_floor, float(find["integrity"]) - Tuning.integrity_hit_cost)
	_focus_find(find)
	_bone_pulse = maxf(_bone_pulse, 0.7)
	_burst(cell_center(cell), int(find["layer"]))
	Sfx.play("crack")
	fossil_hit.emit()
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
	_draw_void()
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
	_draw_boost_ring()
	_draw_tool_cursor()


func _chunk_top() -> Rect2:
	var pad := Tuning.chunk_pad
	return Rect2(
		Tuning.grid_origin.x - pad,
		Tuning.grid_origin.y - pad,
		float(Tuning.grid_w) * Tuning.cell_w + pad * 2.0,
		float(Tuning.grid_h) * Tuning.cell_h + pad
	)


func _draw_void() -> void:
	draw_rect(Rect2(0, 0, Tuning.view_w, Tuning.view_h), Color("140F0C"))


func _draw_chunk() -> void:
	var top := _chunk_top()
	var body := Rect2(top.position, Vector2(top.size.x, top.size.y + Tuning.chunk_front))
	var right := Rect2(body.end.x, body.position.y, Tuning.cell_side, body.size.y)
	var fill := Color("2A2118")
	var line := Color("1A1410")
	draw_rect(right, fill)
	draw_rect(right, line, false, 3.0)
	draw_rect(body, fill)
	draw_rect(body, line, false, 3.0)


func _draw_cell_sides(x: int, y: int) -> void:
	var top := _top_rect(x, y)
	var face := _cell_face_color(x, y)
	if y + 1 >= Tuning.grid_h:
		return
	var below := _top_rect(x, y + 1)
	var drop := below.position.y - top.end.y
	if drop <= Tuning.cell_gap + 1.0:
		return
	var step := Rect2(top.position.x, top.end.y, top.size.x, drop)
	draw_rect(step, face)
	draw_rect(step, Color("1A1410"), false, 1.0)


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
	var rect := _top_rect(x, y)
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
	draw_rect(rect, Color("241C16"), false, 1.5)
	var edge := 0.18
	if _is_exposed_fossil(cell):
		edge += float(cleanliness.get(cell, 0.0)) * 0.22
	draw_rect(rect.grow(-1.0), color.lightened(edge), false, 1.0)
	_draw_cracks(rect, cell, layer)
	if _is_exposed_fossil(cell):
		_draw_bone_mark(rect, float(cleanliness.get(cell, 0.0)))
		_draw_dust_specks(rect, cell, float(cleanliness.get(cell, 0.0)))


func _draw_bone_pulse() -> void:
	if _bone_pulse <= 0.0 or exposed_cells.is_empty():
		return
	var glow := Color("FFF1C4", 0.15 + _bone_pulse * 0.55)
	for cell in exposed_cells:
		var rect := _top_rect(cell.x, cell.y).grow(2.0 + _bone_pulse * 3.0)
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


func _draw_bone_mark(rect: Rect2, clean: float) -> void:
	var inset := rect.grow(-8)
	var mark := Color("8A7355").lerp(Color("FFF4D6"), clean)
	draw_rect(inset, mark, false, 2.0)


func _draw_dust_specks(rect: Rect2, cell: Vector2i, clean: float) -> void:
	var specks := int(round((1.0 - clean) * 10.0))
	if specks <= 0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = int(cell.x * 41 + cell.y * 73 + 11)
	for i in specks:
		var pos := rect.position + Vector2(6.0 + rng.randf() * (rect.size.x - 12.0), 6.0 + rng.randf() * (rect.size.y - 12.0))
		draw_circle(pos, 1.6, Color(0.28, 0.2, 0.12, 0.55))


func _draw_boost_ring() -> void:
	if _boost_flash <= 0.0:
		return
	var radius: float = 16.0 + (1.0 - _boost_flash) * 52.0
	draw_arc(_boost_pos, radius, 0.0, TAU, 36, Color("FFE08A", _boost_flash * 0.9), 3.5)
	draw_arc(_boost_pos, radius * 0.62, 0.0, TAU, 28, Color("FFF4D2", _boost_flash * 0.45), 2.0)


func _draw_tool_cursor() -> void:
	var pos := _mouse_world()
	var color := Color("F2E6C4")
	var boosted := has_boosted_tool(current_tool)
	if _using_hands():
		color = Color("E8C9A0")
		draw_circle(pos, 5.0, color)
		draw_arc(pos, 9.0, 0.0, TAU, 16, color, 2.0)
		draw_string(ThemeDB.fallback_font, pos + Vector2(12, -10), "HANDS", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, color)
		return
	match current_tool:
		Tuning.TOOL_SHOVEL:
			color = Color("FFE08A") if boosted else Color("D4A017")
			draw_circle(pos, 6.0 if boosted else 5.0, color)
			if GameState.precision_on or Tuning.shovel_radius <= 0.0:
				draw_arc(pos, 10.0, 0.0, TAU, 16, color, 2.0)
			else:
				var ring: float = Tuning.shovel_radius * Tuning.cell_w * 0.45
				draw_arc(pos, ring, 0.0, TAU, 24, color, 3.2 if boosted else 2.0)
				if boosted:
					var wobble: float = 5.0 + sin(float(Time.get_ticks_msec()) * 0.012) * 2.0
					draw_arc(pos, ring + wobble, 0.0, TAU, 28, Color("FFF4D2", 0.5), 2.0)
		Tuning.TOOL_PICKAXE:
			color = Color("FF7A5C") if boosted else Color("D94A3D")
			var reach: float = 14.0 if boosted else 10.0
			if GameState.precision_on:
				draw_circle(pos, 7.0 if boosted else 6.0, color, false, 2.5 if boosted else 2.0)
			else:
				draw_line(pos + Vector2(-reach, 0), pos + Vector2(reach, 0), color, 4.0 if boosted else 3.0)
				draw_line(pos + Vector2(0, -reach), pos + Vector2(0, reach), color, 4.0 if boosted else 3.0)
		Tuning.TOOL_BRUSH:
			color = Color("A6E4F5") if boosted else Color("7EC8E3")
			var puff: float = 11.0 if boosted else 7.0
			draw_circle(pos, puff, Color(0.5, 0.8, 0.9, 0.28 if boosted else 0.25))
			draw_arc(pos, puff + 2.0, 0.0, TAU, 20, color, 2.5 if boosted else 2.0)
	var label: String = Tuning.TOOL_NAMES[current_tool]
	draw_string(ThemeDB.fallback_font, pos + Vector2(12, -10), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, color)
