extends CanvasLayer

signal closed

const Ui := preload("res://ui_style.gd")
const FloatingTextScene := preload("res://floating_text.gd")

const VIEW := Vector2(1280, 720)
const HEADER_H := 68.0
const HALL := Vector2(2000, 1480)
const OVERSCROLL := 48.0
const CLICK_SLOP := 10.0
const WHEEL_PAN := 72.0

var _income: Label
var _note: Label
var _money: Label
var _banner: Label
var _canvas: Node2D
var _pad: Control
var _pan: Vector2 = Vector2.ZERO
var _dragging: bool = false
var _pressing: bool = false
var _press_pad: Vector2 = Vector2.ZERO
var _moved: float = 0.0
var _banner_life: float = 0.0


func _ready() -> void:
	layer = 12
	visible = false

	var bg := ColorRect.new()
	bg.color = Color("1A1410")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_canvas = Node2D.new()
	_canvas.set_script(preload("res://museum_exhibit.gd"))
	add_child(_canvas)

	_pad = Control.new()
	_pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pad.offset_top = HEADER_H
	_pad.mouse_filter = Control.MOUSE_FILTER_STOP
	_pad.mouse_default_cursor_shape = Control.CURSOR_DRAG
	_pad.gui_input.connect(_on_hall_gui_input)
	add_child(_pad)

	var bar := Panel.new()
	bar.position = Vector2.ZERO
	bar.size = Vector2(VIEW.x, HEADER_H)
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	Ui.apply_bar(bar, Ui.PAPER_DEEP, false)
	add_child(bar)

	var back := Button.new()
	back.text = "Back"
	back.position = Vector2(24, 14)
	back.custom_minimum_size = Vector2(100, 40)
	Ui.apply_button(back)
	back.pressed.connect(func() -> void:
		Sfx.play("ui")
		closed.emit()
	)
	add_child(back)

	_money = Label.new()
	_money.position = Vector2(140, 18)
	_money.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Ui.apply_label(_money, 22, Ui.GOLD)
	add_child(_money)

	_income = Label.new()
	_income.position = Vector2(300, 20)
	_income.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Ui.apply_label(_income, 18, Ui.GOLD)
	add_child(_income)

	_note = Label.new()
	_note.position = Vector2(760, 18)
	_note.size = Vector2(500, 40)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Ui.apply_label(_note, 15, Ui.MUTED)
	add_child(_note)

	_banner = Label.new()
	_banner.position = Vector2(180, 78)
	_banner.size = Vector2(920, 36)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.visible = false
	Ui.apply_label(_banner, 22, Ui.GOLD)
	add_child(_banner)

	_pan = _clamp_pan(Vector2((VIEW.x - HALL.x) * 0.5, 0.0))
	_apply_pan()

	GameState.collection_changed.connect(_refresh)
	GameState.money_changed.connect(_refresh)
	GameState.hall_changed.connect(_refresh)
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
	var income_line: String = "$%.1f / sec from the exhibit" % GameState.museum_income()
	if GameState.unveil_spike_left > 0.0:
		income_line += "  ·  unveil rush"
	_income.text = income_line


func _input(event: InputEvent) -> void:
	if not visible:
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
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			if mb.pressed:
				_pan = _clamp_pan(_pan + Vector2(0.0, WHEEL_PAN * maxf(mb.factor, 0.1)))
				_apply_pan()
			_pad.accept_event()
			return
		if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if mb.pressed:
				_pan = _clamp_pan(_pan + Vector2(0.0, -WHEEL_PAN * maxf(mb.factor, 0.1)))
				_apply_pan()
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
	var hall_pos: Vector2 = pad_pos + Vector2(0.0, HEADER_H) - _pan
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
	var paid: int = GameState.unveil_stand(stand_id)
	if _canvas.has_method("play_unveil_flash"):
		_canvas.play_unveil_flash(stand_id)
	Sfx.play("unveil")
	if paid > 0:
		_spawn_float("+$%d" % paid, stand_id)
		_toast("Unveiled!", "+$%d  ·  visitors rush in" % paid)
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


func _apply_pan() -> void:
	_canvas.position = _pan


func _clamp_pan(p: Vector2) -> Vector2:
	var min_x: float = VIEW.x - HALL.x - OVERSCROLL
	var max_x: float = OVERSCROLL
	var min_y: float = VIEW.y - HALL.y - OVERSCROLL
	var max_y: float = OVERSCROLL
	if HALL.x <= VIEW.x:
		min_x = (VIEW.x - HALL.x) * 0.5
		max_x = min_x
	if HALL.y <= VIEW.y:
		min_y = (VIEW.y - HALL.y) * 0.5
		max_y = min_y
	return Vector2(clampf(p.x, min_x, max_x), clampf(p.y, min_y, max_y))


func _refresh() -> void:
	_money.text = "$%d" % GameState.money
	var income_line: String = "$%.1f / sec from the exhibit" % GameState.museum_income()
	if GameState.unveil_spike_left > 0.0:
		income_line += "  ·  unveil rush"
	_income.text = income_line
	var bits: PackedStringArray = []
	if GameState.has_any_pending_unveil():
		bits.append("A new find is waiting to be unveiled.")
	if GameState.featured_stand_id != "":
		bits.append("%s featured" % GameState.stand_title(GameState.featured_stand_id))
	if bits.is_empty():
		if GameState.has_piece("triceratops_skull"):
			var piece: Dictionary = GameState.pieces["triceratops_skull"]
			if bool(piece.get("clean", false)):
				_note.text = "A clean find is on display."
			else:
				_note.text = "A dusty find is on display. Visitors pay less."
		else:
			_note.text = "The hall is waiting. Bring something back from a dig."
	else:
		_note.text = "  ·  ".join(bits)
	if _canvas.has_method("queue_redraw"):
		_canvas.queue_redraw()
