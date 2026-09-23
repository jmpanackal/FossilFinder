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
var _body: Label
var _stars
var _button: Button


func _ready() -> void:
	layer = 20
	visible = false
	_dim = ColorRect.new()
	_dim.color = Color(0.06, 0.04, 0.03, 0.62)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)

	_panel = Panel.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.offset_left = -280
	_panel.offset_right = 280
	_panel.offset_top = -148
	_panel.offset_bottom = 148
	Ui.apply_panel(_panel, Color("2A1F18"))
	add_child(_panel)

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

	_body = Label.new()
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	Ui.apply_label(_body, 18, Ui.INK)
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


func show_summary(money: int, fossil_line: String, stars: int = 0) -> void:
	_body.text = "$%d\n%s" % [money, fossil_line]
	if _stars.has_method("set_rating"):
		_stars.set_rating(stars)
	_stars.visible = stars > 0
	visible = true
	_button.grab_focus()


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
