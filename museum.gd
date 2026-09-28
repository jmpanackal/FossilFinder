extends CanvasLayer

signal closed

const Ui := preload("res://ui_style.gd")
const FloatingTextScene := preload("res://floating_text.gd")

const HEADER_H := 86.0
const HALL := Vector2(2000, 1480)
const OVERSCROLL := 48.0
const CLICK_SLOP := 10.0
const ZOOM_STEP := 0.12
const CLOSE_STAND := Vector2(480, 250)

var _visitors: Label
var _visitors_cap: Label
var _each: Label
var _each_cap: Label
var _rate: Label
var _rate_cap: Label
var _rush: Label
var _banner: Label
var _empty_lead: Label
var _empty_mid: Label
var _empty_tail: Label
var _canvas: Node2D
var _pad: Control
var _pan: Vector2 = Vector2.ZERO
var _zoom: float = 1.0
var _dragging: bool = false
var _pressing: bool = false
var _press_pad: Vector2 = Vector2.ZERO
var _moved: float = 0.0
var _banner_life: float = 0.0


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	layer = 12
	visible = false

	var bg := ColorRect.new()
	Ui.apply_field(bg)
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_canvas = Node2D.new()
	_canvas.set_script(preload("res://museum_exhibit.gd"))
	add_child(_canvas)

	_pad = Control.new()
	_pad.mouse_filter = Control.MOUSE_FILTER_STOP
	_pad.mouse_default_cursor_shape = Control.CURSOR_DRAG
	_pad.gui_input.connect(_on_hall_gui_input)
	add_child(_pad)
	_pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pad.offset_top = HEADER_H

	var bar := Panel.new()
	Ui.apply_header_bar(bar)
	add_child(bar)

	_visitors = _make_stat_label()
	_visitors_cap = _make_stat_label()
	_each = _make_stat_label()
	_each_cap = _make_stat_label()
	_rate = _make_stat_label()
	_rate_cap = _make_stat_label()
	_rush = _make_stat_label()
	_rush.visible = false

	_banner = Label.new()
	_banner.size = Vector2(920, 36)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.visible = false
	Ui.apply_section(_banner)
	add_child(_banner)
	_empty_lead = _make_stat_label()
	_empty_mid = _make_stat_label()
	_empty_tail = _make_stat_label()
	_layout_header()

	_zoom = _zoom_min()
	_pan = _clamp_pan(Vector2((_view().x - HALL.x * _zoom) * 0.5, 0.0))
	_apply_pan()

	GameState.collection_changed.connect(_refresh)
	GameState.money_changed.connect(_on_money_changed)
	visibility_changed.connect(_on_money_changed)
	GameState.hall_changed.connect(_refresh)
	Settings.menu_toggled.connect(_on_settings_toggled)
	get_viewport().size_changed.connect(_on_view_resized)
	_refresh()


func _process(delta: float) -> void:
	if not visible:
		return
	if _canvas.has_method("tick"):
		_canvas.tick(delta)
	if _banner != null and _banner.visible:
		_banner.modulate.a = clampf(_banner_life / 0.35, 0.0, 1.0) if _banner_life < 0.35 else 1.0
		_banner_life -= delta
		if _banner_life <= 0.0:
			_banner.visible = false


func _make_stat_label() -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label


func header_stats() -> Dictionary:
	var rush := ""
	if GameState.has_method("unveil_rush_line"):
		rush = str(GameState.unveil_rush_line())
	return {
		"visitors": str(GameState.museum_visitors()),
		"visitors_label": "visitors",
		"each_value": "$%.2f" % GameState.museum_donation(),
		"each_label": "each",
		"rate": "$%.2f" % GameState.museum_income(),
		"rate_label": "/ sec",
		"rush": rush,
	}


func header_cluster_rect() -> Rect2:
	var rect := Rect2()
	var started := false
	for label in [_visitors, _visitors_cap, _each, _each_cap, _rate, _rate_cap, _rush]:
		if label == null or not label.visible:
			continue
		var next := Rect2(label.position, label.size)
		if not started:
			rect = next
			started = true
		else:
			rect = rect.merge(next)
	return rect


func _layout_header() -> void:
	var view: Vector2 = _view()
	var pad: float = Ui.HEADER_PAD
	var left: float = pad
	if Settings != null and Settings.has_method("overlay_content_left"):
		left = Settings.overlay_content_left()
	var right: float = view.x - pad - 128.0
	if Settings != null and Settings.has_method("overlay_content_right"):
		right = Settings.overlay_content_right()
	var avail: float = maxf(160.0, right - left)
	var rush_on: bool = _rush != null and _rush.visible and not str(_rush.text).is_empty()
	var gap: float = 18.0
	var visitors_w: float = _stat_col_width(_visitors, _visitors_cap)
	var each_w: float = _stat_col_width(_each, _each_cap)
	var rate_w: float = _stat_col_width(_rate, _rate_cap)
	var rush_s: Vector2 = _fit_header_label(_rush, 18.0) if rush_on else Vector2.ZERO
	var cols_w: float = visitors_w + gap + each_w + gap + rate_w
	var cluster_w: float = maxf(cols_w, rush_s.x)
	if cluster_w > avail:
		var scale: float = avail / maxf(cluster_w, 1.0)
		visitors_w *= scale
		each_w *= scale
		rate_w *= scale
		cols_w = visitors_w + gap + each_w + gap + rate_w
		cluster_w = avail
		if rush_on:
			rush_s.x = avail
	var cluster_x: float = clampf(view.x * 0.5 - cluster_w * 0.5, left, right - cluster_w)
	var value_h: float = 28.0
	var cap_h: float = 16.0
	var value_y: float = 10.0 if rush_on else 16.0
	var cap_y: float = value_y + value_h
	var col_x: float = cluster_x + maxf(0.0, (cluster_w - cols_w) * 0.5)
	_place_stat_col(_visitors, _visitors_cap, col_x, visitors_w, value_y, cap_y, value_h, cap_h)
	col_x += visitors_w + gap
	_place_stat_col(_each, _each_cap, col_x, each_w, value_y, cap_y, value_h, cap_h)
	col_x += each_w + gap
	_place_stat_col(_rate, _rate_cap, col_x, rate_w, value_y, cap_y, value_h, cap_h)
	if _rush != null:
		_rush.visible = rush_on
		if rush_on:
			_rush.position = Vector2(cluster_x, cap_y + cap_h + 2.0)
			_rush.size = Vector2(cluster_w, minf(18.0, HEADER_H - (cap_y + cap_h + 4.0)))
	if _banner != null:
		_banner.position = Vector2(180.0, HEADER_H + 10.0)
	if _pad != null:
		_pad.offset_top = HEADER_H
	_layout_empty_display()


func _stat_col_width(value: Label, caption: Label) -> float:
	var value_s: Vector2 = _fit_header_label(value, 28.0)
	var cap_s: Vector2 = _fit_header_label(caption, 16.0)
	return maxf(36.0, maxf(value_s.x, cap_s.x))


func _place_stat_col(value: Label, caption: Label, x: float, width: float, value_y: float, cap_y: float, value_h: float, cap_h: float) -> void:
	if value != null:
		value.position = Vector2(x, value_y)
		value.size = Vector2(width, value_h)
		value.visible = true
	if caption != null:
		caption.position = Vector2(x, cap_y)
		caption.size = Vector2(width, cap_h)
		caption.visible = true


func _fit_header_label(label: Label, height: float) -> Vector2:
	if label == null:
		return Vector2.ZERO
	var font: Font = label.get_theme_font("font")
	var sized: int = label.get_theme_font_size("font_size")
	var width: float = 8.0
	var lines: int = 0
	for line in str(label.text).split("\n"):
		lines += 1
		if font != null:
			width = maxf(width, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, sized).x)
	var h: float = maxf(24.0, float(maxi(1, lines) * (sized + 6)))
	h = minf(height, maxf(h, height * 0.5))
	label.size = Vector2(width + 2.0, h)
	return label.size


func _view() -> Vector2:
	return Tuning.play_view_size(get_viewport().get_visible_rect().size)


func _on_view_resized() -> void:
	_layout_header()
	_zoom = clampf(_zoom, _zoom_min(), _zoom_max())
	_pan = _clamp_pan(_pan)
	_apply_pan()


func _on_settings_toggled(open: bool) -> void:
	if open:
		_pressing = false
		_end_drag()


func _input(event: InputEvent) -> void:
	if not visible or Settings.is_open():
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			_finish_press()
	elif event is InputEventMouseMotion and _pressing:
		var mm: InputEventMouseMotion = event
		_moved += mm.relative.length()
		if not _dragging and _moved >= CLICK_SLOP:
			_dragging = true
			_pad.mouse_default_cursor_shape = Control.CURSOR_MOVE
		if _dragging:
			_pan = _clamp_pan(_pan + mm.relative)
			_apply_pan()


func _on_hall_gui_input(event: InputEvent) -> void:
	if Settings.is_open():
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			if mb.pressed:
				_zoom_at(mb.position, true, mb.factor)
			_pad.accept_event()
			return
		if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if mb.pressed:
				_zoom_at(mb.position, false, mb.factor)
			_pad.accept_event()
			return
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_pressing = true
			_dragging = false
			_moved = 0.0
			_press_pad = mb.position
			_pad.accept_event()
		else:
			_finish_press()
			_pad.accept_event()


func _finish_press() -> void:
	if _pressing and not _dragging:
		_click_hall(_press_pad)
	_end_drag()
	_pressing = false


func _end_drag() -> void:
	_dragging = false
	if _pad != null:
		_pad.mouse_default_cursor_shape = Control.CURSOR_DRAG


func _click_hall(pad_pos: Vector2) -> void:
	var hall_pos: Vector2 = _pad_to_hall(pad_pos)
	var stand_id: String = ""
	if _canvas.has_method("stand_id_at"):
		stand_id = str(_canvas.stand_id_at(hall_pos))
	if stand_id.is_empty():
		return
	if GameState.stand_has_pending_unveil(stand_id):
		_unveil_stand(stand_id)
		return
	if GameState.stand_is_filled(stand_id):
		GameState.set_featured_stand(stand_id)
		if _canvas.has_method("play_feature_pop"):
			_canvas.play_feature_pop()
		Sfx.play("ui")
		_refresh()
		return


func _unveil_stand(stand_id: String) -> void:
	var title: String = GameState.unveil_title(stand_id)
	var before_surge: int = 0
	if GameState.has_method("surge_visitors"):
		before_surge = int(GameState.call("surge_visitors"))
	var paid: int = GameState.unveil_stand(stand_id)
	if _canvas.has_method("play_unveil_flash"):
		_canvas.play_unveil_flash(stand_id)
	Sfx.play("unveil")
	var extra: int = 0
	if GameState.has_method("surge_visitors"):
		extra = maxi(0, int(GameState.call("surge_visitors")) - before_surge)
	if extra > 0:
		_spawn_float("+%d visitors" % extra, stand_id)
		_toast(title, "+%d visitors" % extra)
	elif paid > 0:
		_toast(title)
	_refresh()


func _spawn_float(text: String, stand_id: String) -> void:
	var floater: Node2D = FloatingTextScene.new()
	var stand: Rect2 = Rect2()
	if _canvas.has_method("stand_rect"):
		stand = _canvas.stand_rect(stand_id)
	floater.position = stand.get_center() if stand.size != Vector2.ZERO else Vector2(1000, 700)
	floater.setup(text, Ui.GOLD, 28)
	_canvas.add_child(floater)


func _toast(title: String, subtitle: String = "") -> void:
	if _banner != null:
		_banner.text = title if subtitle.is_empty() else "%s  ·  %s" % [title, subtitle]
		_banner.visible = true
		_banner.modulate.a = 1.0
		_banner_life = 2.4
	var parent_node: Node = get_parent()
	if parent_node == null:
		return
	var toast: Node = parent_node.get_node_or_null("Toast")
	if toast != null and toast.has_method("show_toast"):
		toast.show_toast(title, subtitle)


func _pad_to_hall(pad_pos: Vector2) -> Vector2:
	var screen: Vector2 = pad_pos + Vector2(0.0, HEADER_H)
	return (screen - _pan) / maxf(_zoom, 0.001)


func _zoom_min() -> float:
	return _view().x / HALL.x


func _zoom_max() -> float:
	var view := _view()
	return maxf(_zoom_min() + 0.05, minf(view.x / CLOSE_STAND.x, view.y / CLOSE_STAND.y))


func _zoom_at(pad_pos: Vector2, inward: bool, factor: float) -> void:
	var step: float = 1.0 + ZOOM_STEP * maxf(factor, 0.1)
	if not inward:
		step = 1.0 / step
	var screen: Vector2 = pad_pos + Vector2(0.0, HEADER_H)
	var hall: Vector2 = (screen - _pan) / maxf(_zoom, 0.001)
	_zoom = clampf(_zoom * step, _zoom_min(), _zoom_max())
	_pan = _clamp_pan(screen - hall * _zoom)
	_apply_pan()


func _apply_pan() -> void:
	_canvas.position = _pan
	_canvas.scale = Vector2(_zoom, _zoom)


func _clamp_pan(p: Vector2) -> Vector2:
	var view := _view()
	var scaled: Vector2 = HALL * _zoom
	var min_x: float = view.x - scaled.x - OVERSCROLL
	var max_x: float = OVERSCROLL
	var min_y: float = view.y - scaled.y - OVERSCROLL
	var max_y: float = OVERSCROLL
	if scaled.x <= view.x:
		min_x = (view.x - scaled.x) * 0.5
		max_x = min_x
	if scaled.y <= view.y:
		min_y = (view.y - scaled.y) * 0.5
		max_y = min_y
	return Vector2(clampf(p.x, min_x, max_x), clampf(p.y, min_y, max_y))


func _on_money_changed() -> void:
	## The hall header is the only money-driven chrome; skip it while hidden.
	if visible:
		_refresh()


func _refresh() -> void:
	var stats: Dictionary = header_stats()
	_apply_stat(_visitors, str(stats.get("visitors", "")), 22, Ui.GOLD)
	_apply_stat(_visitors_cap, str(stats.get("visitors_label", "")), 11, Ui.MUTED)
	_apply_stat(_each, str(stats.get("each_value", "")), 22, Ui.GOLD)
	_apply_stat(_each_cap, str(stats.get("each_label", "")), 11, Ui.MUTED)
	_apply_stat(_rate, str(stats.get("rate", "")), 22, Ui.GOLD)
	_apply_stat(_rate_cap, str(stats.get("rate_label", "")), 11, Ui.MUTED)
	var rush: String = str(stats.get("rush", ""))
	if _rush != null:
		if rush.is_empty():
			_rush.text = ""
			_rush.visible = false
		else:
			Ui.apply_copy(_rush, rush, 11, Color("FFE08A"))
			_rush.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_rush.visible = true
	_layout_header()
	_layout_empty_display()
	if _canvas.has_method("queue_redraw"):
		_canvas.queue_redraw()


func _apply_stat(label: Label, text: String, size: int, color: Color) -> void:
	if label == null:
		return
	Ui.apply_copy(label, text, size, color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.visible = not text.is_empty()


func empty_display_line() -> String:
	return "Nothing on display yet"


func empty_display_visible() -> bool:
	var stand_id: String = str(GameState.featured_stand_id)
	if stand_id != "" and GameState.stand_is_filled(stand_id):
		return false
	## Any unveiled stand means something is on display.
	for piece_id in GameState.pieces:
		var sid: String = GameState.stand_for_piece(str(piece_id))
		if sid != "" and not GameState.stand_has_pending_unveil(sid):
			return false
	return true


func empty_display_rect() -> Rect2:
	if not empty_display_visible():
		return Rect2()
	var rect := Rect2()
	var started := false
	for label in [_empty_lead, _empty_mid, _empty_tail]:
		if label == null or not label.visible:
			continue
		var next := Rect2(label.position, label.size)
		if not started:
			rect = next
			started = true
		else:
			rect = rect.merge(next)
	return rect


func _layout_empty_display() -> void:
	var labels: Array = [_empty_lead, _empty_mid, _empty_tail]
	var words := ["Nothing", "on display", "yet"]
	if GameState.has_any_pending_unveil():
		words[2] = "yet · click a ribbon to unveil"
	if not empty_display_visible():
		for label in labels:
			if label != null:
				label.visible = false
		return
	var view: Vector2 = _view()
	var gap: float = 5.0
	var height: float = 22.0
	var pad: float = 18.0
	var widths: Array[float] = []
	var total: float = 0.0
	for i in labels.size():
		var label: Label = labels[i]
		if label == null:
			widths.append(0.0)
			continue
		Ui.apply_copy(label, str(words[i]), 16, Color("C8B080"))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var sized: Vector2 = _fit_header_label(label, height)
		var width: float = maxf(8.0, sized.x)
		widths.append(width)
		total += width
	total += gap * float(maxi(words.size() - 1, 0))
	var x: float = view.x * 0.5 - total * 0.5
	var y: float = view.y - pad - height
	for i in labels.size():
		var label: Label = labels[i]
		if label == null:
			continue
		label.position = Vector2(x, y)
		label.size = Vector2(widths[i], height)
		label.visible = true
		x += widths[i] + gap


func _hall_status_line() -> String:
	if GameState.pieces.is_empty():
		return "The hall is waiting. Bring something back from a dig."
	var dusty: bool = false
	var mounted: bool = false
	for piece_id in GameState.pieces:
		var id: String = str(piece_id)
		if GameState.stand_for_piece(id) == "":
			continue
		mounted = true
		var piece: Dictionary = GameState.pieces[id]
		if not bool(piece.get("clean", false)):
			dusty = true
	if not mounted:
		return "The hall is waiting. Bring something back from a dig."
	if dusty:
		return "A dusty find is on display. Visitors pay less."
	return "A clean find is on display."
