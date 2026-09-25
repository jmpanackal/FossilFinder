class_name FossilData
extends Resource

@export var name: String = "Fossil"
@export var piece_id: String = ""
@export var stand_id: String = ""
@export var mount_region: String = ""
@export var shape_width: int = 4
@export var shape: PackedInt32Array = PackedInt32Array()
@export var min_layer: int = 6
@export var max_layer: int = 14
@export var base_value: int = 100
@export var min_rank: int = 0
@export var needs_rich_bed: bool = false
@export var set_need: int = 1


func cell_offsets() -> Array[Vector2i]:
	var offsets: Array[Vector2i] = []
	if shape_width <= 0:
		return offsets
	for i in shape.size():
		if shape[i] != 0:
			var x: int = i % shape_width
			var y: int = int(float(i) / float(shape_width))
			offsets.append(Vector2i(x, y))
	return offsets


func occupied_cells() -> int:
	return cell_offsets().size()


func bounding_size() -> Vector2i:
	var max_x: int = 0
	var max_y: int = 0
	var any: bool = false
	for offset in cell_offsets():
		any = true
		max_x = maxi(max_x, offset.x)
		max_y = maxi(max_y, offset.y)
	if not any:
		return Vector2i.ZERO
	return Vector2i(max_x + 1, max_y + 1)


func is_skull() -> bool:
	var id: String = piece_id.to_lower()
	if id == "skull" or id.ends_with("_skull"):
		return true
	return name.to_lower().contains("skull")


func silhouette_kind() -> String:
	var id: String = piece_id.to_lower()
	if id.is_empty():
		id = name.to_snake_case()
	match id:
		"t_rex_tooth":
			return "tooth_rex"
		"triceratops_tooth":
			return "tooth_trike"
		"brachiosaurus_tooth":
			return "tooth_brach"
		"stegosaurus_foot":
			return "foot"
		"velociraptor_claw":
			return "claw"
		"stegosaurus_plate":
			return "plate"
		"t_rex_femur", "stegosaurus_femur", "velociraptor_femur", "brachiosaurus_femur", "brachiosaurus_humerus", "triceratops_hind_limb":
			return "long_bone"
		"t_rex_skull":
			return "skull_rex"
		"triceratops_skull":
			return "skull_trike"
		"stegosaurus_skull":
			return "skull_stego"
		"velociraptor_skull":
			return "skull_raptor"
		"brachiosaurus_skull":
			return "skull_brach"
		"t_rex_jaw":
			return "jaw"
		"t_rex_ribcage", "velociraptor_ribs":
			return "ribs"
		"stegosaurus_thagomizer":
			return "thagomizer"
		"brachiosaurus_neck":
			return "neck"
		"t_rex_tail", "triceratops_tail", "velociraptor_tail", "brachiosaurus_tail":
			return "tail"
		"triceratops_nose_horn":
			return "horn_spike"
		"triceratops_brow_horns":
			return "horn_v"
		"triceratops_vertebra", "vertebra":
			return "vertebra"
		"stegosaurus_torso":
			return "torso"
		"trilobite":
			return "trilobite"
		"amber_insect":
			return "amber"
		"tooth":
			return "tooth_rex"
		_:
			if id.ends_with("_tooth"):
				return "tooth_rex"
			if id.ends_with("_femur") or id.ends_with("_humerus") or id.ends_with("_limb"):
				return "long_bone"
			if id.ends_with("_tail"):
				return "tail"
			if id.ends_with("_skull"):
				return "skull_rex"
			return "long_bone"


func silhouette_polys(rect: Rect2) -> Array[PackedVector2Array]:
	var polys: Array[PackedVector2Array] = []
	match silhouette_kind():
		"tooth_rex":
			polys.append(_map_poly(rect, PackedVector2Array([
				Vector2(0.08, 0.16), Vector2(0.92, 0.16), Vector2(0.50, 0.92)
			])))
		"tooth_trike":
			polys.append(_map_poly(rect, PackedVector2Array([
				Vector2(0.50, 0.08), Vector2(0.78, 0.32), Vector2(0.62, 0.90),
				Vector2(0.38, 0.90), Vector2(0.22, 0.32)
			])))
		"tooth_brach":
			polys.append(_map_poly(rect, PackedVector2Array([
				Vector2(0.38, 0.08), Vector2(0.62, 0.08), Vector2(0.66, 0.92), Vector2(0.34, 0.92)
			])))
		"foot":
			polys.append(_map_poly(rect, PackedVector2Array([
				Vector2(0.30, 0.10), Vector2(0.70, 0.10), Vector2(0.74, 0.58), Vector2(0.26, 0.58)
			])))
			polys.append(_map_poly(rect, PackedVector2Array([
				Vector2(0.16, 0.56), Vector2(0.36, 0.56), Vector2(0.34, 0.90), Vector2(0.14, 0.86)
			])))
			polys.append(_map_poly(rect, PackedVector2Array([
				Vector2(0.40, 0.56), Vector2(0.60, 0.56), Vector2(0.60, 0.92), Vector2(0.40, 0.92)
			])))
			polys.append(_map_poly(rect, PackedVector2Array([
				Vector2(0.64, 0.56), Vector2(0.84, 0.56), Vector2(0.86, 0.86), Vector2(0.66, 0.90)
			])))
		"claw":
			polys.append(_map_poly(rect, PackedVector2Array([
				Vector2(0.74, 0.10), Vector2(0.94, 0.20), Vector2(0.90, 0.46), Vector2(0.66, 0.76),
				Vector2(0.30, 0.96), Vector2(0.18, 0.82), Vector2(0.48, 0.64), Vector2(0.70, 0.32)
			])))
		"plate":
			polys.append(_map_poly(rect, PackedVector2Array([
				Vector2(0.50, 0.06), Vector2(0.88, 0.50), Vector2(0.50, 0.94), Vector2(0.12, 0.50)
			])))
		"long_bone":
			polys.append(_map_poly(rect, PackedVector2Array([
				Vector2(0.18, 0.40), Vector2(0.82, 0.40), Vector2(0.82, 0.60), Vector2(0.18, 0.60)
			])))
			polys.append(_map_poly(rect, PackedVector2Array([
				Vector2(0.04, 0.26), Vector2(0.26, 0.26), Vector2(0.26, 0.46), Vector2(0.04, 0.46)
			])))
			polys.append(_map_poly(rect, PackedVector2Array([
				Vector2(0.04, 0.54), Vector2(0.26, 0.54), Vector2(0.26, 0.74), Vector2(0.04, 0.74)
			])))
			polys.append(_map_poly(rect, PackedVector2Array([
				Vector2(0.74, 0.26), Vector2(0.96, 0.26), Vector2(0.96, 0.46), Vector2(0.74, 0.46)
			])))
			polys.append(_map_poly(rect, PackedVector2Array([
				Vector2(0.74, 0.54), Vector2(0.96, 0.54), Vector2(0.96, 0.74), Vector2(0.74, 0.74)
			])))
		"skull_rex":
			polys.append(_map_poly(rect, PackedVector2Array([
				Vector2(0.86, 0.22), Vector2(0.94, 0.38), Vector2(0.94, 0.62), Vector2(0.86, 0.78),
				Vector2(0.36, 0.72), Vector2(0.06, 0.58), Vector2(0.06, 0.42), Vector2(0.36, 0.28)
			])))
		"skull_trike":
			polys.append(_map_poly(rect, PackedVector2Array([
				Vector2(0.08, 0.22), Vector2(0.28, 0.08), Vector2(0.50, 0.04), Vector2(0.72, 0.08),
				Vector2(0.92, 0.22), Vector2(0.88, 0.48), Vector2(0.70, 0.56), Vector2(0.78, 0.78),
				Vector2(0.50, 0.90), Vector2(0.22, 0.78), Vector2(0.30, 0.56), Vector2(0.12, 0.48)
			])))
		"skull_stego":
			polys.append(_map_poly(rect, PackedVector2Array([
				Vector2(0.18, 0.38), Vector2(0.82, 0.20), Vector2(0.90, 0.52), Vector2(0.22, 0.74)
			])))
		"skull_raptor":
			polys.append(_map_poly(rect, PackedVector2Array([
				Vector2(0.10, 0.44), Vector2(0.68, 0.18), Vector2(0.90, 0.36), Vector2(0.78, 0.58), Vector2(0.18, 0.70)
			])))
		"skull_brach":
			polys.append(_map_poly(rect, PackedVector2Array([
				Vector2(0.16, 0.40), Vector2(0.60, 0.16), Vector2(0.88, 0.30), Vector2(0.82, 0.58), Vector2(0.26, 0.72)
			])))
		"jaw":
			polys.append(_map_poly(rect, PackedVector2Array([
				Vector2(0.08, 0.32), Vector2(0.36, 0.16), Vector2(0.70, 0.18), Vector2(0.90, 0.38),
				Vector2(0.82, 0.54), Vector2(0.52, 0.42), Vector2(0.24, 0.58), Vector2(0.08, 0.48)
			])))
		"ribs":
			polys.append(_map_poly(rect, PackedVector2Array([
				Vector2(0.78, 0.10), Vector2(0.28, 0.16), Vector2(0.12, 0.50), Vector2(0.28, 0.84),
				Vector2(0.78, 0.90), Vector2(0.72, 0.70), Vector2(0.36, 0.50), Vector2(0.72, 0.30)
			])))
		"thagomizer":
			polys.append(_map_poly(rect, PackedVector2Array([
				Vector2(0.08, 0.42), Vector2(0.58, 0.42), Vector2(0.58, 0.58), Vector2(0.08, 0.58)
			])))
			polys.append(_map_poly(rect, PackedVector2Array([
				Vector2(0.50, 0.10), Vector2(0.68, 0.10), Vector2(0.92, 0.36), Vector2(0.68, 0.46)
			])))
			polys.append(_map_poly(rect, PackedVector2Array([
				Vector2(0.50, 0.90), Vector2(0.68, 0.54), Vector2(0.92, 0.64), Vector2(0.68, 0.90)
			])))
		"neck":
			polys.append(_map_poly(rect, PackedVector2Array([
				Vector2(0.06, 0.38), Vector2(0.28, 0.20), Vector2(0.52, 0.28), Vector2(0.72, 0.16),
				Vector2(0.94, 0.30), Vector2(0.94, 0.50), Vector2(0.74, 0.38), Vector2(0.54, 0.50),
				Vector2(0.30, 0.42), Vector2(0.10, 0.58), Vector2(0.06, 0.48)
			])))
		"tail":
			polys.append(_map_poly(rect, PackedVector2Array([
				Vector2(0.06, 0.28), Vector2(0.62, 0.36), Vector2(0.94, 0.46),
				Vector2(0.94, 0.54), Vector2(0.62, 0.64), Vector2(0.06, 0.72)
			])))
		"horn_spike":
			polys.append(_map_poly(rect, PackedVector2Array([
				Vector2(0.42, 0.06), Vector2(0.58, 0.06), Vector2(0.70, 0.92), Vector2(0.30, 0.92)
			])))
		"horn_v":
			polys.append(_map_poly(rect, PackedVector2Array([
				Vector2(0.10, 0.08), Vector2(0.28, 0.08), Vector2(0.48, 0.90), Vector2(0.26, 0.90)
			])))
			polys.append(_map_poly(rect, PackedVector2Array([
				Vector2(0.72, 0.08), Vector2(0.90, 0.08), Vector2(0.74, 0.90), Vector2(0.52, 0.90)
			])))
		"vertebra":
			polys.append(_map_poly(rect, PackedVector2Array([
				Vector2(0.36, 0.32), Vector2(0.64, 0.32), Vector2(0.64, 0.68), Vector2(0.36, 0.68)
			])))
			polys.append(_map_poly(rect, PackedVector2Array([
				Vector2(0.06, 0.38), Vector2(0.36, 0.42), Vector2(0.36, 0.58), Vector2(0.06, 0.62)
			])))
			polys.append(_map_poly(rect, PackedVector2Array([
				Vector2(0.64, 0.42), Vector2(0.94, 0.38), Vector2(0.94, 0.62), Vector2(0.64, 0.58)
			])))
		"torso":
			polys.append(_map_poly(rect, PackedVector2Array([
				Vector2(0.18, 0.28), Vector2(0.50, 0.12), Vector2(0.82, 0.28),
				Vector2(0.88, 0.72), Vector2(0.50, 0.88), Vector2(0.12, 0.72)
			])))
		"trilobite":
			polys.append(_map_poly(rect, PackedVector2Array([
				Vector2(0.50, 0.08), Vector2(0.78, 0.22), Vector2(0.88, 0.50), Vector2(0.72, 0.78),
				Vector2(0.50, 0.92), Vector2(0.28, 0.78), Vector2(0.12, 0.50), Vector2(0.22, 0.22)
			])))
		"amber":
			polys.append(_map_poly(rect, PackedVector2Array([
				Vector2(0.50, 0.08), Vector2(0.86, 0.32), Vector2(0.78, 0.88), Vector2(0.22, 0.88), Vector2(0.14, 0.32)
			])))
			polys.append(_map_poly(rect, PackedVector2Array([
				Vector2(0.40, 0.36), Vector2(0.60, 0.36), Vector2(0.62, 0.64), Vector2(0.38, 0.64)
			])))
		_:
			polys.append(_map_poly(rect, PackedVector2Array([
				Vector2(0.20, 0.30), Vector2(0.80, 0.30), Vector2(0.80, 0.70), Vector2(0.20, 0.70)
			])))
	return polys


func draw_silhouette(item: CanvasItem, rect: Rect2, color: Color) -> void:
	if item == null or rect.size.x < 2.0 or rect.size.y < 2.0:
		return
	for poly in silhouette_polys(rect):
		if poly.size() < 3:
			continue
		item.draw_colored_polygon(poly, color)
		var line: Color = color.darkened(0.28)
		for i in poly.size():
			item.draw_line(poly[i], poly[(i + 1) % poly.size()], line, 1.6, true)


func _map_poly(rect: Rect2, norms: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in norms:
		out.append(Vector2(rect.position.x + p.x * rect.size.x, rect.position.y + p.y * rect.size.y))
	return out
