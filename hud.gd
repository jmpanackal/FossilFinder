class_name DigHUD
extends CanvasLayer

signal tool_selected(tool: int)
signal end_shift

const Ui := preload("res://ui_style.gd")
const ClockFace := preload("res://clock_face.gd")
const StarRating := preload("res://star_rating.gd")
const ToolIcon := preload("res://tool_icon.gd")

var _clock
var _money: Label
var _pouch: Control
var _income: Label
var _money_flash: float = 0.0
var _pouch_pop: float = 0.0
var _shown_money: int = -1
var _chip: Button
var _goal_key: String = ""
var _goal_pop: float = 0.0
var _tool_role: Label
var _tool_buttons: Array[Button] = []
var _tool_slots: Array[Control] = []
var _slot_tools: Array[int] = []
var _stars
var _headline: Label
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
var _equipped_tool: int = Tuning.TOOL_HANDS


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var tools := HBoxContainer.new()
	tools.set_anchors_preset(Control.PRESET_CENTER_TOP)
	tools.offset_left = -260
	tools.offset_right = 260
	tools.offset_top = 6
	tools.offset_bottom = 94
	tools.add_theme_constant_override("separation", 18)
	tools.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(tools)
	_add_tool_slot(tools, Tuning.TOOL_HANDS)
	_add_tool_slot(tools, Tuning.TOOL_SHOVEL)
	_add_tool_slot(tools, Tuning.TOOL_PICKAXE)
	_add_tool_slot(tools, Tuning.TOOL_BRUSH)
	_tool_role = Label.new()
	_tool_role.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tool_role.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_tool_role.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tool_role.custom_minimum_size = Vector2(72, 16)
	_tool_role.clip_text = false
	Ui.apply_label(_tool_role, 11, Color("2C2118"))
	_tool_role.add_theme_color_override("font_outline_color", Color("F6EDE0"))
	_tool_role.add_theme_constant_override("outline_size", 3)

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
	menu.offset_right = 132
	menu.offset_top = -48
	menu.offset_bottom = -12
	menu.custom_minimum_size = Vector2(112, 32)
	menu.clip_text = false
	menu.add_theme_font_size_override("font_size", 13)
	Ui.apply_button(menu)
	menu.pressed.connect(func() -> void: Settings.toggle_menu())
	root.add_child(menu)

	var finish := Button.new()
	finish.text = "End shift"
	finish.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	finish.offset_left = -140
	finish.offset_right = -16
	finish.offset_top = -48
	finish.offset_bottom = -12
	finish.custom_minimum_size = Vector2(120, 32)
	finish.clip_text = false
	finish.add_theme_font_size_override("font_size", 13)
	Ui.apply_button(finish)
	finish.pressed.connect(func() -> void:
		Sfx.play("ui")
		end_shift.emit()
	)
	root.add_child(finish)

	_pouch = Control.new()
	_pouch.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_pouch.offset_left = 16
	_pouch.offset_top = 20
	_pouch.offset_right = 48
	_pouch.offset_bottom = 58
	_pouch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pouch.pivot_offset = Vector2(16, 19)
	_pouch.draw.connect(_draw_pouch)
	root.add_child(_pouch)

	_money = Label.new()
	_money.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_money.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_money.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_money.offset_left = 50
	_money.offset_right = 300
	_money.offset_top = 22
	_money.offset_bottom = 70
	_money.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Ui.apply_label(_money, 28, Ui.GOLD)
	root.add_child(_money)

	_income = Label.new()
	_income.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_income.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_income.offset_left = 26
	_income.offset_right = 280
	_income.offset_top = 64
	_income.offset_bottom = 84
	_income.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_income.visible = false
	Ui.apply_label(_income, 14, Ui.MUTED)
	root.add_child(_income)

	_chip = Button.new()
	_chip.text = ""
	_chip.custom_minimum_size = Vector2(360, 44)
	_chip.clip_contents = true
	_chip.clip_text = true
	_chip.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_chip.add_theme_font_size_override("font_size", 13)
	Ui.apply_button(_chip)
	_chip.pressed.connect(_on_next_chip)
	root.add_child(_chip)
	_chip.visible = false

	_find_box = VBoxContainer.new()
	_find_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_find_box.clip_contents = true
	_find_box.add_theme_constant_override("separation", 0)
	_find_box.visible = false
	root.add_child(_find_box)
	var title_row := HBoxContainer.new()
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	title_row.add_theme_constant_override("separation", 10)
	_find_box.add_child(title_row)
	_headline = Label.new()
	_headline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_headline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_headline.custom_minimum_size = Vector2(0, 18)
	_headline.visible = false
	Ui.apply_label(_headline, 18, Ui.GOLD)
	title_row.add_child(_headline)
	_value = Label.new()
	_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_value.custom_minimum_size = Vector2(0, 18)
	Ui.apply_label(_value, 16, Ui.GOLD)
	title_row.add_child(_value)
	_grade = Label.new()
	_grade.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_grade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grade.custom_minimum_size = Vector2(0, 14)
	Ui.apply_label(_grade, 12, Ui.MUTED)
	_find_box.add_child(_grade)
	_stars = Control.new()
	_stars.set_script(StarRating)
	_stars.custom_minimum_size = Vector2(140, 16)
	_find_box.add_child(_stars)
	_dirt_label = Label.new()
	_dirt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dirt_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dirt_label.custom_minimum_size = Vector2(0, 12)
	Ui.apply_label(_dirt_label, 11, Ui.MUTED)
	_find_box.add_child(_dirt_label)
	var track := ColorRect.new()
	track.custom_minimum_size = Vector2(220, 6)
	track.color = Color("2A2118")
	track.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_find_box.add_child(track)
	_dirt_fill = ColorRect.new()
	_dirt_fill.color = Color("C9B8A2")
	_dirt_fill.position = Vector2(1, 1)
	_dirt_fill.size = Vector2(0, 4)
	_dirt_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.add_child(_dirt_fill)

	GameState.money_changed.connect(_on_money_changed)
	_set_money_text(false)
	_highlight_tool(Tuning.TOOL_HANDS)


func refresh(time_left: float, time_max: float, tool: int, digging: bool, show_find: bool = false, stars: int = 0, grade: String = "", clean: float = 0.0, value: int = 0) -> void:
	visible = digging
	_equipped_tool = tool
	if _clock.has_method("set_time"):
		_clock.set_time(time_left, time_max)
	_set_money_text(false)
	_highlight_tool(tool)
	_apply_tool_flashes()
	_find_box.visible = show_find
	_value.text = "$%d" % value
	_grade.text = grade
	if _stars.has_method("set_rating"):
		_stars.set_rating(stars)
	_dirt_label.text = Tuning.dirt_label(clean)
	_dirt_fill.size.x = 218.0 * clampf(clean, 0.0, 1.0)
	_dirt_fill.size.y = 4.0
	_dirt_fill.color = Color("E4B75A") if clean >= 0.99 else Color("C9B8A2")
	_refresh_goal_chrome()


func set_find_headline(text: String) -> void:
	if _headline == null:
		return
	_headline.text = text
	_headline.visible = not text.is_empty()


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
	if _goal_pop > 0.0:
		_goal_pop = maxf(0.0, _goal_pop - delta * 2.4)
	if _chip != null:
		_chip.scale = Vector2(1.0 + _goal_pop * 0.12, 1.0 + _goal_pop * 0.12)
	if _chip != null and _chip.visible:
		var shop_id: String = GameState.next_shop_id(_equipped_tool)
		var heat: bool = not shop_id.is_empty() and GameState.can_buy(shop_id)
		var pulse: float = 0.72 + 0.28 * absf(sin(float(Time.get_ticks_msec()) * 0.008))
		_chip.modulate = Color("FFE08A").lerp(Color.WHITE, 1.0 - pulse) if heat else Color(0.82, 0.78, 0.72)
	if _pouch_pop > 0.0:
		_pouch_pop = maxf(0.0, _pouch_pop - delta * 5.5)
		if _pouch != null:
			var squash: float = 1.0 + _pouch_pop * 0.22
			_pouch.scale = Vector2(squash, 1.0 + _pouch_pop * 0.1)
			_pouch.queue_redraw()
	elif _pouch != null and _pouch.scale != Vector2.ONE:
		_pouch.scale = Vector2.ONE
	if _money_flash <= 0.0:
		return
	_money_flash = maxf(0.0, _money_flash - delta * 4.0)
	_money.modulate = Color("FFF4D2").lerp(Color.WHITE, 1.0 - _money_flash)


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
	if _income != null:
		var rate_line: String = GameState.museum_rate_line()
		_income.visible = not rate_line.is_empty()
		_income.text = rate_line


func _add_tool_slot(parent: HBoxContainer, tool: int) -> void:
	var slot := VBoxContainer.new()
	slot.add_theme_constant_override("separation", 2)
	slot.alignment = BoxContainer.ALIGNMENT_CENTER
	slot.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	parent.add_child(slot)
	_tool_slots.append(slot)
	_slot_tools.append(tool)

	var button := Button.new()
	button.custom_minimum_size = Vector2(72, 44)
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
	Ui.apply_label(key, 12, Ui.MUTED)
	slot.add_child(key)
	_tool_buttons.append(button)


func _place_tool_role(tool: int) -> void:
	if _tool_role == null:
		return
	_tool_role.text = GameState.tool_role_line(tool)
	_tool_role.visible = visible and not _tool_role.text.is_empty()
	var slot_i: int = _slot_tools.find(tool)
	if slot_i < 0 or slot_i >= _tool_slots.size():
		return
	var slot: Control = _tool_slots[slot_i]
	if _tool_role.get_parent() != slot:
		var prior: Node = _tool_role.get_parent()
		if prior != null:
			prior.remove_child(_tool_role)
		slot.add_child(_tool_role)


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
	_place_tool_role(tool)


func _apply_tool_flashes() -> void:
	for i in _tool_buttons.size():
		var id: int = _slot_tools[i]
		if not _tool_slots[i].visible or id >= _tool_flash.size() or _tool_flash[id] <= 0.0:
			continue
		var glow: float = _tool_flash[id]
		var pulse: float = 0.55 + 0.45 * absf(sin(glow * TAU * 2.2))
		_tool_buttons[i].modulate = Color("FFE08A").lerp(_tool_buttons[i].modulate, 1.0 - glow * pulse)


func _refresh_goal_chrome() -> void:
	if _chip == null:
		return
	var shop_id: String = GameState.next_shop_id(_equipped_tool)
	var show_chip: bool = visible and not shop_id.is_empty()
	_chip.visible = show_chip
	if show_chip:
		var cost: int = GameState.cost_of(shop_id)
		var caption: String = GameState.next_goal_chip_text(shop_id, cost)
		_chip.text = caption
		var can_buy: bool = GameState.can_buy(shop_id)
		_chip.disabled = not can_buy
		Ui.apply_button(_chip, can_buy)
		_chip.add_theme_font_size_override("font_size", 13)
		_chip.add_theme_color_override("font_color", Ui.INK)
		_chip.add_theme_color_override("font_disabled_color", Ui.MUTED)
		if not _goal_key.is_empty() and shop_id != _goal_key:
			_goal_pop = 1.0
		_goal_key = shop_id
	else:
		_chip.text = ""
		_chip.disabled = true
		_goal_key = ""
	_layout_footer()


func _layout_footer() -> void:
	var footer: float = Tuning.footer_top()
	var row_h: float = Tuning.footer_goal_h()
	var side: float = 16.0
	var chip_w: float = 360.0
	var available: float = maxf(360.0, Tuning.view_w - side * 2.0)
	chip_w = minf(chip_w, available)
	var chip_x: float = (Tuning.view_w - chip_w) * 0.5
	_chip.anchor_left = 0.0
	_chip.anchor_top = 0.0
	_chip.anchor_right = 0.0
	_chip.anchor_bottom = 0.0
	_chip.position = Vector2(chip_x, footer)
	_chip.size = Vector2(chip_w, row_h)
	_chip.pivot_offset = Vector2(chip_w * 0.5, row_h * 0.5)
	var gutter: float = Tuning.footer_menu_gutter()
	var find_top: float = Tuning.footer_find_top()
	var find_bottom: float = Tuning.view_h - 8.0
	_find_box.anchor_left = 0.0
	_find_box.anchor_top = 0.0
	_find_box.anchor_right = 0.0
	_find_box.anchor_bottom = 0.0
	var find_h: float = maxf(1.0, find_bottom - find_top)
	_find_box.custom_minimum_size = Vector2(0, 0)
	_find_box.position = Vector2(gutter, find_top)
	_find_box.size = Vector2(maxf(160.0, Tuning.view_w - gutter * 2.0), find_h)


func _on_next_chip() -> void:
	var shop_id: String = GameState.next_shop_id(_equipped_tool)
	if shop_id.is_empty() or not GameState.buy(shop_id):
		return
	GameState.save_game()
	_goal_pop = 1.0
	_refresh_goal_chrome()
