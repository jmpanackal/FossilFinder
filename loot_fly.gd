class_name LootFly
extends Node2D

## Cookie-style loot: the sprite is the item, then it arcs to the wallet.

const Matrix := preload("res://matrix_find.gd")
const ArtCatalogScript := preload("res://art_catalog.gd")
const FossilDataScript := preload("res://fossil_data.gd")

signal arrived

var _kind: String = "pebble"
var _rarity: int = 0
var _fossil: FossilDataScript
var _piece_id: String = ""
var _start := Vector2.ZERO
var _dest := Vector2.ZERO
var _age: float = 0.0
var _delay: float = 0.0
var _life: float = 0.52
var _sent: bool = false
## Fossil flights glow in their find's color and leave a trail, so the eye
## can follow a bone from the pit to its card.
var _glow := Color(0, 0, 0, 0)
var _trail: PackedVector2Array = PackedVector2Array()


func setup_fossil(data: Resource, start: Vector2, dest: Vector2, delay: float = 0.0, glow: Color = Color("FFE08A")) -> void:
	_fossil = data as FossilDataScript
	_glow = glow
	_life = 0.85
	_piece_id = ""
	if _fossil != null:
		_piece_id = _fossil.piece_id if _fossil.piece_id != "" else _fossil.name.to_snake_case()
	setup("fossil", start, dest, delay, 2)


func setup(kind: String, start: Vector2, dest: Vector2, delay: float = 0.0, rarity: int = 0) -> void:
	_kind = kind
	_rarity = rarity
	_start = start
	_dest = dest
	_delay = maxf(0.0, delay)
	_age = 0.0
	position = start
	z_index = 40


static func arc_point(start: Vector2, dest: Vector2, t: float) -> Vector2:
	var u: float = clampf(t, 0.0, 1.0)
	var lift: float = 56.0 + start.distance_to(dest) * 0.14
	var mid: Vector2 = start.lerp(dest, 0.45) + Vector2(0, -lift)
	var a: Vector2 = start.lerp(mid, u)
	var b: Vector2 = mid.lerp(dest, u)
	return a.lerp(b, u)


func _process(delta: float) -> void:
	_age += delta
	if _age < _delay:
		visible = false
		return
	visible = true
	var t: float = clampf((_age - _delay) / _life, 0.0, 1.0)
	var eased: float = 1.0 - (1.0 - t) * (1.0 - t)
	position = arc_point(_start, _dest, eased)
	var pop: float = 1.0 + sin(minf(t, 0.22) / 0.22 * PI) * 0.28
	scale = Vector2.ONE * lerpf(pop, 0.72, t)
	if _glow.a > 0.0:
		_trail.append(position)
		if _trail.size() > 10:
			_trail.remove_at(0)
	queue_redraw()
	if t < 1.0 or _sent:
		return
	_sent = true
	arrived.emit()
	queue_free()


func _draw() -> void:
	if _glow.a > 0.0:
		## Trail (drawn in local space) + halo in the find's color.
		for i in _trail.size():
			var a: float = float(i + 1) / float(_trail.size() + 1)
			draw_circle((_trail[i] - position) / maxf(scale.x, 0.01), 10.0 * a, Color(_glow, 0.35 * a))
		draw_circle(Vector2.ZERO, 28.0, Color(_glow, 0.28))
		draw_arc(Vector2.ZERO, 28.0, 0.0, TAU, 32, Color(_glow, 0.9), 3.0)
	if _fossil != null or _kind == "fossil":
		var dest := Rect2(-22, -16, 44, 32) if _glow.a > 0.0 else Rect2(-16, -12, 32, 24)
		if _piece_id != "" and ArtCatalogScript.draw_if_present(self, "bones", _piece_id, dest):
			return
		var color := Color("F7E9C6")
		if _fossil != null:
			_fossil.draw_silhouette(self, dest, color)
			return
		draw_rect(dest, color, false, 2.0)
		return
	Matrix.draw_icon(self, _kind, Vector2.ZERO, 8.5, 1.0, _rarity)
