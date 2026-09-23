extends Control

var tool_id: int = 0
var accent := Color("E4B75A")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup(id: int, color: Color) -> void:
	tool_id = id
	accent = color
	queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	match tool_id:
		1:
			_draw_pick(c)
		2:
			_draw_brush(c)
		3:
			_draw_hands(c)
		_:
			_draw_shovel(c)


func _draw_hands(c: Vector2) -> void:
	draw_circle(c + Vector2(0, 4), 8.5, accent)
	draw_line(c + Vector2(-8, 2), c + Vector2(-8, -11), accent, 2.6)
	draw_line(c + Vector2(-3, 0), c + Vector2(-3, -14), accent, 2.6)
	draw_line(c + Vector2(2, 0), c + Vector2(2, -13), accent, 2.6)
	draw_line(c + Vector2(7, 2), c + Vector2(7, -10), accent, 2.6)


func _draw_shovel(c: Vector2) -> void:
	draw_line(c + Vector2(-10, 14), c + Vector2(8, -10), accent, 4.0)
	var scoop := PackedVector2Array([
		c + Vector2(4, -16),
		c + Vector2(16, -8),
		c + Vector2(12, 4),
		c + Vector2(0, -4),
	])
	draw_colored_polygon(scoop, accent)


func _draw_pick(c: Vector2) -> void:
	draw_line(c + Vector2(-4, 14), c + Vector2(6, -6), accent, 4.0)
	draw_line(c + Vector2(-14, -8), c + Vector2(16, 2), accent, 5.0)
	draw_circle(c + Vector2(6, -6), 3.0, accent)


func _draw_brush(c: Vector2) -> void:
	draw_line(c + Vector2(-8, 14), c + Vector2(4, -2), accent, 4.0)
	draw_line(c + Vector2(4, -2), c + Vector2(-2, -12), accent.lightened(0.15), 2.2)
	draw_line(c + Vector2(4, -2), c + Vector2(6, -14), accent.lightened(0.15), 2.2)
	draw_line(c + Vector2(4, -2), c + Vector2(12, -10), accent.lightened(0.15), 2.2)
	draw_circle(c + Vector2(4, -2), 3.2, accent)
