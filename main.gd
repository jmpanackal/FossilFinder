extends Node2D

const FloatingTextScene := preload("res://floating_text.gd")
const RevealPing := preload("res://reveal_ping.gd")

@onready var camera: Camera2D = $Camera2D
@onready var dig_site = $DigSite
@onready var hud = $HUD
@onready var toast = $Toast
@onready var summary = $Summary
@onready var museum = $Museum
@onready var shop = $Shop
@onready var debug_label: Label = $DebugOverlay/DebugLabel

var time_left: float = 0.0
var round_active: bool = false
var debug_on: bool = false
var screen: String = "dig"
var _shake_left: float = 0.0
var _timer_armed: bool = false
var _last_fossil_line: String = ""
var _last_fossil_stars: int = 0
var _round_finds: Array = []
var _round_dirt_pay: int = 0
var _round_fossil_pay: int = 0
var _pending_tool_notices: Dictionary = {}
var _boosted_tools: Array[int] = []


func _ready() -> void:
	randomize()
	GameState.load_game()
	get_viewport().size_changed.connect(_sync_view)
	Settings.menu_toggled.connect(_on_settings_toggled)
	_sync_view()
	dig_site.layer_cleared.connect(_on_layer_cleared)
	dig_site.fossil_cell_exposed.connect(_on_fossil_exposed)
	dig_site.fossil_extracted.connect(_on_fossil_extracted)
	dig_site.fossil_ready_to_dust.connect(_on_ready_to_dust)
	dig_site.pickaxe_struck.connect(_on_pickaxe)
	dig_site.tool_used.connect(_on_tool_used)
	hud.tool_selected.connect(dig_site.set_tool)
	hud.precision_toggled.connect(_toggle_precision)
	hud.end_shift.connect(_end_round)
	summary.dig_again.connect(start_round)
	summary.open_museum.connect(func() -> void: show_screen("museum"))
	summary.open_shop.connect(func() -> void: show_screen("shop"))
	museum.closed.connect(_return_from_menu)
	shop.closed.connect(_return_from_menu)
	$DebugOverlay.visible = false
	start_round()


func start_round() -> void:
	time_left = maxf(Tuning.round_seconds, Tuning.base_round_seconds)
	round_active = true
	_timer_armed = false
	_shake_left = 0.0
	camera.offset = Vector2.ZERO
	summary.hide_summary()
	show_screen("dig")
	dig_site.input_enabled = true
	_round_finds.clear()
	_round_dirt_pay = 0
	_round_fossil_pay = 0
	_last_fossil_line = ""
	_last_fossil_stars = 0
	dig_site.start_round()
	_arm_upgrade_notices()


func show_screen(next: String) -> void:
	if round_active and next != "dig":
		return
	screen = next
	var digging := next == "dig"
	dig_site.visible = digging
	museum.visible = next == "museum"
	shop.visible = next == "shop"
	if next != "dig":
		summary.hide_summary()
	elif not round_active:
		_show_summary()
	dig_site.input_enabled = digging and round_active
	if next == "shop" and shop.has_method("refresh"):
		shop.refresh()
	if next == "museum" and museum.has_method("_refresh"):
		museum._refresh()


func _return_from_menu() -> void:
	show_screen("dig")


func _toggle_precision() -> void:
	if not GameState.precision_unlocked():
		return
	GameState.precision_on = not GameState.precision_on
	Sfx.play("ui")


func _sync_view() -> void:
	var size := Tuning.play_view_size(get_viewport().get_visible_rect().size)
	Tuning.view_w = size.x
	Tuning.view_h = size.y
	camera.position = size * 0.5
	Tuning.apply_cell_metrics()
	if dig_site != null:
		dig_site.queue_redraw()


func _on_settings_toggled(open: bool) -> void:
	if open and dig_site != null and dig_site.has_method("cancel_input"):
		dig_site.cancel_input()


func _process(delta: float) -> void:
	if Settings.is_open():
		return
	if _shake_left > 0.0 and Tuning.shake_enabled:
		_shake_left -= delta
		camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * Tuning.shake_strength
		if _shake_left <= 0.0:
			camera.offset = Vector2.ZERO
	if round_active and screen == "dig":
		if not _timer_armed:
			_timer_armed = true
		else:
			time_left -= delta
			if time_left <= 0.0:
				_end_round()
	var found: bool = round_active and screen == "dig" and bool(dig_site.has_visible_find())
	var clean: float = float(dig_site.fossil_cleanliness())
	var grade: String = Tuning.preservation_grade(float(dig_site.integrity), clean) if found else ""
	var stars: int = Tuning.preservation_stars(float(dig_site.integrity), clean) if found else 0
	var value: int = int(dig_site.preview_value()) if found else 0
	hud.refresh(time_left, Tuning.round_seconds, dig_site.current_tool, round_active and screen == "dig", found, stars, grade, clean, value)
	if debug_on:
		_refresh_debug()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_F1:
			debug_on = not debug_on
			$DebugOverlay.visible = debug_on
		elif event.physical_keycode == KEY_F2 and round_active:
			_end_round()
		elif event.physical_keycode == KEY_P:
			_toggle_precision()
		elif not round_active and (event.physical_keycode == KEY_ENTER or event.physical_keycode == KEY_SPACE):
			start_round()


func _end_round() -> void:
	if not round_active:
		return
	round_active = false
	time_left = 0.0
	dig_site.input_enabled = false
	if dig_site.is_fully_exposed():
		dig_site.extract_now(false)
	if _round_finds.is_empty():
		_last_fossil_line = "Left in the ground."
		_last_fossil_stars = 0
	else:
		var names: PackedStringArray = []
		_last_fossil_stars = 0
		for entry in _round_finds:
			names.append(Summary.find_line(str(entry["name"]), str(entry["grade"]), str(entry.get("dirt", ""))))
			_last_fossil_stars = maxi(_last_fossil_stars, int(entry["stars"]))
		_last_fossil_line = "\n".join(names)
	_show_summary()


func _show_summary() -> void:
	if dig_site != null:
		dig_site.visible = false
	summary.show_summary(_round_fossil_pay, _round_dirt_pay, _last_fossil_line, _last_fossil_stars)


func _on_layer_cleared(amount: int, world_pos: Vector2) -> void:
	GameState.add_money(amount)
	_round_dirt_pay += amount
	_spawn_float("+$%d" % amount, world_pos, Color("E4B75A"))


func _on_fossil_exposed(world_pos: Vector2, first: bool) -> void:
	if first:
		_ping(world_pos)


func _on_ready_to_dust() -> void:
	dig_site.pulse_bones()
	_ping(dig_site.fossil_centroid())
	if GameState.owns_tool(Tuning.TOOL_BRUSH):
		toast.show_toast("Brush it clean")
	else:
		toast.show_toast("Bone is exposed", "End the shift to take it")
	Sfx.play("fossil_ping")
	if Tuning.shake_enabled:
		_shake_left = maxf(_shake_left, 0.18)


func _on_fossil_extracted(fossil_name: String, value: int, integrity: float, cleanliness: float, clean: bool, piece_id: String) -> void:
	var before: int = GameState.money
	GameState.add_money(value)
	var id := piece_id if piece_id != "" else "find"
	GameState.install_find(id, fossil_name, cleanliness, clean)
	_round_fossil_pay += GameState.money - before
	var grade := Tuning.preservation_grade(integrity)
	var stars := Tuning.preservation_stars(integrity)
	var owns_brush: bool = GameState.owns_tool(Tuning.TOOL_BRUSH)
	var dirt := Tuning.summary_dirt_line(cleanliness, owns_brush)
	_round_finds.append({
		"name": fossil_name,
		"grade": grade,
		"stars": stars,
		"dirt": dirt,
	})
	var toast_detail: String = grade if dirt.is_empty() else "%s · %s" % [grade, dirt]
	toast.show_toast("%s found!" % fossil_name, toast_detail, stars)


func _on_pickaxe() -> void:
	if not Tuning.shake_enabled:
		return
	var boosted: bool = _boosted_tools.has(Tuning.TOOL_PICKAXE)
	_shake_left = Tuning.shake_time * (1.7 if boosted else 1.0)


func _arm_upgrade_notices() -> void:
	_pending_tool_notices.clear()
	_boosted_tools.clear()
	var notices: Array = GameState.consume_pending_notices()
	var site_titles: PackedStringArray = []
	var site_subs: PackedStringArray = []
	for raw in notices:
		var notice: Dictionary = raw
		var id: String = str(notice.get("id", ""))
		var tool: int = GameState.tool_for_upgrade(id)
		if tool >= 0:
			if not _pending_tool_notices.has(tool):
				_pending_tool_notices[tool] = []
			var bucket: Array = _pending_tool_notices[tool]
			bucket.append(notice)
			_pending_tool_notices[tool] = bucket
			if not _boosted_tools.has(tool):
				_boosted_tools.append(tool)
		elif GameState.is_site_upgrade(id):
			site_titles.append(str(notice.get("name", id)))
			site_subs.append(GameState.notice_label(notice))
	if hud.has_method("flash_upgraded_tools"):
		hud.flash_upgraded_tools(_boosted_tools)
	if dig_site.has_method("set_boosted_tools"):
		dig_site.set_boosted_tools(_boosted_tools)
	if site_titles.is_empty():
		return
	toast.show_toast(site_titles[0], ", ".join(site_subs))
	for raw in notices:
		var notice: Dictionary = raw
		if str(notice.get("id", "")) != "round_time":
			continue
		if hud.has_method("flash_clock"):
			hud.flash_clock()
		break


func _on_tool_used(tool: int) -> void:
	if not _pending_tool_notices.has(tool):
		return
	var notices: Array = _pending_tool_notices[tool]
	_pending_tool_notices.erase(tool)
	if notices.is_empty():
		return
	var lines: PackedStringArray = []
	for raw in notices:
		var notice: Dictionary = raw
		lines.append(GameState.notice_label(notice))
	var title: String = lines[0]
	var subtitle: String = ""
	if lines.size() > 1:
		subtitle = ", ".join(lines.slice(1))
	toast.show_toast(title, subtitle)
	var pit_top := Tuning.grid_origin + Vector2(float(Tuning.grid_w) * Tuning.cell_w * 0.5, -8.0)
	_spawn_float(title, pit_top, Color("FFE08A"), 26)
	if hud.has_method("flash_upgraded_tools"):
		hud.flash_upgraded_tools([tool])


func _spawn_float(text: String, world_pos: Vector2, color: Color, font_size: int = 16) -> void:
	var floater = FloatingTextScene.new()
	floater.position = world_pos
	floater.setup(text, color, font_size)
	add_child(floater)


func _ping(world_pos: Vector2) -> void:
	var ring := Node2D.new()
	ring.position = world_pos
	ring.set_script(RevealPing)
	add_child(ring)


func _refresh_debug() -> void:
	var lines: PackedStringArray = []
	lines.append("FPS %d" % int(Engine.get_frames_per_second()))
	if dig_site.fossil:
		lines.append("Exposed %d/%d  clean %d%%" % [
			dig_site.exposed_cells.size(),
			dig_site.fossil_cells.size(),
			int(round(dig_site.fossil_cleanliness() * 100.0))
		])
	debug_label.text = "\n".join(lines)
