extends SceneTree

## The Tools and Finds rails are engraved plates: a plain dark box with a brass
## ornament layer on top (sheen, inner line, corner brackets, a rule under the
## title). The box itself must stay a plain StyleBoxFlat.
## Run: godot --headless --path <project> -s res://tests/test_rail_style.gd

var _failed: int = 0
var _passed: int = 0
var TN: Node


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	TN = root.get_node("Tuning")
	await _test_rails_have_the_ornament()
	_test_the_grid_line_is_soft()
	print("rail_style %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _test_rails_have_the_ornament() -> void:
	var hud: CanvasLayer = (load("res://hud.gd") as Script).new() as CanvasLayer
	root.add_child(hud)
	for _i in 4:
		await process_frame
	var seen: int = 0
	for key in ["_tools_frame", "_finds_frame"]:
		var frame: Control = hud.get(key) as Control
		_assert(frame != null, "%s exists" % key)
		if frame == null:
			continue
		var orn: Control = frame.get_node_or_null("Ornament") as Control
		_assert(orn != null, "%s carries the ornament layer" % key)
		if orn == null:
			continue
		seen += 1
		_assert(orn.mouse_filter == Control.MOUSE_FILTER_IGNORE, "%s ornament never steals clicks" % key)
		_assert(float(orn.get("header_y")) > 14.0, "%s ornament draws its title rule below the title (y=%.0f)" % [key, float(orn.get("header_y"))])
		var box: StyleBox = frame.get_theme_stylebox("panel")
		_assert(box is StyleBoxFlat and (box as StyleBoxFlat).border_width_left >= 2, "%s keeps its plain outlined box underneath" % key)
		_assert(absf(orn.size.x - frame.size.x) <= 1.0 and absf(orn.size.y - frame.size.y) <= 1.0, "%s ornament covers the whole rail" % key)
	_assert(seen == 2, "both rails are decorated")
	hud.queue_free()


func _test_the_grid_line_is_soft() -> void:
	## The dig grid used to be heavy near-black lines; it is now a warm, see-through brown.
	_assert(TN.cell_line.a < 0.9, "grid lines let the cell colour through")
	_assert(TN.cell_line.get_luminance() < 0.25, "but are still dark enough to read as cell edges")


func _assert(ok: bool, label: String) -> void:
	if ok:
		_passed += 1
		print("PASS  %s" % label)
	else:
		_failed += 1
		print("FAIL  %s" % label)
