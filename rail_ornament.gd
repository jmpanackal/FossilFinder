extends Control

## Decoration drawn over a rail's plain box (Tools, Finds): a soft top sheen, a
## fine inner brass line, corner brackets, and a brass rule with a small diamond
## under the title. The box itself stays a plain StyleBoxFlat.

const BRASS := Color("E4B75A")
const BRASS_DIM := Color("8A6A38")
const SHEEN := Color(1.0, 0.92, 0.75)

## Local y of the rule under the title (0 = no rule).
var header_y: float = 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func set_header_y(y: float) -> void:
	if is_equal_approx(header_y, y):
		return
	header_y = y
	queue_redraw()


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	if w < 24.0 or h < 24.0:
		return
	## Light from above: a faint sheen at the top, a faint shade at the bottom.
	var top_h: float = minf(h * 0.32, 110.0)
	draw_polygon(
		PackedVector2Array([Vector2(3, 3), Vector2(w - 3, 3), Vector2(w - 3, top_h), Vector2(3, top_h)]),
		PackedColorArray([Color(SHEEN, 0.08), Color(SHEEN, 0.08), Color(SHEEN, 0.0), Color(SHEEN, 0.0)])
	)
	var low_h: float = minf(h * 0.28, 90.0)
	draw_polygon(
		PackedVector2Array([Vector2(3, h - low_h), Vector2(w - 3, h - low_h), Vector2(w - 3, h - 3), Vector2(3, h - 3)]),
		PackedColorArray([Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.20), Color(0, 0, 0, 0.20)])
	)
	## A fine brass line just inside the border.
	draw_rect(Rect2(4, 4, w - 8, h - 8), Color(BRASS_DIM, 0.55), false, 1.0)
	## Corner brackets.
	var arm: float = 12.0
	var inset: float = 3.0
	var bracket := Color(BRASS, 0.9)
	for corner in 4:
		var x: float = inset if corner % 2 == 0 else w - inset
		var y: float = inset if corner < 2 else h - inset
		var dx: float = arm if corner % 2 == 0 else -arm
		var dy: float = arm if corner < 2 else -arm
		draw_line(Vector2(x, y), Vector2(x + dx, y), bracket, 2.0)
		draw_line(Vector2(x, y), Vector2(x, y + dy), bracket, 2.0)
	## The title rule: a line either side of a small diamond.
	if header_y > 0.0:
		var cx: float = w * 0.5
		var line := Color(BRASS_DIM, 0.95)
		draw_line(Vector2(18, header_y), Vector2(cx - 9, header_y), line, 1.5)
		draw_line(Vector2(cx + 9, header_y), Vector2(w - 18, header_y), line, 1.5)
		draw_colored_polygon(
			PackedVector2Array([Vector2(cx, header_y - 4.5), Vector2(cx + 5.5, header_y), Vector2(cx, header_y + 4.5), Vector2(cx - 5.5, header_y)]),
			BRASS
		)
