extends CanvasLayer

const Ui := preload("res://ui_style.gd")

var _name: Label
var _progress: Label
var _status: Label
var _log: Label


func _ready() -> void:
	layer = 8
	var bar := Panel.new()
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_top = -Tuning.find_bar_h
	bar.offset_bottom = 0
	Ui.apply_bar(bar, Color("1B1410"))
	add_child(bar)

	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 24
	row.offset_right = -24
	row.offset_top = 12
	row.offset_bottom = -12
	row.add_theme_constant_override("separation", 28)
	bar.add_child(row)

	var title := Label.new()
	title.text = "THIS FIND"
	Ui.apply_label(title, 16, Ui.GOLD)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(title)

	_name = _col_label(20, Ui.INK)
	_progress = _col_label(16, Ui.MUTED)
	_status = _col_label(16, Ui.GOLD)
	row.add_child(_name)
	row.add_child(_progress)
	row.add_child(_status)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	_log = _col_label(15, Ui.MUTED)
	_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(_log)
	set_log("Dig out the whole bone, then brush it clean.")


func refresh(fossil_name: String, exposed: int, needed: int, cleanliness: float, extracted: bool, extracted_clean: bool) -> void:
	if needed <= 0:
		_name.text = "No fossil this round"
		_progress.text = ""
		_status.text = ""
		return
	_name.text = fossil_name
	_progress.text = "Uncovered  %d / %d" % [exposed, needed]
	if extracted:
		_status.text = "Brought out clean" if extracted_clean else "Brought out dirty"
	elif exposed <= 0:
		_status.text = "Still underground"
	elif exposed < needed:
		_status.text = "Keep uncovering the shape"
	else:
		_status.text = "Cleaned  %d%%  —  brush the bone" % int(round(cleanliness * 100.0))


func set_log(text: String) -> void:
	_log.text = text


func _col_label(size: int, color: Color) -> Label:
	var label := Label.new()
	Ui.apply_label(label, size, color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label
