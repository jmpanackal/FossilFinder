extends Control

var time_left: float = 60.0
var time_max: float = 60.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(72, 72)


func set_time(left: float, maximum: float) -> void:
	time_left = maxf(left, 0.0)
	time_max = maxf(maximum, 0.01)
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.46
	var spent := 1.0 - clampf(time_left / time_max, 0.0, 1.0)
	var urgent := time_left <= 10.0
	var fill := Color("E24B4B") if urgent else Color("E4B75A")
	draw_circle(center, radius, Color("1B1410"))
	draw_arc(center, radius, 0.0, TAU, 48, Color("6A523C"), 4.0)
	if spent > 0.001:
		_draw_pie(center, radius - 5.0, -PI * 0.5, spent * TAU, Color(fill, 0.88))
	draw_arc(center, radius, 0.0, TAU, 48, fill if urgent else Color("C9B8A2"), 2.0)
	for i in 12:
		var angle := -PI * 0.5 + float(i) * TAU / 12.0
		var inner := radius - (8.0 if i % 3 == 0 else 5.0)
		draw_line(center + Vector2.from_angle(angle) * inner, center + Vector2.from_angle(angle) * (radius - 2.0), Color("C9B8A2"), 1.5)
	var hand := -PI * 0.5 + spent * TAU
	draw_line(center, center + Vector2.from_angle(hand) * (radius - 10.0), fill, 2.5)
	draw_circle(center, 3.0, fill)


func _draw_pie(center: Vector2, radius: float, start: float, sweep: float, color: Color) -> void:
	var points := PackedVector2Array()
	points.append(center)
	var steps := maxi(8, int(sweep / 0.12))
	for i in range(steps + 1):
		var angle := start + sweep * float(i) / float(steps)
		points.append(center + Vector2.from_angle(angle) * radius)
	if points.size() >= 3:
		draw_colored_polygon(points, color)
