extends Panel

signal buy_pressed(id: String)

const Ui := preload("res://ui_style.gd")
const ShopIcon := preload("res://shop_icon.gd")
const WELL_PX := 52

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
var _state_key: String = ""
var afford: AffordBar
var _held: bool = false
var _hold_t: float = 0.0
var _last_level: int = -1
const HOLD_DELAY := 0.35
const HOLD_STEP := 0.16


func setup(id: String) -> void:
	item_id = id
	custom_minimum_size = Vector2(0, 96)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 8
	row.offset_right = -8
	row.offset_top = 6
	row.offset_bottom = -6

	var well_slot := CenterContainer.new()
	well_slot.custom_minimum_size = Vector2(WELL_PX, WELL_PX)
	well_slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	well_slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	well_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(well_slot)

	well = Panel.new()
	well.custom_minimum_size = Vector2(WELL_PX, WELL_PX)
	well.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	well.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	well.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Ui.apply_icon_well(well, Color("1B1410"))
	well_slot.add_child(well)
	icon = ShopIcon.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	well.add_child(icon)
	if icon.has_method("setup"):
		icon.setup(ShopIcon.glyph_for(id), Ui.GOLD)

	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 4)
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
	action.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(action)

	button = TipButton.new()
	button.custom_minimum_size = Vector2(168, 48)
	button.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	button.offset_left = -84
	button.offset_right = 84
	button.offset_top = -24
	button.offset_bottom = 24
	Ui.apply_button(button, true)
	button.pressed.connect(func() -> void: buy_pressed.emit(item_id))
	## Hold the button to keep buying ranks.
	button.button_down.connect(func() -> void:
		_held = true
		_hold_t = -HOLD_DELAY)
	button.button_up.connect(func() -> void: _held = false)
	action.add_child(button)
	afford = AffordBar.new()
	afford.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.add_child(afford)

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
	## Money ticks refresh the shop constantly. Rebuilding copy (which re-runs
	## the upgrade math) and restyling is ~1ms per row, so skip unchanged rows.
	var cost: int = GameState.cost_of(item_id)
	var ratio: float = clampf(float(GameState.money) / float(maxi(cost, 1)), 0.0, 1.0)
	var key: String = "%d|%s|%s|%s|%s|%s|%d" % [level, heat, offer, GameState.can_buy(item_id), cost, _juicing(), int(ratio * 40.0)]
	if key == _state_key:
		return
	_state_key = key
	title.text = GameState.shop_display_name(item_id)
	desc.text = GameState.shop_effect_line(item_id)
	tooltip_text = ""
	button.tooltip_text = ""
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
	## Saving-up bar: how close the wallet is to this price.
	if afford != null:
		afford.set_ratio(ratio if can_purchase and heat != "locked" else 1.0)
	if _last_level >= 0 and level > _last_level:
		_flash_bought()
	_last_level = level
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
		Ui.apply_icon_well(well, Color("3A2A18") if heat == "glow" else Color("1B1410"))


func _get_tooltip(_at_position: Vector2) -> String:
	return ""


func _process(delta: float) -> void:
	if not _held:
		return
	if button == null or not button.is_pressed() or not is_visible_in_tree():
		_held = false
		return
	_hold_t += delta
	if _hold_t >= HOLD_STEP:
		_hold_t -= HOLD_STEP
		if GameState.can_buy(item_id):
			buy_pressed.emit(item_id)


func _flash_bought() -> void:
	## The new rank pip flashes and the effect line glows with its new value.
	if pips != null and pips.has_method("flash_last"):
		pips.call("flash_last")
	if desc != null:
		desc.modulate = Color("FFE08A")
		var tw := create_tween()
		tw.tween_property(desc, "modulate", Color.WHITE, 0.6)


## Force the next refresh() to rebuild even if the row state looks the same.
func invalidate() -> void:
	_state_key = ""


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


class TipButton extends Button:
	func _get_tooltip(_at_position: Vector2) -> String:
		return ""


class AffordBar extends Control:
	## Thin bar along the bottom of a Buy button showing savings toward it.
	var ratio: float = 1.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_ratio(value: float) -> void:
		if is_equal_approx(value, ratio):
			return
		ratio = value
		queue_redraw()

	func _draw() -> void:
		if ratio >= 1.0 or ratio <= 0.0:
			return
		var bar := Rect2(6.0, size.y - 8.0, (size.x - 12.0), 4.0)
		draw_rect(bar, Color(0, 0, 0, 0.45))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y)), Color("E4B75A"))
		var font := Ui.display_font()
		var pct: String = "%d%%" % int(floor(ratio * 100.0))
		draw_string(font, Vector2(size.x - 34.0, 13.0), pct, HORIZONTAL_ALIGNMENT_RIGHT, 28, 10, Color(Ui.GOLD, 0.8))


class PipBar extends Control:
	var level: int = 0
	var max_level: int = 1
	var heat: String = "dim"
	var _flash: float = 0.0

	func flash_last() -> void:
		_flash = 1.0
		set_process(true)

	func _process(delta: float) -> void:
		if _flash <= 0.0:
			set_process(false)
			return
		_flash = maxf(0.0, _flash - delta * 1.6)
		queue_redraw()


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
			if filled and i == level - 1 and _flash > 0.0:
				fill = fill.lerp(Color.WHITE, _flash)
				draw_rect(box.grow(2.0 * _flash), Color(1, 0.9, 0.5, 0.6 * _flash), false, 2.0)
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
		var font := Ui.display_font()
		draw_string(font, Vector2(-28, 6), "MAXED", HORIZONTAL_ALIGNMENT_CENTER, 56, 16, Color("F6EDE0"))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
