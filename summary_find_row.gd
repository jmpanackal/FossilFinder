class_name SummaryFindRow
extends Control

const Ui := preload("res://ui_style.gd")
const ArtCatalogScript := preload("res://art_catalog.gd")
const FossilDataScript := preload("res://fossil_data.gd")

var _icon: Control
var _label: Label
var _piece_id: String = ""
var _data: FossilDataScript


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(0, 30)
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	_icon = Control.new()
	_icon.custom_minimum_size = Vector2(36, 28)
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.draw.connect(_draw_icon)
	row.add_child(_icon)
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_label.clip_text = false
	Ui.apply_label(_label, 16, Ui.INK)
	row.add_child(_label)


func apply_find(entry: Dictionary) -> void:
	var find_name: String = str(entry.get("name", ""))
	_piece_id = str(entry.get("piece_id", ""))
	_label.text = Summary.find_line(
		find_name,
		str(entry.get("grade", "")),
		str(entry.get("dirt", "")),
		str(entry.get("fate", ""))
	)
	_label.clip_text = false
	var font: Font = _label.get_theme_font("font")
	var sized: int = _label.get_theme_font_size("font_size")
	if font != null:
		var need: float = font.get_string_size(_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, sized).x
		_label.custom_minimum_size.x = need + 2.0
	var raw: Variant = entry.get("data", null)
	if raw is FossilDataScript:
		_data = raw as FossilDataScript
	elif not _piece_id.is_empty():
		_data = GameState.fossil_data_for(_piece_id)
	if _data == null:
		_data = FossilDataScript.new()
		_data.name = find_name
		_data.piece_id = _piece_id
	if _piece_id.is_empty() and _data != null:
		_piece_id = _data.piece_id if _data.piece_id != "" else _data.name.to_snake_case()
	if _icon != null:
		_icon.queue_redraw()


func _draw_icon() -> void:
	if _icon == null:
		return
	var dest := Rect2(Vector2.ZERO, _icon.size)
	if dest.size.x < 2.0 or dest.size.y < 2.0:
		return
	if _piece_id != "" and ArtCatalogScript.draw_if_present(_icon, "bones", _piece_id, dest):
		return
	var color := Color("F7E9C6")
	if _data != null:
		_data.draw_silhouette(_icon, dest.grow(-1.0), color)
