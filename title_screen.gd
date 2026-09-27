extends CanvasLayer

## Boot / return-to-title. Does not sit on a live shift.

signal started

const Ui := preload("res://ui_style.gd")
const SiteBackdropScript := preload("res://site_backdrop.gd")

var _title: Label
var _start: Button
var _settings: Button
var _exit: Button
var _field: Node2D


func _ready() -> void:
	layer = 22
	visible = false
	_build_ui()


func is_open() -> bool:
	return visible


func refresh_field() -> void:
	if _field != null:
		_field.queue_redraw()


func _build_ui() -> void:
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_field = Node2D.new()
	_field.set_script(SiteBackdropScript)
	root.add_child(_field)
	if _field.has_method("set_covers_chunk_hole"):
		_field.call("set_covers_chunk_hole", true)

	var wash := ColorRect.new()
	wash.color = Color(0.09, 0.06, 0.04, 0.78)
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(wash)
	wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 14)
	root.add_child(stack)
	stack.set_anchors_preset(Control.PRESET_CENTER)
	stack.offset_left = -200
	stack.offset_right = 200
	stack.offset_top = -180
	stack.offset_bottom = 220

	_title = Label.new()
	_title.text = "Fossil Finder"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Ui.apply_label(_title, 48, Ui.GOLD)
	stack.add_child(_title)

	_start = _menu_button("Start", true)
	_start.pressed.connect(_on_start_pressed)
	stack.add_child(_start)

	_settings = _menu_button("Settings", false)
	_settings.pressed.connect(_on_settings_pressed)
	stack.add_child(_settings)

	_exit = _menu_button("Exit", false)
	_exit.pressed.connect(_on_exit_pressed)
	stack.add_child(_exit)
	_exit.visible = not OS.has_feature("web")


func _menu_button(caption: String, prominent: bool) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(280, 48)
	button.clip_text = false
	button.add_theme_font_size_override("font_size", Ui.SECTION_SIZE)
	Ui.apply_button(button, prominent)
	return button


func _on_start_pressed() -> void:
	Sfx.play("ui")
	started.emit()


func _on_settings_pressed() -> void:
	Settings.open_menu()


func _on_exit_pressed() -> void:
	if OS.has_feature("web"):
		return
	GameState.save_game()
	Settings.save_settings()
	get_tree().quit()
