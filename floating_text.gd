class_name FloatingText
extends Node2D

const Ui := preload("res://ui_style.gd")

var _life := 0.9


func setup(text: String, color: Color, font_size: int = 22) -> void:
	var label := Label.new()
	label.text = text
	label.position = Vector2(-10, -8)
	Ui.apply_label(label, font_size, color)
	add_child(label)


func _process(delta: float) -> void:
	position.y -= 64.0 * delta
	_life -= delta
	modulate.a = clampf(_life / 0.9, 0.0, 1.0)
	if _life <= 0.0:
		queue_free()
