extends Node2D

var _age := 0.0
var _max_age := 0.45


func _process(delta: float) -> void:
	_age += delta
	queue_redraw()
	if _age >= _max_age:
		queue_free()


func _draw() -> void:
	var t := _age / _max_age
	var radius := lerpf(8.0, 46.0, t)
	var alpha := 1.0 - t
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(1, 0.92, 0.7, alpha), 3.0)
