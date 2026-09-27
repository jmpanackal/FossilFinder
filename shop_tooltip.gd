extends Panel

const Ui := preload("res://ui_style.gd")

const WRAP_W := 320.0
const PAD_X := 14.0
const PAD_Y := 10.0
const FONT_SIZE := 14

var _label: Label


func setup(text: String) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false
	add_theme_stylebox_override("panel", Ui.tooltip_box())

	if _label == null:
		_label = Label.new()
		_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_label)
	_label.text = text
	Ui.apply_label(_label, FONT_SIZE, Ui.INK)
	_fit(text)


func _fit(text: String) -> void:
	var font: Font = _label.get_theme_font("font")
	var one_line: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE)
	var inner_w: float = one_line.x
	var inner_h: float = maxf(one_line.y, float(FONT_SIZE) + 4.0)
	if inner_w > WRAP_W:
		inner_w = WRAP_W
		var wrapped: Vector2 = font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, WRAP_W, FONT_SIZE)
		inner_h = maxf(wrapped.y, inner_h)
		_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	else:
		_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	inner_w = maxf(inner_w, 160.0)
	_label.custom_minimum_size = Vector2(inner_w, inner_h)
	_label.position = Vector2(PAD_X, PAD_Y)
	_label.size = Vector2(inner_w, inner_h)
	custom_minimum_size = Vector2(inner_w + PAD_X * 2.0, inner_h + PAD_Y * 2.0)
	size = custom_minimum_size
