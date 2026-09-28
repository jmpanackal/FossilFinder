extends Node2D

const FloatingTextScene := preload("res://floating_text.gd")
const RevealPing := preload("res://reveal_ping.gd")
const LootFlyScene := preload("res://loot_fly.gd")
const Matrix := preload("res://matrix_find.gd")
const Lucky := preload("res://lucky_strike.gd")

@onready var camera: Camera2D = $Camera2D
@onready var site_backdrop = $SiteBackdrop
@onready var dig_site = $DigSite
@onready var hud = $HUD
@onready var toast = $Toast
@onready var summary = $Summary
@onready var museum = $Museum
@onready var shop = $Shop
@onready var title = $Title
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
var _round_finds_pay: int = 0
var _round_fossil_pay: int = 0
var _extract_fate: String = ""
var _pending_tool_notices: Dictionary = {}
var _boosted_tools: Array[int] = []


func _ready() -> void:
	randomize()
	GameState.load_game()
	get_viewport().size_changed.connect(_sync_view)
	Settings.menu_toggled.connect(_on_settings_toggled)
	GameState.progress_reset.connect(_on_progress_reset)
	GameState.skeleton_completed.connect(_on_skeleton_completed)
	_sync_view()
	dig_site.layer_cleared.connect(_on_layer_cleared)
	dig_site.fossil_cell_exposed.connect(_on_fossil_exposed)
	dig_site.fossil_extracted.connect(_on_fossil_extracted)
	dig_site.fossil_ready_to_dust.connect(_on_ready_to_dust)
	dig_site.pickaxe_struck.connect(_on_pickaxe)
	dig_site.tool_used.connect(_on_tool_used)
	dig_site.lucky_struck.connect(_on_lucky_struck)
	if dig_site.has_signal("bone_sensed"):
		dig_site.bone_sensed.connect(_on_bone_sensed)
	hud.tool_selected.connect(dig_site.set_tool)
	hud.end_shift.connect(_end_round)
	if Settings.has_signal("end_shift_pressed"):
		Settings.end_shift_pressed.connect(_end_round)
	if Settings.has_signal("back_pressed"):
		Settings.back_pressed.connect(_on_nav_back)
	if Settings.has_signal("dig_pressed"):
		Settings.dig_pressed.connect(start_round)
	if Settings.has_signal("museum_pressed"):
		Settings.museum_pressed.connect(func() -> void: show_screen("museum"))
	if Settings.has_signal("upgrades_pressed"):
		Settings.upgrades_pressed.connect(func() -> void: show_screen("shop"))
	summary.dig_again.connect(start_round)
	summary.open_museum.connect(func() -> void: show_screen("museum"))
	summary.open_shop.connect(func() -> void: show_screen("shop"))
	museum.closed.connect(_return_from_menu)
	shop.closed.connect(_return_from_menu)
	if title != null and title.has_signal("started"):
		title.started.connect(_begin_from_title)
	if Settings.has_signal("title_requested"):
		Settings.title_requested.connect(show_title)
	$DebugOverlay.visible = false
	show_title()


func _begin_from_title() -> void:
	_hide_title()
	start_round()


func show_title() -> void:
	round_active = false
	time_left = 0.0
	_timer_armed = false
	if dig_site != null:
		dig_site.input_enabled = false
		if dig_site.has_method("cancel_input"):
			dig_site.cancel_input()
	if summary != null:
		summary.hide_summary()
	if museum != null:
		museum.visible = false
	if shop != null:
		shop.visible = false
	if hud != null:
		hud.visible = false
	screen = "title"
	_sync_shift_pause()
	if site_backdrop != null:
		site_backdrop.visible = true
		if site_backdrop.has_method("set_covers_chunk_hole"):
			site_backdrop.call("set_covers_chunk_hole", true)
	if title != null:
		title.visible = true
		if title.has_method("refresh_field"):
			title.refresh_field()
	_sync_menu_chrome()
	if Settings.has_method("set_title_return_visible"):
		Settings.set_title_return_visible(false)


func _hide_title() -> void:
	if title != null:
		title.visible = false
	_sync_menu_chrome()
	if Settings.has_method("set_title_return_visible"):
		Settings.set_title_return_visible(true)


func start_round() -> void:
	time_left = maxf(Tuning.round_seconds, Tuning.base_round_seconds)
	round_active = true
	_timer_armed = false
	_shake_left = 0.0
	camera.offset = Vector2.ZERO
	summary.hide_summary()
	_hide_title()
	show_screen("dig")
	dig_site.input_enabled = true
	_round_finds.clear()
	_round_finds_pay = 0
	_round_fossil_pay = 0
	_extract_fate = ""
	_last_fossil_line = ""
	_last_fossil_stars = 0
	dig_site.start_round()
	_arm_upgrade_notices()


func show_screen(next: String) -> void:
	if next != "title":
		_hide_title()
	if round_active and (next == "shop" or next == "museum"):
		_open_shift_overlay(next)
		return
	if round_active and next != "dig":
		return
	screen = next
	var digging := next == "dig"
	dig_site.visible = digging
	if site_backdrop != null:
		site_backdrop.visible = digging
		if digging and site_backdrop.has_method("set_covers_chunk_hole"):
			site_backdrop.call("set_covers_chunk_hole", not (dig_site != null and dig_site.visible))
	museum.visible = next == "museum"
	shop.visible = next == "shop"
	if next != "dig":
		summary.hide_summary()
	elif not round_active:
		_show_summary()
	dig_site.input_enabled = digging and round_active
	if hud != null:
		hud.visible = digging and round_active
	_sync_menu_chrome()
	if next == "shop" and shop.has_method("refresh"):
		shop.refresh()
	if next == "museum" and museum.has_method("_refresh"):
		museum._refresh()
	_sync_shift_pause()


func _open_shift_overlay(next: String) -> void:
	if next != "shop" and next != "museum":
		return
	if dig_site != null and dig_site.has_method("cancel_input"):
		dig_site.cancel_input()
	screen = next
	dig_site.visible = false
	if site_backdrop != null:
		site_backdrop.visible = false
	museum.visible = next == "museum"
	shop.visible = next == "shop"
	if hud != null:
		hud.visible = false
	_sync_menu_chrome()
	dig_site.input_enabled = false
	if next == "shop" and shop.has_method("refresh"):
		shop.refresh()
	if next == "museum" and museum.has_method("_refresh"):
		museum._refresh()
	_sync_shift_pause()


func _on_nav_back() -> void:
	if Settings.has_method("is_open") and Settings.is_open():
		return
	if screen == "shop" or screen == "museum":
		_return_from_menu()
		return
	if screen != "title":
		show_title()


func _return_from_menu() -> void:
	if round_active:
		shop.visible = false
		museum.visible = false
		screen = "dig"
		dig_site.visible = true
		if site_backdrop != null:
			site_backdrop.visible = true
			if site_backdrop.has_method("set_covers_chunk_hole"):
				site_backdrop.call("set_covers_chunk_hole", false)
		if hud != null:
			hud.visible = true
		_sync_menu_chrome()
		dig_site.input_enabled = true
		_sync_shift_pause()
		return
	show_screen("dig")


func _sync_menu_chrome() -> void:
	var settings_open: bool = Settings.has_method("is_open") and Settings.is_open()
	var in_game: bool = screen != "title"
	if Settings.has_method("set_nav_visible"):
		Settings.set_nav_visible(in_game and not settings_open)
	elif Settings.has_method("set_menu_chrome_visible"):
		Settings.set_menu_chrome_visible(in_game and not settings_open)
	if Settings.has_method("set_nav_context"):
		Settings.set_nav_context(_nav_context())
	if Settings.has_method("_layout_nav_chrome"):
		Settings.call("_layout_nav_chrome")
	elif Settings.has_method("_layout_menu_chrome"):
		Settings.call("_layout_menu_chrome")
	var live_dig: bool = in_game and screen == "dig" and round_active
	if summary != null and bool(summary.visible):
		live_dig = false
	if Settings.has_method("set_end_shift_visible"):
		Settings.set_end_shift_visible(live_dig and not settings_open)
	if Settings.has_method("set_wallet_visible"):
		Settings.set_wallet_visible(in_game)
		if Settings.has_method("_layout_wallet"):
			Settings.call("_layout_wallet")
	if hud != null and hud.has_method("set_header_actions_visible"):
		hud.set_header_actions_visible(false)


func _nav_context() -> String:
	if screen == "title":
		return "title"
	if screen == "shop":
		return "shop"
	if screen == "museum":
		return "museum"
	if summary != null and bool(summary.visible):
		return "summary"
	return "dig"


func _dig_header_should_hide() -> bool:
	if screen == "shop" or screen == "museum" or screen == "title":
		return true
	if summary != null and bool(summary.visible):
		return true
	if Settings.has_method("is_open") and Settings.is_open():
		return true
	return false


func _sync_shift_pause() -> void:
	if get_tree() == null:
		return
	if screen == "shop" or screen == "museum":
		get_tree().paused = true
	elif not Settings.is_open():
		get_tree().paused = false


func _sync_view() -> void:
	var size := Tuning.play_view_size(get_viewport().get_visible_rect().size)
	Tuning.view_w = size.x
	Tuning.view_h = size.y
	camera.position = size * 0.5
	Tuning.apply_cell_metrics()
	if site_backdrop != null:
		site_backdrop.queue_redraw()
	if dig_site != null:
		dig_site.queue_redraw()


func _on_settings_toggled(open: bool) -> void:
	if open and dig_site != null and dig_site.has_method("cancel_input"):
		dig_site.cancel_input()
	_sync_menu_chrome()
	if not open:
		_sync_shift_pause()


func _on_progress_reset() -> void:
	_begin_from_title()


func _process(delta: float) -> void:
	if screen == "title":
		if hud != null:
			hud.visible = false
		return
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
	var cards: Array = []
	if round_active and screen == "dig" and dig_site.has_method("live_find_cards"):
		cards = dig_site.live_find_cards()
	if hud.has_method("set_find_cards"):
		hud.set_find_cards(cards)
	var found: bool = not cards.is_empty()
	var clean: float = float(dig_site.fossil_cleanliness())
	var grade: String = Tuning.preservation_grade(float(dig_site.integrity), clean) if found else ""
	var stars: int = Tuning.preservation_stars(float(dig_site.integrity), clean) if found else 0
	var value: int = int(dig_site.preview_value()) if found else 0
	hud.refresh(time_left, Tuning.round_seconds, dig_site.current_tool, round_active and screen == "dig", found, stars, grade, clean, value)
	if hud.has_method("set_bone_warning") and dig_site.has_method("aiming_spoils_bone"):
		hud.set_bone_warning(bool(dig_site.aiming_spoils_bone()))
	if hud.has_method("set_find_headline"):
		hud.set_find_headline("")
	if debug_on:
		_refresh_debug()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_F1:
			debug_on = not debug_on
			$DebugOverlay.visible = debug_on
		elif screen == "title" and (event.physical_keycode == KEY_ENTER or event.physical_keycode == KEY_SPACE):
			_begin_from_title()
		elif event.physical_keycode == KEY_F2 and round_active:
			_end_round()
		elif screen != "title" and not round_active and (event.physical_keycode == KEY_ENTER or event.physical_keycode == KEY_SPACE):
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
			names.append(Summary.find_line(str(entry["name"]), str(entry["grade"]), str(entry.get("dirt", "")), str(entry.get("fate", ""))))
			_last_fossil_stars = maxi(_last_fossil_stars, int(entry["stars"]))
		_last_fossil_line = Summary.join_find_lines(names)
	_show_summary()


func _show_summary() -> void:
	_hide_title()
	if dig_site != null:
		dig_site.visible = true
	if site_backdrop != null:
		site_backdrop.visible = true
		if site_backdrop.has_method("set_covers_chunk_hole"):
			site_backdrop.call("set_covers_chunk_hole", false)
	summary.show_summary(_round_fossil_pay, _round_finds_pay, _last_fossil_line, _last_fossil_stars, _round_finds)
	if hud != null:
		hud.visible = false
	_sync_menu_chrome()


func _on_layer_cleared(amount: int, world_pos: Vector2) -> void:
	GameState.add_money(amount)
	_round_finds_pay += amount
	var juice: Array = []
	if dig_site.has_method("take_matrix_juice"):
		juice = dig_site.take_matrix_juice()
	if juice.is_empty():
		_spawn_float("+$%d" % amount, world_pos, Color("E4B75A"))
		return
	for i in juice.size():
		var find: Dictionary = juice[i]
		if GameState.has_method("try_mount_matrix_find"):
			GameState.try_mount_matrix_find(find)
		var origin: Vector2 = _find_origin(find, world_pos)
		var offset := Vector2((float(i) - float(juice.size() - 1) * 0.5) * 18.0, float(i) * -10.0)
		var color := Color("E4B75A")
		match int(find.get("rarity", 0)):
			1:
				color = Color("F0D078")
			2:
				color = Color("FFE08A")
		_spawn_float(Matrix.float_text(find), origin + offset, color)
		_spawn_loot_fly(Matrix.icon_kind(find), origin, float(i) * 0.045, int(find.get("rarity", 0)))


func _on_skeleton_completed(stand_id: String, bonus: int) -> void:
	## The biggest moment in the game: louder than any single find.
	var title_text: String = "%s complete!" % GameState.stand_title(stand_id)
	var sub: String = "+$%d  ·  visitors x%s forever" % [bonus, GameState._mult_text(Tuning.complete_stand_mult)]
	if toast != null and toast.has_method("show_toast"):
		toast.show_toast(title_text, sub, 5)
	Sfx.play("unveil")
	if Tuning.shake_enabled:
		_shake_left = Tuning.shake_time * 2.5
	if screen == "dig" and dig_site != null and dig_site.visible:
		var center: Vector2 = Tuning.pit_grid_rect().get_center()
		_spawn_float(title_text.to_upper(), center + Vector2(0, -30), Color("FFE08A"), 34)
		_spawn_float("+$%d" % bonus, center + Vector2(0, 14), Color("E4B75A"), 26)
		_ping(center)


func _on_bone_sensed(world_pos: Vector2) -> void:
	_spawn_float("Bone below!", world_pos + Vector2(0, -18), Color("FFF1C4"), 18)


func _on_fossil_exposed(world_pos: Vector2, first: bool) -> void:
	if first:
		_ping(world_pos)


func _on_ready_to_dust(find_index: int = -1) -> void:
	if hud != null and hud.has_method("set_find_cards") and dig_site.has_method("live_find_cards"):
		hud.set_find_cards(dig_site.live_find_cards())
	dig_site.pulse_bones()
	var origin: Vector2 = dig_site.fossil_centroid()
	if find_index >= 0 and dig_site.has_method("find_centroid"):
		origin = dig_site.find_centroid(find_index)
	_ping(origin)
	Sfx.play("fossil_ping")
	if Tuning.shake_enabled:
		_shake_left = maxf(_shake_left, 0.18)
	_spawn_fossil_fly(find_index, origin)


func _on_fossil_extracted(fossil_name: String, value: int, integrity: float, cleanliness: float, clean: bool, piece_id: String) -> void:
	var before: int = GameState.money
	GameState.add_money(value)
	var id := piece_id if piece_id != "" else "find"
	_extract_fate = GameState.hall_fate_line(id)
	if dig_site.has_method("set_find_fate"):
		dig_site.set_find_fate(id, _extract_fate)
	GameState.install_find(id, fossil_name, cleanliness, clean)
	_round_fossil_pay += GameState.money - before
	var grade := Tuning.preservation_grade(integrity)
	var stars := Tuning.preservation_stars(integrity)
	var owns_brush: bool = GameState.owns_tool(Tuning.TOOL_BRUSH)
	var dirt := Tuning.summary_dirt_line(cleanliness, owns_brush)
	_round_finds.append({
		"name": fossil_name,
		"piece_id": id,
		"grade": grade,
		"stars": stars,
		"dirt": dirt,
		"fate": _extract_fate,
	})
	if hud.has_method("set_find_cards") and dig_site.has_method("live_find_cards"):
		hud.set_find_cards(dig_site.live_find_cards())
	if hud.has_method("catch_find") and dig_site.has_method("find_index_for"):
		hud.catch_find(int(dig_site.find_index_for(id)))
	if hud.has_method("set_find_headline"):
		hud.set_find_headline("")


func _extract_fate_for(piece_id: String, note: String) -> String:
	if GameState.has_method("hall_fate_line"):
		return str(GameState.hall_fate_line(piece_id))
	if note.to_lower().find("sold") >= 0:
		return "extra sold"
	var progress: String = GameState.piece_progress_label(piece_id)
	if not progress.is_empty():
		return "New · %s" % progress
	return "New · 1/1"


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


func _on_lucky_struck(amount: int, world_pos: Vector2) -> void:
	GameState.add_money(amount)
	_round_finds_pay += amount
	_spawn_float(Lucky.float_text(amount), world_pos, Color("FFE08A"), 28)
	_spawn_loot_fly(Lucky.icon_kind(), world_pos, 0.0, 2)
	toast.show_toast(Lucky.toast_title(), Lucky.float_text(amount))
	Sfx.play("unlock")


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


func _find_origin(find: Dictionary, fallback: Vector2) -> Vector2:
	var raw: Variant = find.get("origin", fallback)
	if raw is Vector2:
		return raw
	if raw is Vector2i:
		return Vector2(raw)
	return fallback


func _world_to_hud(world_pos: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform() * world_pos


func _spawn_fossil_fly(find_index: int, world_pos: Vector2) -> void:
	var dest := Vector2(Tuning.view_w * 0.5, Tuning.footer_find_top() + 34.0)
	if hud != null and hud.has_method("find_chip_catch_pos"):
		dest = hud.find_chip_catch_pos(find_index)
	var data: Resource = null
	if find_index >= 0 and find_index < dig_site.finds.size():
		var find: Dictionary = dig_site.finds[find_index]
		data = find.get("data", null) as Resource
	var fly = LootFlyScene.new()
	fly.setup_fossil(data, _world_to_hud(world_pos), dest)
	if hud != null and hud.has_method("catch_find"):
		fly.arrived.connect(func() -> void: hud.catch_find(find_index))
	if hud != null:
		hud.add_child(fly)
	else:
		add_child(fly)


func _spawn_loot_fly(kind: String, world_pos: Vector2, delay: float = 0.0, rarity: int = 0) -> void:
	var dest := Vector2(40, 40)
	if hud != null and hud.has_method("money_catch_pos"):
		dest = hud.money_catch_pos()
	var fly = LootFlyScene.new()
	fly.setup(kind, _world_to_hud(world_pos), dest, delay, rarity)
	if hud != null and hud.has_method("catch_loot"):
		fly.arrived.connect(func() -> void: hud.catch_loot())
	if hud != null:
		hud.add_child(fly)
	else:
		add_child(fly)


func _spawn_float(text: String, world_pos: Vector2, color: Color, font_size: int = 22) -> void:
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
