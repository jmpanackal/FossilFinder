extends CanvasLayer

## Pause overlay plus display / volume / save. Esc or the shared Menu button opens it.

signal menu_toggled(open: bool)
signal title_requested

const Ui := preload("res://ui_style.gd")
const SETTINGS_PATH := "user://settings.cfg"
const DESIGN_SIZE := Vector2i(1280, 720)

var master_volume: float = 0.8
var sfx_volume: float = 1.0
var fullscreen: bool = true

var _overlay: Control
var _menu_btn: Button
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
var _chrome_allowed: bool = true
var _title_return_allowed: bool = true


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 50


func _ready() -> void:
	visible = true
	_build_ui()
	load_settings()
	apply_display()
	apply_volume()
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
	_chrome_allowed = on
	if _menu_btn != null:
		_menu_btn.visible = on and not is_open()


func set_title_return_visible(on: bool) -> void:
	_title_return_allowed = on
	if _title_btn != null:
		_title_btn.visible = on


func _layout_menu_chrome() -> void:
	if _menu_btn == null:
		return
	_menu_btn.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_menu_btn.anchor_right = 0.0
	_menu_btn.anchor_bottom = 0.0
	_menu_btn.position = Vector2(Tuning.view_w - 8.0 - 120.0, Tuning.hud_h + 8.0)
	_menu_btn.size = Vector2(120, 36)


func _set_overlay_open(open: bool) -> void:
	if _overlay != null:
		_overlay.visible = open
	if _menu_btn != null:
		_menu_btn.visible = (not open) and _chrome_allowed


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
	_menu_btn = Button.new()
	_menu_btn.text = "Menu"
	_menu_btn.custom_minimum_size = Vector2(120, 36)
	_menu_btn.clip_text = false
	_menu_btn.focus_mode = Control.FOCUS_NONE
	_menu_btn.add_theme_font_size_override("font_size", Ui.META_SIZE)
	Ui.apply_button(_menu_btn)
	_menu_btn.pressed.connect(toggle_menu)
	add_child(_menu_btn)
	_layout_menu_chrome()

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

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 22
	box.offset_right = -22
	box.offset_top = 16
	box.offset_bottom = -16
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

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
	Sfx.play("ui")


func _hide_new_game_confirm() -> void:
	if _confirm_wrap != null:
		_confirm_wrap.visible = false
	if _new_game != null:
		_new_game.visible = true


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
