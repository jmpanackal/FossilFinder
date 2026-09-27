extends Control

const ArtCatalogScript := preload("res://art_catalog.gd")
const Ui := preload("res://ui_style.gd")

var tool_id: int = 0
var accent := Color("E4B75A")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = TEXTURE_FILTER_NEAREST
	resized.connect(queue_redraw)


static func apply_box(mark: Control) -> void:
	Ui.apply_tool_icon(mark)


func setup(id: int, color: Color) -> void:
	tool_id = id
	accent = color
	queue_redraw()


func _draw() -> void:
	if ArtCatalogScript.draw_if_present(self, "tools", ArtCatalogScript.tool_id_for(tool_id), Rect2(Vector2.ZERO, size)):
		return
	if size.x < 2.0 or size.y < 2.0:
		return
	var c := size * 0.5
	var k: float = minf(size.x, size.y) / 36.0
	match tool_id:
		1:
			_draw_pick(c, k)
		2:
			_draw_brush(c, k)
		3:
			_draw_hands(c, k)
		_:
			_draw_shovel(c, k)


func _draw_hands(c: Vector2, k: float) -> void:
	draw_circle(c + Vector2(0, 4) * k, 8.5 * k, accent)
	draw_line(c + Vector2(-8, 2) * k, c + Vector2(-8, -11) * k, accent, 2.6 * k)
	draw_line(c + Vector2(-3, 0) * k, c + Vector2(-3, -14) * k, accent, 2.6 * k)
	draw_line(c + Vector2(2, 0) * k, c + Vector2(2, -13) * k, accent, 2.6 * k)
	draw_line(c + Vector2(7, 2) * k, c + Vector2(7, -10) * k, accent, 2.6 * k)


func _draw_shovel(c: Vector2, k: float) -> void:
	draw_line(c + Vector2(-10, 14) * k, c + Vector2(8, -10) * k, accent, 4.0 * k)
	var scoop := PackedVector2Array([
		c + Vector2(4, -16) * k,
		c + Vector2(16, -8) * k,
		c + Vector2(12, 4) * k,
		c + Vector2(0, -4) * k,
	])
	draw_colored_polygon(scoop, accent)


func _draw_pick(c: Vector2, k: float) -> void:
	draw_line(c + Vector2(-4, 14) * k, c + Vector2(6, -6) * k, accent, 4.0 * k)
	draw_line(c + Vector2(-14, -8) * k, c + Vector2(16, 2) * k, accent, 5.0 * k)
	draw_circle(c + Vector2(6, -6) * k, 3.0 * k, accent)


func _draw_brush(c: Vector2, k: float) -> void:
	draw_line(c + Vector2(-8, 14) * k, c + Vector2(4, -2) * k, accent, 4.0 * k)
	draw_line(c + Vector2(4, -2) * k, c + Vector2(-2, -12) * k, accent.lightened(0.15), 2.2 * k)
	draw_line(c + Vector2(4, -2) * k, c + Vector2(6, -14) * k, accent.lightened(0.15), 2.2 * k)
	draw_line(c + Vector2(4, -2) * k, c + Vector2(12, -10) * k, accent.lightened(0.15), 2.2 * k)
	draw_circle(c + Vector2(4, -2) * k, 3.2 * k, accent)
