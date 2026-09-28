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
	## Longer lines (e.g. "Great condition!") center on the spot and stay on screen.
	var width: float = label.get_combined_minimum_size().x
	if width > 60.0:
		label.position.x = -width * 0.5
	_keep_on_screen(label, width)


func _keep_on_screen(label: Label, width: float) -> void:
	var left: float = position.x + label.position.x
	var right: float = left + width
	var view_w: float = Tuning.view_w
	if right > view_w - 8.0:
		label.position.x -= right - (view_w - 8.0)
	elif left < 8.0:
		label.position.x += 8.0 - left


func _process(delta: float) -> void:
	position.y -= 64.0 * delta
	_life -= delta
	modulate.a = clampf(_life / 0.9, 0.0, 1.0)
	if _life <= 0.0:
		queue_free()
