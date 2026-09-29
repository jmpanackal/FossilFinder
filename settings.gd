extends CanvasLayer

## Pause overlay plus display / volume / save. Esc or the shared Menu button opens it.

signal menu_toggled(open: bool)
signal title_requested
signal back_pressed
signal end_shift_pressed
signal dig_pressed
signal museum_pressed
signal upgrades_pressed

const Ui := preload("res://ui_style.gd")
const ShopIcon := preload("res://shop_icon.gd")
const SETTINGS_PATH := "user://settings.cfg"
const DESIGN_SIZE := Vector2i(1280, 720)
const WALLET_MONEY_SAMPLE := "$8888888"
const WALLET_RATE_SAMPLE := "$8888.88/s"
const WALLET_RIGHT_PAD := 20.0

var master_volume: float = 0.8
var sfx_volume: float = 1.0
var fullscreen: bool = true

var _overlay: Control
var _menu_panel: Panel
var _menu_box: VBoxContainer
var _nav_bar: HBoxContainer
var _menu_btn: Button
var _back_btn: Button
var _end_btn: Button
var _dig_btn: Button
var _museum_btn: Button
var _upgrades_btn: Button
var _nav_context: String = "dig"
var _master: HSlider
var _sfx: HSlider
var _full: CheckButton
var _load: Button
var _new_game: Button
var _title_btn: Button
var _confirm_wrap: VBoxContainer
var _status: Label
var _status_life: float = 0.0
var _refreshing: bool = false
var _chrome_allowed: bool = false
var _nav_allowed: bool = false
var _end_shift_allowed: bool = false
var _title_return_allowed: bool = true
var _wallet_allowed: bool = false
var _wallet: PanelContainer
var _money: Label
var _income: Label
var _income_row: HBoxContainer
var _income_mark: Control
var _pouch: Control
var _money_flash: float = 0.0
var _pouch_pop: float = 0.0
var _shown_money: int = -1


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 50


func _ready() -> void:
	visible = true
	_build_ui()
	load_settings()
	apply_display()
	apply_volume()
	if GameState != null and not GameState.money_changed.is_connected(refresh_wallet):
		GameState.money_changed.connect(func() -> void: refresh_wallet(true))
		## The $/s line depends on the hall, not just the bank; keep it current.
		GameState.collection_changed.connect(func() -> void: refresh_wallet(false))
		GameState.hall_changed.connect(func() -> void: refresh_wallet(false))
	refresh_wallet(false)
	if get_tree() != null:
		get_tree().auto_accept_quit = false


func is_open() -> bool:
	return _overlay != null and _overlay.visible


func toggle_menu() -> void:
	if is_open():
		close_menu()
	else:
		open_menu()


func open_menu() -> void:
	if is_open():
		return
	_set_overlay_open(true)
	_refresh_controls()
	_fit_menu_panel()
	if get_tree() != null:
		get_tree().paused = true
	menu_toggled.emit(true)
	Sfx.play("ui")


func close_menu() -> void:
	if not is_open():
		return
	_hide_new_game_confirm()
	_set_overlay_open(false)
	if get_tree() != null:
		get_tree().paused = false
	menu_toggled.emit(false)
	Sfx.play("ui")


func set_menu_chrome_visible(on: bool) -> void:
	set_nav_visible(on)


func set_nav_visible(on: bool) -> void:
	_nav_allowed = on
	_chrome_allowed = on
	_apply_nav_visibility()


func set_nav_context(context: String) -> void:
	_nav_context = context
	_apply_nav_visibility()


func set_end_shift_visible(on: bool) -> void:
	_end_shift_allowed = on
	_apply_nav_visibility()


func set_title_return_visible(on: bool) -> void:
	_title_return_allowed = on
	if _title_btn != null:
		_title_btn.visible = on


func set_wallet_visible(on: bool) -> void:
	_wallet_allowed = on
	if _wallet != null:
		_wallet.visible = on


func wallet_rect() -> Rect2:
	if _wallet == null:
		return Rect2(12, 6, 1, 1)
	return Rect2(_wallet.position, _wallet.size)


func overlay_content_left() -> float:
	var bank: Rect2 = wallet_rect()
	return maxf(16.0, bank.position.x + bank.size.x + 12.0)


func overlay_content_right() -> float:
	var nav: Rect2 = nav_rect()
	var right: float = Tuning.view_w - 8.0
	if nav.size.x > 1.0:
		right = nav.position.x - 12.0
	var reserved: float = _overlay_nav_reserve_width()
	return minf(right, Tuning.view_w - 8.0 - reserved - 12.0)


func nav_rect() -> Rect2:
	if _nav_bar == null:
		return Rect2(Tuning.view_w - 128.0, 6.0, 1, 1)
	return Rect2(_nav_bar.position, _nav_bar.size)


func money_catch_pos() -> Vector2:
	if _pouch != null:
		return _pouch.global_position + _pouch.size * 0.5
	if _money != null:
		return _money.global_position + Vector2(18, 16)
	return Vector2(40, 40)


func catch_loot() -> void:
	_money_flash = 1.0
	_pouch_pop = 1.0
	if _money != null:
		_money.modulate = Color("FFF6D8")
	if _pouch != null:
		_pouch.queue_redraw()


func refresh_wallet(flash: bool = false) -> void:
	if _money == null:
		return
	var next: int = GameState.money
	_money.text = "$%d" % next
	if flash and next != _shown_money:
		catch_loot()
	_shown_money = next
	if _income != null:
		var rate_line: String = GameState.museum_rate_line()
		var show_rate: bool = not rate_line.is_empty()
		_income.visible = show_rate
		_income.text = rate_line
		if _income_row != null:
			_income_row.visible = show_rate
		if _income_mark != null:
			_income_mark.visible = show_rate
	_layout_wallet()


func _layout_menu_chrome() -> void:
	_layout_nav_chrome()


func _set_overlay_open(open: bool) -> void:
	if _overlay != null:
		_overlay.visible = open
	_apply_nav_visibility()


func apply_display() -> void:
	var win := get_window()
	if win == null:
		return
	win.content_scale_size = DESIGN_SIZE
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	if fullscreen:
		if win.mode != Window.MODE_FULLSCREEN and win.mode != Window.MODE_EXCLUSIVE_FULLSCREEN:
			win.mode = Window.MODE_FULLSCREEN
	elif win.mode == Window.MODE_FULLSCREEN or win.mode == Window.MODE_EXCLUSIVE_FULLSCREEN:
		win.mode = Window.MODE_MAXIMIZED


func apply_volume() -> void:
	_set_bus_linear("Master", master_volume)
	Sfx.ensure_bus()
	_set_bus_linear("SFX", sfx_volume)


func set_fullscreen(on: bool) -> void:
	fullscreen = on
	apply_display()
	save_settings()


func toggle_fullscreen() -> void:
	set_fullscreen(not fullscreen)
	_refresh_controls()


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key: InputEventKey = event
	if key.physical_keycode == KEY_F11:
		toggle_fullscreen()
		get_viewport().set_input_as_handled()
	elif key.physical_keycode == KEY_ESCAPE:
		toggle_menu()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _pouch_pop > 0.0:
		_pouch_pop = maxf(0.0, _pouch_pop - delta * 5.5)
		if _pouch != null:
			var squash: float = 1.0 + _pouch_pop * 0.22
			_pouch.scale = Vector2(squash, 1.0 + _pouch_pop * 0.1)
			_pouch.queue_redraw()
	elif _pouch != null and _pouch.scale != Vector2.ONE:
		_pouch.scale = Vector2.ONE
	if _money_flash > 0.0 and _money != null:
		_money_flash = maxf(0.0, _money_flash - delta * 4.0)
		_money.modulate = Color("FFF4D2").lerp(Color.WHITE, 1.0 - _money_flash)
	if _status == null or _status_life <= 0.0:
		return
	_status_life -= delta
	_status.modulate.a = 1.0 if _status_life > 0.35 else clampf(_status_life / 0.35, 0.0, 1.0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		GameState.save_game()
		save_settings()
		get_tree().quit()


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	master_volume = clampf(float(cfg.get_value("audio", "master", master_volume)), 0.0, 1.0)
	sfx_volume = clampf(float(cfg.get_value("audio", "sfx", sfx_volume)), 0.0, 1.0)
	fullscreen = bool(cfg.get_value("display", "fullscreen", fullscreen))


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master", master_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.save(SETTINGS_PATH)


func _build_ui() -> void:
	_build_nav_chrome()
	_build_wallet()

	_overlay = Control.new()
	_overlay.visible = false
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var dim := ColorRect.new()
	dim.color = Ui.DIM
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(_on_dim_gui)
	_overlay.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel := Panel.new()
	Ui.apply_modal(panel)
	_overlay.add_child(panel)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -230
	panel.offset_right = 230
	panel.offset_top = -330
	panel.offset_bottom = 330
	_menu_panel = panel

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 22
	box.offset_right = -22
	box.offset_top = 16
	box.offset_bottom = -16
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	_menu_box = box

	var title := Label.new()
	title.text = "Settings"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Ui.apply_title(title)
	box.add_child(title)

	var hint := Label.new()
	hint.text = "Esc to close  ·  F11 fullscreen"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Ui.apply_caption(hint)
	box.add_child(hint)

	var resume := Button.new()
	resume.text = "Resume"
	resume.custom_minimum_size = Vector2(0, 48)
	resume.add_theme_font_size_override("font_size", Ui.SECTION_SIZE)
	Ui.apply_button(resume, true)
	resume.pressed.connect(close_menu)
	box.add_child(resume)

	_master = HSlider.new()
	box.add_child(_volume_row("Master volume", _master, _on_master_changed))
	_sfx = HSlider.new()
	box.add_child(_volume_row("Sound effects", _sfx, _on_sfx_changed))

	_full = CheckButton.new()
	_full.text = "Fullscreen"
	_full.focus_mode = Control.FOCUS_NONE
	Ui.apply_check(_full)
	_full.toggled.connect(_on_fullscreen_toggled)
	box.add_child(_full)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	row.add_child(_action_button("Save", _on_save_pressed))
	_load = _action_button("Load", _on_load_pressed)
	row.add_child(_load)

	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.modulate.a = 0.0
	Ui.apply_label(_status, 14, Ui.GOLD)
	box.add_child(_status)

	_new_game = Button.new()
	_new_game.text = "New game"
	_new_game.custom_minimum_size = Vector2(0, 42)
	Ui.apply_button(_new_game)
	_new_game.pressed.connect(_on_new_game_pressed)
	box.add_child(_new_game)

	_confirm_wrap = VBoxContainer.new()
	_confirm_wrap.visible = false
	_confirm_wrap.add_theme_constant_override("separation", 8)
	box.add_child(_confirm_wrap)
	var confirm_label := Label.new()
	confirm_label.text = "Erase save and start over?"
	confirm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	confirm_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	Ui.apply_label(confirm_label, 14, Ui.GOLD)
	_confirm_wrap.add_child(confirm_label)
	var confirm_row := HBoxContainer.new()
	confirm_row.add_theme_constant_override("separation", 10)
	_confirm_wrap.add_child(confirm_row)
	confirm_row.add_child(_action_button("Erase", _on_new_game_confirmed))
	confirm_row.add_child(_action_button("Cancel", _hide_new_game_confirm))

	_title_btn = Button.new()
	_title_btn.text = "Title"
	_title_btn.custom_minimum_size = Vector2(0, 42)
	Ui.apply_button(_title_btn)
	_title_btn.pressed.connect(_on_title_pressed)
	box.add_child(_title_btn)

	var quit := Button.new()
	quit.text = "Quit"
	quit.custom_minimum_size = Vector2(0, 42)
	Ui.apply_button(quit)
	quit.pressed.connect(_on_quit_pressed)
	box.add_child(quit)
	quit.visible = not OS.has_feature("web")
	_fit_menu_panel()


## The panel hugs its contents (no empty band at the bottom), and re-fits when
## the erase confirmation opens or closes.
func _fit_menu_panel() -> void:
	if _menu_panel == null or _menu_box == null:
		return
	var h: float = _menu_box.get_combined_minimum_size().y + 32.0
	var half: float = ceilf(h * 0.5)
	_menu_panel.offset_top = -half
	_menu_panel.offset_bottom = half


func _volume_row(caption: String, slider: HSlider, cb: Callable) -> VBoxContainer:
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 2)
	var label := Label.new()
	label.text = caption
	Ui.apply_caption(label)
	wrap.add_child(label)
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 1.0
	slider.custom_minimum_size = Vector2(0, 22)
	Ui.apply_slider(slider)
	slider.value_changed.connect(cb)
	wrap.add_child(slider)
	return wrap


func _action_button(text: String, cb: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size.y = 42
	Ui.apply_button(button)
	button.pressed.connect(cb)
	return button


func _refresh_controls() -> void:
	if _master == null:
		return
	_refreshing = true
	_master.value = master_volume * 100.0
	_sfx.value = sfx_volume * 100.0
	_full.button_pressed = fullscreen
	_load.disabled = not GameState.has_save()
	_refreshing = false


func _on_dim_gui(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			close_menu()


func _on_master_changed(value: float) -> void:
	if _refreshing:
		return
	master_volume = clampf(value / 100.0, 0.0, 1.0)
	apply_volume()
	save_settings()


func _on_sfx_changed(value: float) -> void:
	if _refreshing:
		return
	sfx_volume = clampf(value / 100.0, 0.0, 1.0)
	apply_volume()
	save_settings()


func _on_fullscreen_toggled(on: bool) -> void:
	if _refreshing:
		return
	set_fullscreen(on)


func _on_save_pressed() -> void:
	if GameState.save_game():
		_flash_status("Saved")
	else:
		_flash_status("Could not save")
	_refresh_controls()
	Sfx.play("ui")


func _on_load_pressed() -> void:
	if GameState.load_game():
		_flash_status("Loaded")
	else:
		_flash_status("No save yet")
	_refresh_controls()
	Sfx.play("ui")


func _on_title_pressed() -> void:
	GameState.save_game()
	close_menu()
	title_requested.emit()


func _on_quit_pressed() -> void:
	GameState.save_game()
	save_settings()
	if OS.has_feature("web"):
		return
	get_tree().quit()


func _on_new_game_pressed() -> void:
	if _new_game != null:
		_new_game.visible = false
	if _confirm_wrap != null:
		_confirm_wrap.visible = true
	_fit_menu_panel()
	Sfx.play("ui")


func _hide_new_game_confirm() -> void:
	if _confirm_wrap != null:
		_confirm_wrap.visible = false
	if _new_game != null:
		_new_game.visible = true
	_fit_menu_panel()


func _on_new_game_confirmed() -> void:
	GameState.reset_progress()
	_hide_new_game_confirm()
	close_menu()


func _flash_status(text: String) -> void:
	_status.text = text
	_status.modulate.a = 1.0
	_status_life = 1.8


func _set_bus_linear(bus_name: String, linear: float) -> void:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	var amount: float = clampf(linear, 0.0, 1.0)
	AudioServer.set_bus_volume_db(idx, -80.0 if amount <= 0.001 else linear_to_db(amount))


func _build_wallet() -> void:
	_wallet = PanelContainer.new()
	_wallet.name = "WalletChrome"
	_wallet.visible = _wallet_allowed
	_wallet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wallet.add_theme_stylebox_override("panel", Ui.wallet_box())
	add_child(_wallet)
	var wallet_row := HBoxContainer.new()
	wallet_row.add_theme_constant_override("separation", 8)
	wallet_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wallet.add_child(wallet_row)
	_pouch = Control.new()
	_pouch.custom_minimum_size = Vector2(32, 38)
	_pouch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pouch.pivot_offset = Vector2(16, 19)
	_pouch.draw.connect(_draw_pouch)
	wallet_row.add_child(_pouch)
	var wallet_stack := VBoxContainer.new()
	wallet_stack.add_theme_constant_override("separation", 0)
	wallet_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	wallet_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wallet_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wallet_row.add_child(wallet_stack)
	_money = Label.new()
	_money.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_money.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_money.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Ui.apply_wallet(_money)
	wallet_stack.add_child(_money)
	_income_row = HBoxContainer.new()
	_income_row.add_theme_constant_override("separation", int(Ui.ICON_GAP))
	_income_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	_income_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_income_row.visible = false
	wallet_stack.add_child(_income_row)
	_income_mark = Control.new()
	_income_mark.name = "MuseumRateMark"
	_income_mark.set_script(ShopIcon)
	ShopIcon.apply_action(_income_mark)
	_income_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _income_mark.has_method("setup"):
		_income_mark.setup(ShopIcon.glyph_for_action("Museum"), Ui.GOLD)
	_income_row.add_child(_income_mark)
	_income = Label.new()
	_income.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_income.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_income.visible = false
	Ui.apply_caption(_income)
	_income_row.add_child(_income)
	_layout_wallet()


func _layout_wallet() -> void:
	if _wallet == null:
		return
	_reserve_wallet_width()
	_wallet.reset_size()
	var wallet_min: Vector2 = _wallet.get_combined_minimum_size()
	_wallet.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_wallet.anchor_right = 0.0
	_wallet.anchor_bottom = 0.0
	_wallet.position = Vector2(12, 6)
	_wallet.size = Vector2(maxf(_wallet_reserved_width(), wallet_min.x), maxf(_wallet.size.y, wallet_min.y))


func _draw_pouch() -> void:
	if _pouch == null:
		return
	var glow: float = _pouch_pop
	var body := Color("C47A3A").lerp(Color("FFE08A"), glow * 0.35)
	var mouth := Color("6B4423")
	var cord := Color("E4B75A")
	var center := Vector2(16, 22)
	_pouch.draw_circle(center + Vector2(0, 2), 11.0, mouth)
	_pouch.draw_circle(center + Vector2(0, 3), 9.0, body)
	_pouch.draw_arc(center + Vector2(0, -3), 6.5, PI + 0.15, TAU - 0.15, 12, cord, 2.0)
	_pouch.draw_circle(center + Vector2(0, -8), 2.2, cord)


func _wallet_rate_text_width() -> float:
	var font: Font = Ui.display_font()
	return font.get_string_size(WALLET_RATE_SAMPLE, HORIZONTAL_ALIGNMENT_LEFT, -1, Ui.CAPTION_SIZE).x


func _wallet_text_col_width() -> float:
	var font: Font = Ui.display_font()
	var money_w: float = font.get_string_size(WALLET_MONEY_SAMPLE, HORIZONTAL_ALIGNMENT_LEFT, -1, Ui.WALLET_SIZE).x
	var rate_row: float = _wallet_rate_text_width() + Ui.ACTION_ICON + Ui.ICON_GAP
	return maxf(money_w, rate_row)


func _wallet_reserved_width() -> float:
	var pad_left: float = 8.0
	var pad_right: float = WALLET_RIGHT_PAD
	if _wallet != null:
		var box: StyleBox = _wallet.get_theme_stylebox("panel")
		if box != null:
			pad_left = box.content_margin_left
			pad_right = box.content_margin_right
	return pad_left + 32.0 + 8.0 + _wallet_text_col_width() + pad_right


func _reserve_wallet_width() -> void:
	var text_w: float = _wallet_text_col_width()
	if _money != null:
		_money.custom_minimum_size.x = text_w
	if _income != null:
		_income.custom_minimum_size.x = _wallet_rate_text_width()
	if _wallet != null:
		_wallet.custom_minimum_size.x = _wallet_reserved_width()


func _build_nav_chrome() -> void:
	_nav_bar = HBoxContainer.new()
	_nav_bar.name = "NavChrome"
	_nav_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_nav_bar.alignment = BoxContainer.ALIGNMENT_END
	_nav_bar.add_theme_constant_override("separation", 8)
	add_child(_nav_bar)
	_end_btn = _make_nav_button("End shift", func() -> void:
		Sfx.play("ui")
		end_shift_pressed.emit()
	)
	_nav_bar.add_child(_end_btn)
	_back_btn = _make_nav_button("Back", func() -> void:
		Sfx.play("ui")
		back_pressed.emit()
	)
	_nav_bar.add_child(_back_btn)
	_dig_btn = _make_nav_button("Dig", func() -> void:
		Sfx.play("ui")
		dig_pressed.emit()
	)
	_nav_bar.add_child(_dig_btn)
	_museum_btn = _make_nav_button("Museum", func() -> void:
		Sfx.play("ui")
		museum_pressed.emit()
	)
	_nav_bar.add_child(_museum_btn)
	_upgrades_btn = _make_nav_button("Upgrades", func() -> void:
		Sfx.play("ui")
		upgrades_pressed.emit()
	)
	_nav_bar.add_child(_upgrades_btn)
	_menu_btn = _make_nav_button("Menu", toggle_menu)
	_nav_bar.add_child(_menu_btn)
	_apply_nav_visibility()


func _apply_nav_visibility() -> void:
	var show_bar: bool = _nav_chrome_on()
	if _nav_bar != null:
		_nav_bar.visible = show_bar
	if _menu_btn != null:
		_menu_btn.visible = show_bar
	if _back_btn != null:
		_back_btn.visible = _back_nav_on()
	if _end_btn != null:
		_end_btn.visible = show_bar and _end_shift_allowed
	if _dig_btn != null:
		_dig_btn.visible = _dig_nav_on()
	if _museum_btn != null:
		_museum_btn.visible = _museum_nav_on()
	if _upgrades_btn != null:
		_upgrades_btn.visible = _upgrades_nav_on()
	_layout_nav_chrome()


func _layout_nav_chrome() -> void:
	if _nav_bar == null:
		return
	_place_nav_marks()
	_nav_bar.reset_size()
	var width: float = _nav_cluster_width()
	_nav_bar.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_nav_bar.anchor_right = 0.0
	_nav_bar.anchor_bottom = 0.0
	_nav_bar.position = Vector2(Tuning.view_w - 8.0 - width, 6.0)
	_nav_bar.size = Vector2(maxf(width, 1.0), 36.0)
	_nav_bar.notification(Container.NOTIFICATION_SORT_CHILDREN)
	_place_nav_marks()


func _nav_cluster_width() -> float:
	return _measure_nav_width(_visible_nav_buttons())


func _overlay_nav_reserve_width() -> float:
	return _measure_nav_width([_dig_btn, _upgrades_btn, _menu_btn])


func _visible_nav_buttons() -> Array:
	var shown: Array = []
	for raw in [_end_btn, _back_btn, _dig_btn, _museum_btn, _upgrades_btn, _menu_btn]:
		var child: Control = raw as Control
		if child == null or not child.visible:
			continue
		if child == _end_btn and not _end_shift_allowed:
			continue
		shown.append(child)
	return shown


func _measure_nav_width(buttons: Array) -> float:
	if _nav_bar == null:
		return 1.0
	var sep: float = float(_nav_bar.get_theme_constant("separation"))
	var width: float = 0.0
	var shown: int = 0
	for raw in buttons:
		var child: Control = raw as Control
		if child == null:
			continue
		width += maxf(child.get_combined_minimum_size().x, child.custom_minimum_size.x)
		shown += 1
	if shown > 1:
		width += sep * float(shown - 1)
	return maxf(width, 1.0)


func _nav_chrome_on() -> bool:
	return _nav_allowed and not is_open()


func _back_nav_on() -> bool:
	## The live dig has End shift and Menu; Back there only risked quitting a shift.
	return _nav_chrome_on() and _nav_context == "summary"


func _dig_nav_on() -> bool:
	return _nav_chrome_on() and (_nav_context == "shop" or _nav_context == "museum")


func _museum_nav_on() -> bool:
	return _nav_chrome_on() and _nav_context == "shop"


func _upgrades_nav_on() -> bool:
	return _nav_chrome_on() and _nav_context == "museum"


func _place_nav_marks() -> void:
	for raw in [_menu_btn, _back_btn, _end_btn, _dig_btn, _museum_btn, _upgrades_btn]:
		var btn: Button = raw as Button
		if btn == null:
			continue
		ShopIcon.place_left_of_label(btn, btn.get_node_or_null("ActionMark") as Control)


func _make_nav_button(text: String, pressed: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	var font: Font = Ui.display_font()
	var text_w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, Ui.META_SIZE).x
	btn.custom_minimum_size = Vector2(maxf(96.0, ceili(text_w + 32.0 + Ui.ACTION_ICON + Ui.ICON_GAP)), 36.0)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.clip_text = false
	btn.autowrap_mode = TextServer.AUTOWRAP_OFF
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", Ui.META_SIZE)
	Ui.apply_hud_button(btn)
	btn.pressed.connect(pressed)
	var glyph: String = ShopIcon.glyph_for_action(text)
	if not glyph.is_empty():
		var mark: Control = ShopIcon.new()
		mark.name = "ActionMark"
		ShopIcon.apply_action(mark)
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if mark.has_method("setup"):
			mark.setup(glyph, Ui.GOLD)
		btn.add_child(mark)
	return btn
