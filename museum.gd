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

var _income: Label
var _rush: Label
var _note: Label
var _money: Label
var _back: Button
var _banner: Label
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

	_back = Button.new()
	_back.text = "Back"
	Ui.apply_nav(_back)
	_back.pressed.connect(func() -> void:
		Sfx.play("ui")
		closed.emit()
	)
	add_child(_back)

	_money = Label.new()
	_money.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Ui.apply_wallet(_money)
	add_child(_money)

	_income = Label.new()
	_income.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_income.clip_text = false
	_income.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	Ui.apply_label(_income, Ui.BODY_SIZE, Ui.GOLD)
	add_child(_income)

	_rush = Label.new()
	_rush.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rush.clip_text = false
	_rush.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	Ui.apply_label(_rush, 15, Ui.GOLD)
	add_child(_rush)

	_note = Label.new()
	_note.autowrap_mode = TextServer.AUTOWRAP_OFF
	_note.clip_text = true
	_note.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_note.max_lines_visible = 2
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Ui.apply_caption(_note)
	add_child(_note)

	_banner = Label.new()
	_banner.size = Vector2(920, 36)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.visible = false
	Ui.apply_section(_banner)
	add_child(_banner)
	_layout_header()

	_zoom = _zoom_min()
	_pan = _clamp_pan(Vector2((_view().x - HALL.x * _zoom) * 0.5, 0.0))
	_apply_pan()

	GameState.collection_changed.connect(_refresh)
	GameState.money_changed.connect(_refresh)
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
	_money.text = "$%d" % GameState.money
	_income.text = _exhibit_income_line()
	var rush_on: bool = _rush.visible
	_rush.text = GameState.unveil_rush_line()
	_rush.visible = not _rush.text.is_empty()
	if _rush.visible != rush_on:
		_layout_header()


func _exhibit_income_line() -> String:
	return "$%.2f / sec from the exhibit" % GameState.museum_income()


func _layout_header() -> void:
	var view: Vector2 = _view()
	var pad: float = Ui.HEADER_PAD
	var back_size: Vector2 = Ui.NAV_SIZE
	if _back != null:
		_back.position = Vector2(pad, (HEADER_H - back_size.y) * 0.5)
		_back.size = back_size
	var gap: float = 20.0
	var left: float = pad + back_size.x + 12.0
	var right: float = view.x - pad
	var avail: float = maxf(160.0, right - left)
	var rush_on: bool = _rush != null and not str(_rush.text).is_empty()
	var money_s: Vector2 = _fit_header_label(_money, 40.0)
	var income_s: Vector2 = _fit_header_label(_income, 28.0)
	var rush_s: Vector2 = _fit_header_label(_rush, 28.0) if rush_on else Vector2.ZERO
	var mid_w: float = maxf(income_s.x, rush_s.x)
	var note_s: Vector2 = _fit_header_label(_note, HEADER_H - 16.0)
	var cluster_w: float = money_s.x + gap + mid_w + gap + note_s.x
	if cluster_w > avail and _note != null:
		var note_max: float = maxf(80.0, avail - money_s.x - mid_w - gap * 2.0)
		_note.size = Vector2(note_max, note_s.y)
		_note.clip_text = true
		note_s.x = note_max
		cluster_w = money_s.x + gap + mid_w + gap + note_s.x
	var cluster_x: float = left + maxf(0.0, (avail - cluster_w) * 0.5)
	if _money != null:
		_money.position = Vector2(cluster_x, (HEADER_H - money_s.y) * 0.5)
		_money.size = money_s
	var mid_x: float = cluster_x + money_s.x + gap
	if _income != null:
		_income.position = Vector2(mid_x, 12.0 if rush_on else (HEADER_H - income_s.y) * 0.5)
		_income.size = Vector2(mid_w, income_s.y)
	if _rush != null:
		_rush.position = Vector2(mid_x, 44.0)
		_rush.size = Vector2(mid_w, rush_s.y if rush_on else 28.0)
		_rush.visible = rush_on
	if _note != null:
		_note.position = Vector2(mid_x + mid_w + gap, (HEADER_H - note_s.y) * 0.5)
		_note.size = note_s
	if _banner != null:
		_banner.position = Vector2(180.0, HEADER_H + 10.0)
	if _pad != null:
		_pad.offset_top = HEADER_H


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
	_toast("Nothing on display yet")


func _unveil_stand(stand_id: String) -> void:
	var title: String = GameState.unveil_title(stand_id)
	var paid: int = GameState.unveil_stand(stand_id)
	if _canvas.has_method("play_unveil_flash"):
		_canvas.play_unveil_flash(stand_id)
	Sfx.play("unveil")
	var rate: float = GameState.unveil_rush_rate()
	if rate > 0.0:
		_spawn_float("+$%.2f/sec" % rate, stand_id)
		_toast(title, "+$%.2f/sec from unveiling rush" % rate)
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


func _refresh() -> void:
	_money.text = "$%d" % GameState.money
	_income.text = _exhibit_income_line()
	_rush.text = GameState.unveil_rush_line()
	var bits: PackedStringArray = []
	if GameState.has_any_pending_unveil():
		var waiting: String = GameState.pending_unveil_waiting_line()
		bits.append(waiting if not waiting.is_empty() else "A new find is waiting to be unveiled.")
	if GameState.featured_stand_id != "":
		bits.append("%s featured" % GameState.stand_title(GameState.featured_stand_id))
	if bits.is_empty():
		_note.text = _hall_status_line()
	else:
		_note.text = "\n".join(bits)
	_layout_header()
	if _canvas.has_method("queue_redraw"):
		_canvas.queue_redraw()


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
