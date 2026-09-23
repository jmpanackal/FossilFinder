extends Control

var filled: int = 0
var total: int = 5


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(168, 30)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER


func set_rating(count: int, out_of: int = 5) -> void:
	filled = clampi(count, 0, out_of)
	total = maxi(out_of, 1)
	queue_redraw()


func _draw() -> void:
	var star_size := 22.0
	var gap := 8.0
	var row := float(total) * star_size + float(total - 1) * gap
	var start := Vector2((size.x - row) * 0.5 + star_size * 0.5, size.y * 0.5)
	for i in total:
		var center := start + Vector2(float(i) * (star_size + gap), 0.0)
		_draw_star(center, star_size * 0.5, i < filled)


func _draw_star(center: Vector2, radius: float, on: bool) -> void:
	var points := PackedVector2Array()
	for i in 10:
		var angle := -PI * 0.5 + float(i) * PI / 5.0
		var reach := radius if i % 2 == 0 else radius * 0.42
		points.append(center + Vector2.from_angle(angle) * reach)
	if on:
		draw_colored_polygon(points, Color("E4B75A"))
	var outline := PackedVector2Array(points)
	outline.append(points[0])
	draw_polyline(outline, Color("E4B75A") if on else Color("8A7358"), 1.6, true)
