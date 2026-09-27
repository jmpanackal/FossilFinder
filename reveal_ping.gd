extends Node2D

var _age := 0.0
var _max_age := 0.58


func _process(delta: float) -> void:
	_age += delta
	queue_redraw()
	if _age >= _max_age:
		queue_free()


func _draw() -> void:
	var t := _age / _max_age
	var radius := lerpf(12.0, 72.0, t)
	var alpha := 1.0 - t
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 36, Color(1, 0.92, 0.7, alpha), 5.0)
	draw_arc(Vector2.ZERO, radius * 0.62, 0.0, TAU, 28, Color(1, 0.96, 0.8, alpha * 0.55), 2.5)
