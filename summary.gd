class_name Summary
extends CanvasLayer

signal dig_again

var _dim: ColorRect
var _panel: Panel
var _title: Label
var _body: Label
var _button: Button


func _ready() -> void:
	layer = 20
	visible = false
	_dim = ColorRect.new()
	_dim.color = Color(0.04, 0.03, 0.02, 0.72)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)

	_panel = Panel.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.offset_left = -280
	_panel.offset_right = 280
	_panel.offset_top = -210
	_panel.offset_bottom = 230
	add_child(_panel)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 28
	box.offset_right = -28
	box.offset_top = 24
	box.offset_bottom = -24
	box.add_theme_constant_override("separation", 14)
	_panel.add_child(box)

	_title = Label.new()
	_title.text = "ROUND OVER"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 36)
	box.add_child(_title)

	_body = Label.new()
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.add_theme_font_size_override("font_size", 20)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_body)

	var spacer := Control.new()
	spacer.custom_minimum_size.y = 12
	box.add_child(spacer)

	_button = Button.new()
	_button.text = "DIG AGAIN"
	_button.custom_minimum_size = Vector2(0, 84)
	_button.add_theme_font_size_override("font_size", 32)
	_button.pressed.connect(_on_dig_again)
	box.add_child(_button)


func show_summary(depth_m: float, round_money: int, session_money: int, fossil_line: String) -> void:
	_body.text = "Depth reached: %.1f m\nMoney this round: $%d\nTotal money: $%d\n\n%s" % [
		depth_m, round_money, session_money, fossil_line
	]
	visible = true
	_button.grab_focus()


func hide_summary() -> void:
	visible = false


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
