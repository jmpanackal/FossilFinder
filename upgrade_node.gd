extends Panel

signal buy_pressed(id: String)

const Ui := preload("res://ui_style.gd")
const ShopIcon := preload("res://shop_icon.gd")

var item_id: String = ""
var title: Label
var desc: Label
var button: Button
var icon: Control
var pips: Control
var seal: Control
var lock: Label
var rank: Label
var well: Panel


func setup(id: String) -> void:
	item_id = id
	custom_minimum_size = Vector2(0, 88)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 8
	row.offset_right = -8
	row.offset_top = 6
	row.offset_bottom = -6

	well = Panel.new()
	well.custom_minimum_size = Vector2(56, 56)
	well.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Ui.apply_panel(well, Color("1B1410"))
	row.add_child(well)
	icon = ShopIcon.new()
	icon.custom_minimum_size = Vector2(56, 56)
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	well.add_child(icon)
	if icon.has_method("setup"):
		icon.setup(ShopIcon.glyph_for(id), Ui.GOLD)

	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 2)
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(text)

	title = Label.new()
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Ui.apply_label(title, 18, Ui.INK)
	text.add_child(title)

	desc = Label.new()
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc.custom_minimum_size.x = 160
	Ui.apply_label(desc, 13, Ui.MUTED)
	text.add_child(desc)

	var progress := HBoxContainer.new()
	progress.add_theme_constant_override("separation", 8)
	text.add_child(progress)
	pips = PipBar.new()
	pips.custom_minimum_size = Vector2(148, 16)
	progress.add_child(pips)
	rank = Label.new()
	Ui.apply_label(rank, 13, Ui.GOLD)
	progress.add_child(rank)

	var action := Control.new()
	action.custom_minimum_size = Vector2(168, 56)
	row.add_child(action)

	button = Button.new()
	button.custom_minimum_size = Vector2(168, 48)
	button.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	button.offset_left = -84
	button.offset_right = 84
	button.offset_top = -24
	button.offset_bottom = 24
	Ui.apply_button(button, true)
	button.pressed.connect(func() -> void: buy_pressed.emit(item_id))
	action.add_child(button)

	lock = Label.new()
	lock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lock.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lock.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lock.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Ui.apply_label(lock, 13, Ui.MUTED)
	action.add_child(lock)

	seal = MaxSeal.new()
	seal.custom_minimum_size = Vector2(88, 56)
	seal.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	seal.offset_left = -44
	seal.offset_right = 44
	seal.offset_top = -28
	seal.offset_bottom = 28
	seal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	action.add_child(seal)

	refresh()


func refresh() -> void:
	if item_id.is_empty():
		return
	var item: Dictionary = _item()
	if item.is_empty():
		return
	var level: int = int(GameState.levels.get(item_id, 0))
	var max_level: int = int(item.get("max", 1))
	var heat: String = GameState.shop_row_heat(item_id)
	var offer: bool = GameState.is_unlock_offer(item_id)
	title.text = GameState.shop_display_name(item_id)
	desc.text = GameState.shop_item_desc(item_id)
	if icon.has_method("setup"):
		icon.setup(ShopIcon.glyph_for(item_id), Ui.GOLD if heat != "locked" else Color("7A6A58"), heat == "locked")

	var show_pips: bool = not offer
	pips.visible = show_pips
	rank.visible = show_pips
	if show_pips and pips.has_method("set_ranks"):
		pips.set_ranks(level, max_level, heat)
	rank.text = "%d / %d" % [level, max_level]
	rank.add_theme_color_override("font_color", Ui.GOLD if heat == "maxed" or heat == "glow" else Ui.MUTED)

	var can_purchase: bool = heat != "locked" and heat != "maxed"
	button.visible = can_purchase
	button.text = GameState.shop_button_label(item_id)
	button.disabled = not GameState.can_buy(item_id)
	Ui.apply_button(button, heat == "glow")

	lock.visible = heat == "locked"
	lock.text = GameState.lock_reason(item_id)

	seal.visible = heat == "maxed"
	if seal.has_method("refresh"):
		seal.refresh()

	if not _juicing():
		add_theme_stylebox_override("panel", Ui.row_box(heat))
		modulate = Color.WHITE if heat != "dim" else Color(0.78, 0.74, 0.70)
		if heat == "locked":
			modulate = Color(0.66, 0.62, 0.58)
	if well != null:
		Ui.apply_panel(well, Color("3A2A18") if heat == "glow" else Color("1B1410"))


func _juicing() -> bool:
	if not has_meta("juice_tween"):
		return false
	var tw: Tween = get_meta("juice_tween")
	return tw != null and is_instance_valid(tw) and tw.is_running()


func _item() -> Dictionary:
	for entry in GameState.catalog:
		if str(entry["id"]) == item_id:
			return entry
	return {}


class PipBar extends Control:
	var level: int = 0
	var max_level: int = 1
	var heat: String = "dim"


	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE


	func set_ranks(next_level: int, next_max: int, next_heat: String) -> void:
		level = next_level
		max_level = maxi(next_max, 1)
		heat = next_heat
		queue_redraw()


	func _draw() -> void:
		var count: int = max_level
		var gap := 3.0
		var pip_w: float = maxf(10.0, (size.x - gap * float(count - 1)) / float(count))
		var pip_h: float = size.y
		for i in count:
			var x: float = float(i) * (pip_w + gap)
			var box := Rect2(x, 0.0, pip_w, pip_h)
			var filled: bool = i < level
			var fill := Color("E4B75A") if filled else Color("3F342A")
			if filled and heat == "maxed":
				fill = Color("F0D48A")
			draw_rect(box, fill)
			draw_rect(box, Color("8A6A40") if filled else Color("6A523C"), false, 1.0)


class MaxSeal extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		queue_redraw()


	func refresh() -> void:
		queue_redraw()


	func _draw() -> void:
		var c: Vector2 = size * 0.5
		draw_set_transform(c, -0.18, Vector2.ONE)
		var box := Rect2(Vector2(-36, -16), Vector2(72, 32))
		draw_rect(box, Color("3A2C18"))
		draw_rect(box, Color("E4B75A"), false, 3.0)
		draw_rect(Rect2(box.position + Vector2(3, 3), box.size - Vector2(6, 6)), Color("C9A056"), false, 1.0)
		var font := get_theme_default_font()
		draw_string(font, Vector2(-28, 6), "MAXED", HORIZONTAL_ALIGNMENT_CENTER, 56, 16, Color("F6EDE0"))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
