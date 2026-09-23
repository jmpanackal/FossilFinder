class_name DigHUD
extends CanvasLayer

signal tool_selected(tool: int)
signal precision_toggled
signal end_shift

const Ui := preload("res://ui_style.gd")
const ClockFace := preload("res://clock_face.gd")
const StarRating := preload("res://star_rating.gd")
const ToolIcon := preload("res://tool_icon.gd")

var _clock
var _money: Label
var _money_flash: float = 0.0
var _shown_money: int = -1
var _precision: Button
var _tool_buttons: Array[Button] = []
var _tool_slots: Array[Control] = []
var _slot_tools: Array[int] = []
var _stars
var _grade: Label
var _value: Label
var _dirt_label: Label
var _dirt_fill: ColorRect
var _find_box: VBoxContainer
var _tool_colors := [
	Color("E4B75A"),
	Color("D96A4A"),
	Color("7EC8E3"),
	Color("E4B75A"),
]
var _tool_flash: PackedFloat32Array = PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
var _clock_flash: float = 0.0


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var tools := HBoxContainer.new()
	tools.set_anchors_preset(Control.PRESET_CENTER_TOP)
	tools.offset_left = -200
	tools.offset_right = 200
	tools.offset_top = 10
	tools.offset_bottom = 92
	tools.add_theme_constant_override("separation", 18)
	tools.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(tools)
	_add_tool_slot(tools, Tuning.TOOL_HANDS)
	_add_tool_slot(tools, Tuning.TOOL_SHOVEL)
	_add_tool_slot(tools, Tuning.TOOL_PICKAXE)
	_add_tool_slot(tools, Tuning.TOOL_BRUSH)

	_precision = Button.new()
	_precision.text = "P"
	_precision.custom_minimum_size = Vector2(44, 56)
	_precision.visible = false
	_precision.pressed.connect(func() -> void: precision_toggled.emit())
	Ui.apply_button(_precision)
	tools.add_child(_precision)

	_clock = Control.new()
	_clock.set_script(ClockFace)
	_clock.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_clock.offset_left = -96
	_clock.offset_top = 12
	_clock.offset_right = -16
	_clock.offset_bottom = 92
	root.add_child(_clock)

	var menu := Button.new()
	menu.text = "Menu"
	menu.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	menu.offset_left = 16
	menu.offset_right = 120
	menu.offset_top = -52
	menu.offset_bottom = -16
	menu.custom_minimum_size = Vector2(100, 32)
	menu.add_theme_font_size_override("font_size", 13)
	Ui.apply_button(menu)
	menu.pressed.connect(func() -> void: Settings.toggle_menu())
	root.add_child(menu)

	var finish := Button.new()
	finish.text = "End shift"
	finish.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	finish.offset_left = -120
	finish.offset_right = -16
	finish.offset_top = -52
	finish.offset_bottom = -16
	finish.custom_minimum_size = Vector2(100, 32)
	finish.add_theme_font_size_override("font_size", 13)
	Ui.apply_button(finish)
	finish.pressed.connect(func() -> void:
		Sfx.play("ui")
		end_shift.emit()
	)
	root.add_child(finish)

	_money = Label.new()
	_money.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_money.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_money.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_money.offset_left = 24
	_money.offset_right = 280
	_money.offset_top = 22
	_money.offset_bottom = 70
	_money.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Ui.apply_label(_money, 28, Ui.GOLD)
	root.add_child(_money)

	_find_box = VBoxContainer.new()
	_find_box.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_find_box.offset_left = 80
	_find_box.offset_right = -80
	_find_box.offset_top = -156
	_find_box.offset_bottom = -72
	_find_box.add_theme_constant_override("separation", 4)
	_find_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_find_box.visible = false
	root.add_child(_find_box)
	_value = Label.new()
	_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Ui.apply_label(_value, 22, Ui.GOLD)
	_find_box.add_child(_value)
	_grade = Label.new()
	_grade.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_grade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Ui.apply_label(_grade, 16, Ui.MUTED)
	_find_box.add_child(_grade)
	_stars = Control.new()
	_stars.set_script(StarRating)
	_find_box.add_child(_stars)
	_dirt_label = Label.new()
	_dirt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dirt_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Ui.apply_label(_dirt_label, 14, Ui.MUTED)
	_find_box.add_child(_dirt_label)
	var track := ColorRect.new()
	track.custom_minimum_size = Vector2(220, 10)
	track.color = Color("2A2118")
	track.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_find_box.add_child(track)
	_dirt_fill = ColorRect.new()
	_dirt_fill.color = Color("C9B8A2")
	_dirt_fill.position = Vector2(1, 1)
	_dirt_fill.size = Vector2(0, 8)
	_dirt_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.add_child(_dirt_fill)

	GameState.money_changed.connect(_on_money_changed)
	_set_money_text(false)
	_highlight_tool(Tuning.TOOL_HANDS)


func refresh(time_left: float, time_max: float, tool: int, digging: bool, show_find: bool = false, stars: int = 0, grade: String = "", clean: float = 0.0, value: int = 0) -> void:
	visible = digging
	if _clock.has_method("set_time"):
		_clock.set_time(time_left, time_max)
	_set_money_text(false)
	_precision.visible = GameState.precision_unlocked()
	_precision.modulate = Color.WHITE if GameState.precision_on else Color(0.75, 0.7, 0.64)
	_highlight_tool(tool)
	_apply_tool_flashes()
	_find_box.visible = show_find
	_value.text = "$%d" % value
	_grade.text = grade
	if _stars.has_method("set_rating"):
		_stars.set_rating(stars)
	_dirt_label.text = Tuning.dirt_label(clean)
	_dirt_fill.size.x = 218.0 * clampf(clean, 0.0, 1.0)
	_dirt_fill.color = Color("E4B75A") if clean >= 0.99 else Color("C9B8A2")


func flash_upgraded_tools(tools: Array) -> void:
	for raw in tools:
		var tool: int = int(raw)
		if tool >= 0 and tool < _tool_flash.size():
			_tool_flash[tool] = 1.25


func flash_clock() -> void:
	_clock_flash = 1.2


func _process(delta: float) -> void:
	for i in _tool_flash.size():
		if _tool_flash[i] > 0.0:
			_tool_flash[i] = maxf(0.0, _tool_flash[i] - delta * 1.15)
	if _clock_flash > 0.0:
		_clock_flash = maxf(0.0, _clock_flash - delta * 1.6)
		var pulse: float = 0.4 + 0.6 * absf(sin(_clock_flash * TAU * 2.0))
		_clock.modulate = Color("FFE08A").lerp(Color.WHITE, 1.0 - _clock_flash * pulse)
	elif _clock.modulate != Color.WHITE:
		_clock.modulate = Color.WHITE
	if _money_flash <= 0.0:
		return
	_money_flash = maxf(0.0, _money_flash - delta * 4.0)
	_money.modulate = Color("FFF4D2").lerp(Color.WHITE, 1.0 - _money_flash)


func _on_money_changed() -> void:
	_set_money_text(true)


func _set_money_text(flash: bool) -> void:
	if _money == null:
		return
	var next := GameState.money
	_money.text = "$%d" % next
	if flash and next != _shown_money:
		_money_flash = 1.0
		_money.modulate = Color("FFF6D8")
	_shown_money = next


func _add_tool_slot(parent: HBoxContainer, tool: int) -> void:
	var slot := VBoxContainer.new()
	slot.add_theme_constant_override("separation", 4)
	slot.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(slot)
	_tool_slots.append(slot)
	_slot_tools.append(tool)

	var button := Button.new()
	button.custom_minimum_size = Vector2(72, 56)
	button.text = ""
	Ui.apply_button(button)
	button.pressed.connect(_on_tool_pressed.bind(tool))
	slot.add_child(button)
	var icon := Control.new()
	icon.set_script(ToolIcon)
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 8
	icon.offset_right = -8
	icon.offset_top = 6
	icon.offset_bottom = -6
	button.add_child(icon)
	if icon.has_method("setup"):
		icon.setup(tool, _tool_colors[tool])

	var key := Label.new()
	key.text = Tuning.hotkey_for_tool(tool)
	key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Ui.apply_label(key, 14, Ui.MUTED)
	slot.add_child(key)
	_tool_buttons.append(button)


func _on_tool_pressed(tool: int) -> void:
	if not GameState.owns_tool(tool):
		return
	tool_selected.emit(tool)


func _highlight_tool(tool: int) -> void:
	for i in _tool_buttons.size():
		var id: int = _slot_tools[i]
		var owned: bool = GameState.owns_tool(id)
		_tool_slots[i].visible = owned
		if not owned:
			continue
		var on: bool = id == tool
		_tool_buttons[i].disabled = false
		Ui.apply_button(_tool_buttons[i], on)
		_tool_buttons[i].modulate = Color.WHITE if on else Color(0.78, 0.74, 0.68)


func _apply_tool_flashes() -> void:
	for i in _tool_buttons.size():
		var id: int = _slot_tools[i]
		if not _tool_slots[i].visible or id >= _tool_flash.size() or _tool_flash[id] <= 0.0:
			continue
		var glow: float = _tool_flash[id]
		var pulse: float = 0.55 + 0.45 * absf(sin(glow * TAU * 2.2))
		_tool_buttons[i].modulate = Color("FFE08A").lerp(_tool_buttons[i].modulate, 1.0 - glow * pulse)
