class_name DigHUD
extends CanvasLayer

var _timer: Label
var _depth: Label
var _tool: Label
var _money: Label


func _ready() -> void:
	var bar := ColorRect.new()
	bar.color = Color(0.08, 0.06, 0.04, 0.92)
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_bottom = 52
	add_child(bar)

	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_TOP_WIDE)
	row.offset_left = 20
	row.offset_right = -20
	row.offset_top = 8
	row.offset_bottom = 44
	row.add_theme_constant_override("separation", 36)
	add_child(row)

	_timer = _make_label("1:00", 28)
	_depth = _make_label("DEPTH 0.0 m", 22)
	_tool = _make_label("SHOVEL", 22)
	_money = _make_label("$0", 26)
	_money.add_theme_color_override("font_color", Color("F2D36B"))
	row.add_child(_timer)
	row.add_child(_depth)
	row.add_child(_tool)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	row.add_child(_money)


func refresh(time_left: float, depth_m: float, tool_name: String, round_money: int) -> void:
	var seconds := maxi(0, int(ceili(time_left)))
	var minutes: int = int(float(seconds) / 60.0)
	_timer.text = "%d:%02d" % [minutes, seconds % 60]
	_timer.add_theme_color_override("font_color", Color("E24B4B") if seconds <= 10 else Color("F4EFE6"))
	_depth.text = "DEPTH %.1f m" % depth_m
	_tool.text = tool_name
	_money.text = "$%d" % round_money


func _make_label(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color("F4EFE6"))
	return label
