class_name Summary
extends CanvasLayer

signal dig_again
signal open_museum
signal open_shop

const Ui := preload("res://ui_style.gd")
const StarRating := preload("res://star_rating.gd")

var _dim: ColorRect
var _panel: Panel
var _title: Label
var _pay: Label
var _breakdown: Label
var _body: Label
var _stars
var _button: Button


func _ready() -> void:
	layer = 20
	visible = false
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_dim = ColorRect.new()
	_dim.color = Color(0.06, 0.04, 0.03, 0.72)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(_dim)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_panel = Panel.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.offset_left = -300
	_panel.offset_right = 300
	_panel.offset_top = -200
	_panel.offset_bottom = 200
	Ui.apply_panel(_panel, Color("2A1F18"))
	root.add_child(_panel)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 18
	box.offset_right = -18
	box.offset_top = 14
	box.offset_bottom = -14
	box.add_theme_constant_override("separation", 8)
	_panel.add_child(box)

	_title = Label.new()
	_title.text = "Shift over"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Ui.apply_label(_title, 28, Ui.GOLD)
	box.add_child(_title)

	_pay = Label.new()
	_pay.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Ui.apply_label(_pay, 32, Ui.GOLD)
	box.add_child(_pay)

	_breakdown = Label.new()
	_breakdown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Ui.apply_label(_breakdown, 15, Ui.MUTED)
	box.add_child(_breakdown)

	_body = Label.new()
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	Ui.apply_label(_body, 16, Ui.INK)
	box.add_child(_body)

	_stars = Control.new()
	_stars.set_script(StarRating)
	_stars.visible = false
	box.add_child(_stars)

	_button = Button.new()
	_button.text = "DIG AGAIN"
	_button.custom_minimum_size = Vector2(0, 52)
	_button.add_theme_font_size_override("font_size", 24)
	Ui.apply_button(_button, true)
	_button.pressed.connect(_on_dig_again)
	box.add_child(_button)

	var extras := HBoxContainer.new()
	extras.add_theme_constant_override("separation", 10)
	box.add_child(extras)
	extras.add_child(_small_nav("Museum", func() -> void: open_museum.emit()))
	extras.add_child(_small_nav("Upgrades", func() -> void: open_shop.emit()))


func show_summary(fossil_pay: int, dirt_pay: int, fossil_line: String, stars: int = 0) -> void:
	var shift_pay: int = fossil_pay + dirt_pay
	_pay.text = pay_headline(shift_pay)
	_breakdown.text = pay_breakdown(fossil_pay, dirt_pay)
	_breakdown.visible = not _breakdown.text.is_empty()
	_body.text = fossil_line
	if _stars.has_method("set_rating"):
		_stars.set_rating(stars)
	_stars.visible = stars > 0
	visible = true
	_button.grab_focus()


static func pay_headline(shift_pay: int) -> String:
	return "$%d" % shift_pay


static func pay_breakdown(fossil_pay: int, dirt_pay: int) -> String:
	if fossil_pay > 0 and dirt_pay > 0:
		return "Fossil $%d · dirt $%d" % [fossil_pay, dirt_pay]
	if fossil_pay > 0:
		return "Fossil $%d" % fossil_pay
	if dirt_pay > 0:
		return "dirt $%d" % dirt_pay
	return ""


static func find_line(piece_name: String, grade: String, dirt_tag: String) -> String:
	var bits: PackedStringArray = PackedStringArray()
	if not piece_name.is_empty():
		bits.append(piece_name)
	if not grade.is_empty():
		bits.append(grade)
	if not dirt_tag.is_empty():
		bits.append(dirt_tag)
	return " · ".join(bits)


func hide_summary() -> void:
	visible = false


func _small_nav(text: String, cb: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size.y = 42
	Ui.apply_button(button)
	button.pressed.connect(func() -> void:
		Sfx.play("ui")
		cb.call()
	)
	return button


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ENTER or event.physical_keycode == KEY_SPACE:
			_on_dig_again()
			get_viewport().set_input_as_handled()


func _on_dig_again() -> void:
	Sfx.play("ui")
	dig_again.emit()
