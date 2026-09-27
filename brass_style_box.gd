class_name BrassStyleBox
extends StyleBox

const HIGHLIGHT := Color("E8C878")
const SHADE := Color("3A2410")
const OUTER := Color("6A523C")
const DROP := Color(0.05, 0.03, 0.02, 0.55)

@export var bg_color: Color = Color("2C2118")
@export var border_color: Color = OUTER
@export var highlight_color: Color = HIGHLIGHT
@export var shade_color: Color = SHADE
@export var inset: bool = false
@export var corner_radius: int = 6
@export var border_width: int = 2
@export var shadow_color: Color = DROP
@export var shadow_size: int = 10
@export var shadow_offset: Vector2 = Vector2(1, 3)


func set_border_width_all(width: int) -> void:
	border_width = width


func set_corner_radius_all(radius: int) -> void:
	corner_radius = radius


func is_brass() -> bool:
	return true


func is_outset() -> bool:
	return not inset


func is_inset() -> bool:
	return inset


func has_dual_border() -> bool:
	return true


func apply_hud_shadow() -> void:
	shadow_color = Color(0.05, 0.03, 0.02, 0.28)
	shadow_size = 3
	shadow_offset = Vector2(0, 1)


func clone_chrome():
	var copy = BrassStyleBox.new()
	copy.bg_color = bg_color
	copy.border_color = border_color
	copy.highlight_color = highlight_color
	copy.shade_color = shade_color
	copy.inset = inset
	copy.corner_radius = corner_radius
	copy.border_width = border_width
	copy.shadow_color = shadow_color
	copy.shadow_size = shadow_size
	copy.shadow_offset = shadow_offset
	copy.content_margin_left = content_margin_left
	copy.content_margin_right = content_margin_right
	copy.content_margin_top = content_margin_top
	copy.content_margin_bottom = content_margin_bottom
	return copy


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	if rect.size.x < 2.0 or rect.size.y < 2.0:
		return
	if shadow_size > 0 and not inset:
		var drop := _flat(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0)
		drop.shadow_color = shadow_color
		drop.shadow_size = shadow_size
		drop.shadow_offset = shadow_offset
		drop.draw(to_canvas_item, rect)
	var body := _flat(bg_color, border_color, border_width)
	body.draw(to_canvas_item, rect)
	var inner := rect.grow(-float(maxi(border_width, 1)))
	if inner.size.x < 4.0 or inner.size.y < 4.0:
		return
	var ring := _flat(Color(0, 0, 0, 0), _ring_color(), 1)
	ring.draw_center = false
	ring.draw(to_canvas_item, inner)
	var hi := _flat(Color(0, 0, 0, 0), _hi_color(), 0)
	hi.draw_center = false
	hi.border_width_top = 1
	hi.border_width_left = 1
	hi.draw(to_canvas_item, inner)
	var lo := _flat(Color(0, 0, 0, 0), _lo_color(), 0)
	lo.draw_center = false
	lo.border_width_bottom = 1
	lo.border_width_right = 1
	lo.draw(to_canvas_item, inner)


func _ring_color() -> Color:
	return highlight_color.darkened(0.15) if not inset else shade_color.lightened(0.12)


func _hi_color() -> Color:
	return shade_color if inset else highlight_color


func _lo_color() -> Color:
	return highlight_color if inset else shade_color


func _flat(fill: Color, border: Color, width: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(corner_radius)
	return box
