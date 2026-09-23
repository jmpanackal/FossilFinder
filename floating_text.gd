class_name FloatingText
extends Node2D

var _life := 0.7


func setup(text: String, color: Color, font_size: int = 16) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	label.position = Vector2(-10, -8)
	add_child(label)


func _process(delta: float) -> void:
	position.y -= 48.0 * delta
	_life -= delta
	modulate.a = clampf(_life / 0.7, 0.0, 1.0)
	if _life <= 0.0:
		queue_free()
