extends SceneTree

## Sitting 1: existing hit juice reads louder. No new systems.
## Run: godot --headless --path <project> -s res://tests/test_dig_juice.gd

var _failed: int = 0
var _passed: int = 0
var GS: Node
var TN: Node


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	GS = root.get_node("GameState")
	TN = root.get_node("Tuning")
	_test_dirt_and_rock_bursts_are_fat()
	_test_punch_squash_is_a_real_hit()
	_test_cracks_read_on_damaged_dirt()
	_test_pick_shake_kicks()
	_test_money_floats_are_loud()
	print("dig_juice %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _make_site() -> Node2D:
	var script: GDScript = load("res://dig_site.gd") as GDScript
	_assert(script != null, "dig_site.gd loads for juice tests")
	if script == null:
		return null
	var site: Node2D = script.new()
	root.add_child(site)
	return site


func _test_dirt_and_rock_bursts_are_fat() -> void:
	var site := _make_site()
	if site == null:
		return
	_assert(site.has_method("_burst"), "hits still use the existing burst hook")
	if not site.has_method("_burst"):
		site.queue_free()
		return
	site.call("_burst", Vector2.ZERO, 0, false)
	var particles: CPUParticles2D = site.get("_particles") as CPUParticles2D
	_assert(particles != null, "dirt/rock still share the existing particle node")
	if particles == null:
		site.queue_free()
		return
	_assert(particles.amount >= 18, "a dirt hit sprays a real burst")
	_assert(particles.scale_amount_min >= 1.05, "dirt chunks read at cell scale")
	_assert(particles.lifetime >= 0.38, "dirt specks hang long enough to see")
	site.call("_burst", Vector2.ZERO, 18, false)
	_assert(particles.amount >= 24, "a rock hit sprays more than dirt")
	_assert(particles.scale_amount_max >= 2.8, "rock chips are bigger than dirt")
	var rock_n: int = particles.amount
	site.call("_burst", Vector2.ZERO, 18, true)
	_assert(particles.amount > rock_n, "a fat scoop still uses the same burst, louder")
	site.queue_free()


func _test_punch_squash_is_a_real_hit() -> void:
	var site := _make_site()
	if site == null:
		return
	_assert(site.has_method("_punch_squash"), "hits still use the existing punch hook")
	if not site.has_method("_punch_squash"):
		site.queue_free()
		return
	var dirt: Vector2 = site.call("_punch_squash", 0)
	var firm: Vector2 = site.call("_punch_squash", 1)
	var bone: Vector2 = site.call("_punch_squash", 2)
	_assert(dirt.y >= 0.28, "dirt squash is a cookie punch, not a tick")
	_assert(dirt.x >= 0.20, "dirt stretches wide on the hit")
	_assert(firm.y >= 0.12, "packed/rock still flinches")
	_assert(bone.y >= 0.14, "bone flinch is readable")
	_assert(dirt.y > firm.y, "dirt still squashes softer than packed/rock")
	site.call("_begin_punch", Vector2i(2, 2), 0)
	site.call("_tick_punches", 0.02)
	var rect: Rect2 = site.call("_punched_rect", Rect2(0, 0, 64, 64), Vector2i(2, 2))
	_assert(rect.size.y < 64.0 * 0.86, "the live squash is obvious on the cell")
	_assert(site.call("_punch_scale", 2, 0.08) == Vector2.ONE, "bone flinch is still over by 80ms")
	site.queue_free()


func _test_cracks_read_on_damaged_dirt() -> void:
	var site := _make_site()
	if site == null:
		return
	_assert(site.has_method("_crack_stroke_width"), "cracks expose a stroke width")
	if site.has_method("_crack_stroke_width"):
		_assert(is_equal_approx(float(site.call("_crack_stroke_width")), 1.4), "crack lines stay the pre-juice hairline")
	_assert(site.has_method("_dirt_crack_count"), "dirt cracks scale with damage")
	if site.has_method("_dirt_crack_count"):
		_assert(int(site.call("_dirt_crack_count", 1.0)) == 3, "a spent dirt cell keeps the old few scratches")
		_assert(int(site.call("_dirt_crack_count", 0.4)) <= 1, "a chipped cell is not webbed with cracks")
	site.queue_free()


func _test_pick_shake_kicks() -> void:
	_assert(bool(TN.shake_enabled), "pick shake stays on the existing camera hook")
	## Toned down for late game (fast picks shake often); still noticeable.
	_assert(float(TN.shake_strength) >= 4.0 and float(TN.shake_strength) <= 6.0, "pick shake is a noticeable but gentle kick")
	_assert(float(TN.shake_time) >= 0.12, "pick shake lasts long enough to feel")


func _test_money_floats_are_loud() -> void:
	var script: GDScript = load("res://floating_text.gd") as GDScript
	_assert(script != null, "floating_text.gd loads")
	if script == null:
		return
	var floater: Node2D = script.new()
	root.add_child(floater)
	floater.call("setup", "+$4", Color("E4B75A"))
	_assert(floater.get_child_count() > 0, "+$ still uses the existing float label")
	if floater.get_child_count() > 0:
		var label: Label = floater.get_child(0) as Label
		_assert(label != null and label.text == "+$4", "money floats still say +$")
		if label != null:
			_assert(label.get_theme_font_size("font_size") >= 20, "+$ type is loud enough to catch")
	_assert(float(floater.get("_life")) >= 0.82, "+$ hangs long enough to read")
	floater.queue_free()
	var main_src: String = FileAccess.get_file_as_string("res://main.gd")
	_assert(main_src.find("_spawn_float") >= 0, "layer clears still spawn +$ on the existing hook")
	_assert(main_src.find("font_size: int = 16") < 0, "main does not keep the quiet 16px float default")


func _assert(ok: bool, label: String) -> void:
	if ok:
		_passed += 1
		print("PASS  %s" % label)
	else:
		_failed += 1
		print("FAIL  %s" % label)
