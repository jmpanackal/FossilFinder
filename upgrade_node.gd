extends Control

signal pressed(id: String)
signal focused(id: String)

const Ui := preload("res://ui_style.gd")

var item_id: String = ""
var _short: String = ""
var _hovered: bool = false


func setup(id: String, short_name: String) -> void:
	item_id = id
	_short = short_name
	custom_minimum_size = Vector2(176, 78)
	size = Vector2(176, 78)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(func() -> void:
		_hovered = true
		focused.emit(item_id)
		queue_redraw()
	)
	mouse_exited.connect(func() -> void:
		_hovered = false
		queue_redraw()
	)
	refresh()


func refresh() -> void:
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit(item_id)
		accept_event()


func _draw() -> void:
	var item := _item()
	if item.is_empty():
		return
	var level: int = int(GameState.levels.get(item_id, 0))
	var max_level: int = int(item["max"])
	var maxed := level >= max_level
	var affordable := GameState.can_buy(item_id)
	var owned := level > 0
	var fill := Color("2A211A")
	var border := Color("6A523C")
	if maxed:
		fill = Color("3A2C18")
		border = Color("E4B75A")
	elif affordable:
		fill = Color("3A2A18")
		border = Color("E4B75A")
	elif owned:
		fill = Color("32281E")
		border = Color("A88858")
	if _hovered:
		border = border.lightened(0.18)
		fill = fill.lightened(0.08)
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, fill)
	draw_rect(rect, border, false, 2.0 if affordable or maxed or _hovered else 1.5)
	var font := get_theme_default_font()
	var title_color := Color("E4B75A") if affordable or maxed else (Ui.INK if owned else Ui.MUTED)
	draw_string(font, Vector2(10, 24), _short, HORIZONTAL_ALIGNMENT_LEFT, size.x - 20, 15, title_color)
	_draw_pips(level, max_level)
	var cost_text := "MAX" if maxed else "$%d" % GameState.cost_of(item_id)
	var cost_color := Color("7A6A58") if maxed else (Color("E4B75A") if affordable else Ui.MUTED)
	draw_string(font, Vector2(10, size.y - 10), cost_text, HORIZONTAL_ALIGNMENT_LEFT, size.x - 20, 14, cost_color)
	draw_string(font, Vector2(10, size.y - 10), "%d/%d" % [level, max_level], HORIZONTAL_ALIGNMENT_RIGHT, size.x - 20, 13, Ui.MUTED)


func _draw_pips(level: int, max_level: int) -> void:
	var pip := 8.0
	var gap := 2.0
	var start := Vector2(10, 36)
	for i in max_level:
		var x := start.x + float(i) * (pip + gap)
		if x + pip > size.x - 10:
			break
		var box := Rect2(x, start.y, pip, 8)
		draw_rect(box, Color("E4B75A") if i < level else Color("3F342A"))
		draw_rect(box, Color("6A523C"), false, 1.0)


func _item() -> Dictionary:
	for entry in GameState.catalog:
		if str(entry["id"]) == item_id:
			return entry
	return {}
