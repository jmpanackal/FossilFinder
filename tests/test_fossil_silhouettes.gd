extends SceneTree

## Occupied cells plus inset doodles must read as the part in the pit.
## Run: godot --headless --path <project> -s res://tests/test_fossil_silhouettes.gd

var _failed: int = 0
var _passed: int = 0

const KINDS := {
	"t_rex_tooth": "tooth_rex",
	"triceratops_tooth": "tooth_trike",
	"brachiosaurus_tooth": "tooth_brach",
	"stegosaurus_foot": "foot",
	"velociraptor_claw": "claw",
	"stegosaurus_plate": "plate",
	"t_rex_femur": "long_bone",
	"stegosaurus_femur": "long_bone",
	"velociraptor_femur": "long_bone",
	"brachiosaurus_femur": "long_bone",
	"brachiosaurus_humerus": "long_bone",
	"triceratops_hind_limb": "long_bone",
	"t_rex_skull": "skull_rex",
	"triceratops_skull": "skull_trike",
	"stegosaurus_skull": "skull_stego",
	"velociraptor_skull": "skull_raptor",
	"brachiosaurus_skull": "skull_brach",
	"t_rex_jaw": "jaw",
	"t_rex_ribcage": "ribs",
	"velociraptor_ribs": "ribs",
	"stegosaurus_thagomizer": "thagomizer",
	"brachiosaurus_neck": "neck",
	"t_rex_tail": "tail",
	"triceratops_tail": "tail",
	"velociraptor_tail": "tail",
	"brachiosaurus_tail": "tail",
	"triceratops_nose_horn": "horn_spike",
	"triceratops_brow_horns": "horn_v",
	"triceratops_vertebra": "vertebra",
	"stegosaurus_torso": "torso",
	"trilobite": "trilobite",
	"amber_insect": "amber",
}

const CELLS := {
	"t_rex_tooth": 1,
	"triceratops_tooth": 1,
	"brachiosaurus_tooth": 1,
	"stegosaurus_foot": 1,
	"velociraptor_claw": 1,
	"stegosaurus_plate": 2,
	"t_rex_femur": 4,
	"stegosaurus_femur": 3,
	"velociraptor_femur": 2,
	"brachiosaurus_femur": 6,
	"brachiosaurus_humerus": 5,
	"triceratops_hind_limb": 3,
	"t_rex_skull": 8,
	"triceratops_skull": 8,
	"stegosaurus_skull": 3,
	"velociraptor_skull": 2,
	"brachiosaurus_skull": 3,
	"t_rex_jaw": 4,
	"t_rex_ribcage": 5,
	"velociraptor_ribs": 3,
	"stegosaurus_thagomizer": 4,
	"brachiosaurus_neck": 10,
	"t_rex_tail": 3,
	"triceratops_tail": 3,
	"velociraptor_tail": 3,
	"brachiosaurus_tail": 4,
	"triceratops_nose_horn": 2,
	"triceratops_brow_horns": 3,
	"triceratops_vertebra": 3,
	"stegosaurus_torso": 5,
	"trilobite": 1,
	"amber_insect": 1,
}

const QUOTAS := {
	"t_rex_tooth": 6,
	"triceratops_tooth": 5,
	"stegosaurus_foot": 4,
	"stegosaurus_plate": 3,
	"velociraptor_claw": 2,
	"brachiosaurus_tooth": 5,
}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_every_part_has_a_readable_kind()
	_test_teeth_and_bugs_are_not_the_same_wedge()
	_test_occupancy_reads_as_the_part()
	_test_doodles_use_the_right_geometry()
	_test_pit_draws_the_part_doodle()
	_test_cell_counts_and_quotas_hold()
	print("fossil_silhouettes %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _load_id(piece_id: String) -> Resource:
	return load("res://%s.tres" % piece_id)


func _test_every_part_has_a_readable_kind() -> void:
	for piece_id in KINDS:
		var data: Resource = _load_id(str(piece_id))
		_assert(data != null, "%s resource exists" % str(piece_id))
		if data == null:
			continue
		_assert(data.has_method("silhouette_kind"), "%s exposes silhouette_kind" % str(piece_id))
		if not data.has_method("silhouette_kind"):
			continue
		_assert(
			str(data.call("silhouette_kind")) == str(KINDS[piece_id]),
			"%s reads as %s" % [str(piece_id), str(KINDS[piece_id])]
		)


func _test_teeth_and_bugs_are_not_the_same_wedge() -> void:
	var rex: Resource = _load_id("t_rex_tooth")
	var trike: Resource = _load_id("triceratops_tooth")
	var brach: Resource = _load_id("brachiosaurus_tooth")
	var bug: Resource = _load_id("trilobite")
	var amber: Resource = _load_id("amber_insect")
	if rex == null or trike == null or brach == null or bug == null or amber == null:
		_assert(false, "starter scraps and teeth load")
		return
	if not rex.has_method("silhouette_kind"):
		_assert(false, "FossilData exposes silhouette_kind")
		return
	var kinds: PackedStringArray = PackedStringArray([
		str(rex.call("silhouette_kind")),
		str(trike.call("silhouette_kind")),
		str(brach.call("silhouette_kind")),
		str(bug.call("silhouette_kind")),
		str(amber.call("silhouette_kind")),
	])
	_assert(kinds[0] != kinds[1], "rex tooth is not the trike leaf")
	_assert(kinds[0] != kinds[2], "rex tooth is not the brach peg")
	_assert(kinds[1] != kinds[2], "trike leaf is not the brach peg")
	_assert(kinds[3] != kinds[0], "trilobite is not a tooth")
	_assert(kinds[4] != kinds[0], "amber is not a tooth")
	_assert(kinds[3] != kinds[4], "trilobite is not amber")


func _test_occupancy_reads_as_the_part() -> void:
	var masks := {
		"triceratops_vertebra": {"width": 3, "shape": PackedInt32Array([0, 1, 0, 1, 0, 1])},
		"t_rex_tail": {"width": 2, "shape": PackedInt32Array([1, 1, 0, 1])},
		"triceratops_tail": {"width": 3, "shape": PackedInt32Array([1, 1, 0, 0, 1, 0])},
		"velociraptor_tail": {"width": 2, "shape": PackedInt32Array([1, 0, 1, 1])},
		"brachiosaurus_tail": {"width": 3, "shape": PackedInt32Array([1, 1, 0, 0, 1, 0, 0, 1, 0])},
		"t_rex_femur": {"width": 3, "shape": PackedInt32Array([1, 0, 1, 0, 1, 0, 0, 1, 0])},
		"stegosaurus_femur": {"width": 3, "shape": PackedInt32Array([1, 0, 1, 0, 1, 0])},
	}
	for piece_id in masks:
		var data: Resource = _load_id(str(piece_id))
		_assert(data != null, "%s occupancy resource exists" % str(piece_id))
		if data == null:
			continue
		var spec: Dictionary = masks[piece_id]
		_assert(int(data.get("shape_width")) == int(spec["width"]), "%s uses width %d" % [str(piece_id), int(spec["width"])])
		_assert(data.get("shape") == spec["shape"], "%s uses the pit cell mask" % str(piece_id))
	var vertebra: Resource = _load_id("triceratops_vertebra")
	if vertebra != null:
		_assert(not _is_solid_rect(vertebra), "vertebra is not a 3-wide rectangle")
		_assert(int(vertebra.occupied_cells()) == 3, "vertebra stays 3 cells")
	var leftover: Resource = load("res://vertebra.tres")
	if leftover != null:
		_assert(not _is_solid_rect(leftover), "generic vertebra is not a 3-wide rectangle")
	var plate: Resource = _load_id("stegosaurus_plate")
	if plate != null:
		_assert(plate.get("shape") == PackedInt32Array([0, 1, 1, 0]), "stego plate stays a 2-cell kite")
	var jaw: Resource = _load_id("t_rex_jaw")
	if jaw != null:
		_assert(jaw.get("shape") == PackedInt32Array([1, 1, 1, 0, 0, 1]), "rex jaw stays a banana hook")
	var ribs: Resource = _load_id("t_rex_ribcage")
	if ribs != null:
		_assert(ribs.get("shape") == PackedInt32Array([1, 1, 1, 0, 1, 1]), "rex ribs stay a C")
	var fork: Resource = _load_id("stegosaurus_thagomizer")
	if fork != null:
		_assert(fork.get("shape") == PackedInt32Array([1, 0, 1, 1, 1, 0]), "thagomizer stays a fork")
	var neck: Resource = _load_id("brachiosaurus_neck")
	if neck != null:
		_assert(
			neck.get("shape") == PackedInt32Array([1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1]),
			"brach neck stays a long snake"
		)
	var brow: Resource = _load_id("triceratops_brow_horns")
	if brow != null:
		_assert(brow.get("shape") == PackedInt32Array([1, 0, 1, 0, 1, 0]), "brow horns stay a V")
	var rex_skull: Resource = _load_id("t_rex_skull")
	var trike_skull: Resource = _load_id("triceratops_skull")
	if rex_skull != null and trike_skull != null:
		_assert(rex_skull.get("shape") != trike_skull.get("shape"), "rex snout is not the trike frill")


func _test_doodles_use_the_right_geometry() -> void:
	var box := Rect2(0, 0, 100, 100)
	var rex: PackedVector2Array = _first_poly("t_rex_tooth", box)
	var trike: PackedVector2Array = _first_poly("triceratops_tooth", box)
	var brach: PackedVector2Array = _first_poly("brachiosaurus_tooth", box)
	_assert(rex.size() == 3, "rex tooth doodle is a fat triangle")
	_assert(trike.size() >= 5, "trike tooth doodle is a leaf, not a triangle")
	_assert(brach.size() == 4, "brach tooth doodle is a peg column")
	if rex.size() >= 3 and brach.size() >= 4:
		_assert(_bounds(rex).size.x > _bounds(brach).size.x, "rex triangle is fatter than the brach peg")
		_assert(_bounds(brach).size.y > _bounds(brach).size.x, "brach peg is taller than it is wide")
	var foot: Array = _polys("stegosaurus_foot", box)
	_assert(foot.size() >= 4, "stego foot doodle is a stump plus toes")
	var claw: PackedVector2Array = _first_poly("velociraptor_claw", box)
	_assert(claw.size() >= 6, "raptor claw doodle is a comma / sickle")
	if claw.size() >= 3:
		_assert(not _is_centered(claw, box), "raptor claw leans like a sickle")
	var plate: PackedVector2Array = _first_poly("stegosaurus_plate", box)
	_assert(plate.size() == 4, "stego plate doodle is a diamond / kite")
	var bone: Array = _polys("t_rex_femur", box)
	_assert(bone.size() >= 3, "long bone doodle is a bar with knobs")
	var rex_skull: PackedVector2Array = _first_poly("t_rex_skull", box)
	var trike_skull: PackedVector2Array = _first_poly("triceratops_skull", box)
	_assert(rex_skull.size() >= 5, "rex skull doodle is a snout")
	_assert(trike_skull.size() >= 6, "trike skull doodle is a frill blob")
	if rex_skull.size() >= 3 and trike_skull.size() >= 3:
		_assert(_bounds(rex_skull).size.x > _bounds(rex_skull).size.y, "rex snout is longer than it is tall")
		_assert(_bounds(trike_skull).size.x >= _bounds(rex_skull).size.x * 0.85, "trike frill stays a wide blob")
	_assert(_first_poly("stegosaurus_skull", box).size() >= 4, "stego skull doodle is a small wedge")
	_assert(_first_poly("velociraptor_skull", box).size() >= 4, "raptor skull doodle is a small wedge")
	_assert(_first_poly("brachiosaurus_skull", box).size() >= 4, "brach skull doodle is a small wedge")
	_assert(_first_poly("t_rex_jaw", box).size() >= 6, "rex jaw doodle is a banana")
	_assert(_first_poly("t_rex_ribcage", box).size() >= 6, "ribcage doodle is a C")
	_assert(_polys("stegosaurus_thagomizer", box).size() >= 3, "thagomizer doodle is a fork")
	var neck: PackedVector2Array = _first_poly("brachiosaurus_neck", box)
	_assert(neck.size() >= 6, "neck doodle is a long snake")
	if neck.size() >= 3:
		_assert(_bounds(neck).size.x > _bounds(neck).size.y, "neck snake is long, not a blob")
	var tail: PackedVector2Array = _first_poly("t_rex_tail", box)
	_assert(tail.size() >= 4, "tail doodle is a tapering bar")
	if tail.size() >= 4:
		_assert(_left_width(tail) > _right_width(tail), "tail bar tapers toward the tip")
	_assert(_first_poly("triceratops_nose_horn", box).size() >= 3, "nose horn doodle is a spike")
	_assert(_polys("triceratops_brow_horns", box).size() >= 2, "brow horns doodle is a V")
	_assert(_polys("triceratops_vertebra", box).size() >= 2, "vertebra doodle has a centrum and wings")
	_assert(_first_poly("trilobite", box).size() >= 6, "trilobite doodle is a bug, not a tooth")
	_assert(_polys("amber_insect", box).size() >= 2, "amber doodle is a gem with a bug inside")


func _test_pit_draws_the_part_doodle() -> void:
	var site_src: String = FileAccess.get_file_as_string("res://dig_site.gd")
	_assert(site_src.find("draw_silhouette") >= 0, "dig site draws the part silhouette")
	_assert(site_src.find("draw_rect(inset, mark, false, 2.0)") < 0, "dig site no longer uses a generic inset rectangle")
	var data_src: String = FileAccess.get_file_as_string("res://fossil_data.gd")
	_assert(data_src.find("func draw_silhouette") >= 0, "FossilData can draw its own pit doodle")
	_assert(data_src.find("func silhouette_polys") >= 0, "FossilData exposes silhouette polygons")


func _test_cell_counts_and_quotas_hold() -> void:
	var GS: Node = root.get_node("GameState")
	for piece_id in CELLS:
		var data: Resource = _load_id(str(piece_id))
		_assert(data != null, "%s still loads" % str(piece_id))
		if data == null:
			continue
		_assert(int(data.occupied_cells()) == int(CELLS[piece_id]), "%s stays %d cells" % [str(piece_id), int(CELLS[piece_id])])
	for piece_id in QUOTAS:
		_assert(int(GS.call("piece_need", str(piece_id))) == int(QUOTAS[piece_id]), "%s quota stays %d" % [str(piece_id), int(QUOTAS[piece_id])])
	var rex_tooth: Resource = _load_id("t_rex_tooth")
	if rex_tooth != null:
		_assert(int(rex_tooth.get("min_rank")) == 0, "rex tooth stay rank 0")
		_assert(int(rex_tooth.get("set_need")) == 6, "rex tooth set_need stays 6")


func _polys(piece_id: String, rect: Rect2) -> Array:
	var data: Resource = _load_id(piece_id)
	if data == null or not data.has_method("silhouette_polys"):
		return []
	var raw: Variant = data.call("silhouette_polys", rect)
	if raw is Array:
		return raw
	return []


func _first_poly(piece_id: String, rect: Rect2) -> PackedVector2Array:
	var polys: Array = _polys(piece_id, rect)
	if polys.is_empty():
		return PackedVector2Array()
	return polys[0]


func _bounds(pts: PackedVector2Array) -> Rect2:
	if pts.is_empty():
		return Rect2()
	var rect := Rect2(pts[0], Vector2.ZERO)
	for i in range(1, pts.size()):
		rect = rect.expand(pts[i])
	return rect


func _is_centered(pts: PackedVector2Array, box: Rect2) -> bool:
	if pts.is_empty():
		return true
	var sum := Vector2.ZERO
	for p in pts:
		sum += p
	var mid: Vector2 = sum / float(pts.size())
	return mid.distance_to(box.get_center()) < 8.0


func _left_width(pts: PackedVector2Array) -> float:
	return _band_height(pts, _bounds(pts).position.x, _bounds(pts).size.x * 0.35)


func _right_width(pts: PackedVector2Array) -> float:
	var box: Rect2 = _bounds(pts)
	return _band_height(pts, box.end.x - box.size.x * 0.35, box.size.x * 0.35)


func _band_height(pts: PackedVector2Array, x: float, width: float) -> float:
	var min_y: float = INF
	var max_y: float = -INF
	for p in pts:
		if p.x >= x and p.x <= x + width:
			min_y = minf(min_y, p.y)
			max_y = maxf(max_y, p.y)
	if min_y == INF:
		return 0.0
	return max_y - min_y


func _is_solid_rect(data: Resource) -> bool:
	var box: Vector2i = data.bounding_size()
	return int(data.occupied_cells()) == box.x * box.y and box.x > 0 and box.y > 0


func _assert(ok: bool, label: String) -> void:
	if ok:
		_passed += 1
		print("PASS  %s" % label)
	else:
		_failed += 1
		print("FAIL  %s" % label)
