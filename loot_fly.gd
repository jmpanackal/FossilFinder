class_name LootFly
extends Node2D

## Cookie-style loot: the sprite is the item, then it arcs to the wallet.

const Matrix := preload("res://matrix_find.gd")

signal arrived

var _kind: String = "pebble"
var _rarity: int = 0
var _start := Vector2.ZERO
var _dest := Vector2.ZERO
var _age: float = 0.0
var _delay: float = 0.0
var _life: float = 0.52
var _sent: bool = false


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
	queue_redraw()
	if t < 1.0 or _sent:
		return
	_sent = true
	arrived.emit()
	queue_free()


func _draw() -> void:
	Matrix.draw_icon(self, _kind, Vector2.ZERO, 8.5, 1.0, _rarity)
