extends CanvasLayer

## Pause overlay plus display / volume / save. Esc or HUD Menu opens it.

signal menu_toggled(open: bool)

const Ui := preload("res://ui_style.gd")
const SETTINGS_PATH := "user://settings.cfg"
const DESIGN_SIZE := Vector2i(1280, 720)

var master_volume: float = 0.8
var sfx_volume: float = 1.0
var fullscreen: bool = true

var _master: HSlider
var _sfx: HSlider
var _full: CheckButton
var _load: Button
var _status: Label
var _status_life: float = 0.0
var _refreshing: bool = false


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 50


func _ready() -> void:
	visible = false
	_build_ui()
	load_settings()
	apply_display()
	apply_volume()
	if get_tree() != null:
		get_tree().auto_accept_quit = false


func is_open() -> bool:
	return visible


func toggle_menu() -> void:
	if visible:
		close_menu()
	else:
		open_menu()


func open_menu() -> void:
	if visible:
		return
	visible = true
	_refresh_controls()
	if get_tree() != null:
		get_tree().paused = true
	menu_toggled.emit(true)
	Sfx.play("ui")


func close_menu() -> void:
	if not visible:
		return
	visible = false
	if get_tree() != null:
		get_tree().paused = false
	menu_toggled.emit(false)
	Sfx.play("ui")


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
	var dim := ColorRect.new()
	dim.color = Color(0.06, 0.04, 0.03, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(_on_dim_gui)
	add_child(dim)

	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -230
	panel.offset_right = 230
	panel.offset_top = -268
	panel.offset_bottom = 268
	Ui.apply_panel(panel, Color("2A1F18"))
	add_child(panel)

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
	Ui.apply_label(title, 28, Ui.GOLD)
	box.add_child(title)

	var hint := Label.new()
	hint.text = "Esc to close  ·  F11 fullscreen"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Ui.apply_label(hint, 13, Ui.MUTED)
	box.add_child(hint)

	var resume := Button.new()
	resume.text = "Resume"
	resume.custom_minimum_size = Vector2(0, 48)
	resume.add_theme_font_size_override("font_size", 22)
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

	var quit := Button.new()
	quit.text = "Quit"
	quit.custom_minimum_size = Vector2(0, 42)
	Ui.apply_button(quit)
	quit.pressed.connect(_on_quit_pressed)
	box.add_child(quit)


func _volume_row(caption: String, slider: HSlider, cb: Callable) -> VBoxContainer:
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 2)
	var label := Label.new()
	label.text = caption
	Ui.apply_label(label, 14, Ui.MUTED)
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


func _on_quit_pressed() -> void:
	GameState.save_game()
	save_settings()
	get_tree().quit()


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
