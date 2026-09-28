class_name FameBadge
extends Control

## Brass medal on the Finds tray: "MUSEUM FAME / finds x219". Every bone's
## price already includes it; this says why late finds pay so much.

const Ui := preload("res://ui_style.gd")

var mult: float = 1.0
var _pulse: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_mult(value: float) -> void:
	if absf(value - mult) < 0.05 and visible == (value >= 1.05):
		return
	if value > mult + 0.05:
		_pulse = 1.0
	mult = value
	visible = mult >= 1.05
	_resize()
	queue_redraw()


static func mult_text(value: float) -> String:
	if value >= 1000.0:
		return "x%.1fk" % (value / 1000.0)
	if value >= 10.0:
		return "x%d" % int(round(value))
	return "x%.1f" % value


func _resize() -> void:
	var font: Font = Ui.display_font()
	var big: float = font.get_string_size("finds " + mult_text(mult), HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	var small: float = font.get_string_size("MUSEUM FAME", HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	size = Vector2(maxf(big, small) + 44.0, 40.0)


func _process(delta: float) -> void:
	if _pulse > 0.0:
		_pulse = maxf(0.0, _pulse - delta * 1.5)
		queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var glow: float = _pulse
	draw_rect(rect.grow(2.0 + glow * 3.0), Color(Ui.GOLD, 0.15 + glow * 0.3), false, 3.0)
	draw_rect(rect, Color("2A1D12"))
	draw_rect(rect, Ui.GOLD, false, 2.0)
	## Star medal on the left.
	var c := Vector2(18.0, size.y * 0.5)
	draw_circle(c, 12.0, Color("5A3A1C"))
	draw_arc(c, 12.0, 0.0, TAU, 24, Ui.GOLD, 1.5)
	var pts := PackedVector2Array()
	for k in 10:
		var ang: float = -PI * 0.5 + float(k) * PI / 5.0
		var rad: float = 8.0 if k % 2 == 0 else 3.6
		pts.append(c + Vector2(cos(ang), sin(ang)) * rad)
	draw_colored_polygon(pts, Ui.GOLD)
	var font: Font = Ui.display_font()
	draw_string(font, Vector2(36.0, 15.0), "MUSEUM FAME", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Ui.MUTED)
	draw_string(font, Vector2(36.0, 33.0), "finds " + mult_text(mult), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Ui.GOLD)
