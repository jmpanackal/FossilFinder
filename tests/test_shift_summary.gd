extends SceneTree

## Shift-over readout: one shift total, a quiet split, one fossil line.
## Run: godot --headless --path <project> -s res://tests/test_shift_summary.gd

var _failed: int = 0
var _passed: int = 0
var TN: Node


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	TN = root.get_node("Tuning")
	_test_dirty_tag_is_short()
	_test_clean_has_no_dirt_tag()
	_test_find_line_does_not_repeat_or_essay()
	_test_shift_lists_the_same_find_once()
	_test_summary_money_is_total_plus_quiet_breakdown()
	_test_summary_dim_is_a_full_rect_modal()
	_test_shift_over_does_not_leave_a_white_pit()
	print("shift_summary %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _test_dirty_tag_is_short() -> void:
	var no_brush: String = str(TN.summary_dirt_line(0.0, false))
	var skipped: String = str(TN.summary_dirt_line(0.0, true))
	_assert(no_brush.to_lower().find("still dirty") >= 0, "dusty find gets a still-dirty tag")
	_assert(no_brush.to_lower().find("brush") < 0, "no-brush dust does not lecture about a brush")
	_assert(no_brush.find("Dust") < 0, "no-brush dust does not say Dust 100%")
	_assert(skipped.to_lower().find("still dirty") >= 0, "skipped brushing still says still dirty")
	_assert(skipped.find("Dust") < 0, "skipped brushing does not shame Dust 100%")


func _test_clean_has_no_dirt_tag() -> void:
	_assert(str(TN.summary_dirt_line(1.0, false)) == "", "a cleaned find has no extra dirt line")


func _test_find_line_does_not_repeat_or_essay() -> void:
	var script: GDScript = load("res://summary.gd") as GDScript
	var dirty: String = str(script.call("find_line", "Tooth", "Well preserved", "still dirty"))
	var clean: String = str(script.call("find_line", "Tooth", "Well preserved", ""))
	_assert(dirty == "Tooth · Well preserved · still dirty", "dirty find is one short tagged line")
	_assert(clean == "Tooth · Well preserved", "clean find is name and grade only")
	_assert(dirty.find("hall") < 0 and dirty.find("case") < 0, "find line drops the hall-case essay")
	_assert(dirty.find("tooth") < 0, "find line does not repeat tooth in an essay")


func _test_shift_lists_the_same_find_once() -> void:
	var script: GDScript = load("res://summary.gd") as GDScript
	var line: String = str(script.call("find_line", "Vertebra", "Well preserved", "still dirty"))
	var joined: String = str(script.call("join_find_lines", PackedStringArray([line, line])))
	_assert(joined == line, "same find is listed once")
	_assert(joined.split("\n").size() == 1, "duplicate vertebra lines collapse to one")
	var other: String = str(script.call("find_line", "Tooth", "Mostly intact", ""))
	var both: String = str(script.call("join_find_lines", PackedStringArray([line, other])))
	_assert(both.find("Vertebra") >= 0 and both.find("Tooth") >= 0, "different finds both stay")


func _test_summary_money_is_total_plus_quiet_breakdown() -> void:
	var script: GDScript = load("res://summary.gd") as GDScript
	var panel: Node = script.new()
	root.add_child(panel)
	panel.show_summary(16, 51, str(script.call("find_line", "Tooth", "Mostly intact", "still dirty")), 4)
	var pay: String = str(panel._pay.text)
	var split: String = str(panel._breakdown.text)
	var body: String = str(panel._body.text)
	_assert(pay == "$67", "pay headline is only the shift total")
	_assert(pay.find("\n") < 0, "pay is one line")
	_assert(split.find("Fossils $16") >= 0 and split.find("Finds $51") >= 0, "quiet line splits finds and fossils")
	_assert(split.to_lower().find("dirt $") < 0, "quiet line never says dirt $")
	_assert(split.find("$67") < 0, "breakdown does not repeat the shift total")
	_assert(body.find("Tooth") >= 0, "summary still names the find")
	_assert(body.find("Mostly intact") >= 0, "summary still names the grade")
	_assert(body.find("still dirty") >= 0, "dusty find keeps a short dirty tag")
	_assert(body.find("brush") < 0, "summary does not lecture about a brush")
	_assert(body.find("Dust") < 0, "summary does not shame Dust 100%")
	_assert(body.find("case") < 0 and body.find("hall") < 0, "summary drops the hall-case essay")
	_assert(body.find("$") < 0, "fossil line does not repeat money")
	panel.free()


func _test_summary_dim_is_a_full_rect_modal() -> void:
	var panel: Node = (load("res://summary.gd") as GDScript).new() as Node
	root.add_child(panel)
	var dim: ColorRect = panel._dim
	_assert(dim != null, "summary has a dim overlay")
	if dim != null:
		_assert(is_equal_approx(dim.anchor_left, 0.0) and is_equal_approx(dim.anchor_right, 1.0), "dim stretches horizontally")
		_assert(is_equal_approx(dim.anchor_top, 0.0) and is_equal_approx(dim.anchor_bottom, 1.0), "dim stretches vertically")
		_assert(dim.get_parent() is Control, "dim lives under a full-rect Control, not a bare CanvasLayer")
	panel.show_summary(0, 0, "Left in the ground.", 0)
	_assert(bool(panel.visible), "summary can show the shift-over card")
	_assert(str(panel._pay.text) == "$0", "empty shift still shows one money number")
	_assert(str(panel._body.text) == "Left in the ground.", "left-in-ground is one line")
	_assert(not bool(panel._stars.visible), "left-in-ground has no star row")
	panel.free()


func _test_shift_over_does_not_leave_a_white_pit() -> void:
	var packed: PackedScene = load("res://main.tscn") as PackedScene
	_assert(packed != null, "main.tscn loads")
	if packed == null:
		return
	var main: Node = packed.instantiate()
	root.add_child(main)
	if main.has_method("_show_summary"):
		main.call("_show_summary")
	var pit: Node = main.get_node_or_null("DigSite")
	var backdrop: Node = main.get_node_or_null("SiteBackdrop")
	var card: Node = main.get_node_or_null("Summary")
	_assert(pit != null and bool(pit.visible), "shift-over keeps the excavated pit on screen")
	_assert(backdrop != null and bool(backdrop.visible), "field stays behind the card")
	_assert(card != null and bool(card.visible), "shift-over card is up")
	_assert(backdrop != null and backdrop.has_method("covers_chunk_hole"), "backdrop can still plug a hole if the pit is gone")
	if backdrop != null and backdrop.has_method("covers_chunk_hole"):
		_assert(not bool(backdrop.call("covers_chunk_hole")), "visible pit fills the site hole — no blank tan patch")
	var Site: GDScript = load("res://site_backdrop.gd") as GDScript
	_assert(Site != null and Site.has_method("hole_fill_color"), "backdrop exposes the hole fill color")
	if Site != null and Site.has_method("hole_fill_color"):
		var fill: Color = Site.hole_fill_color()
		_assert(fill.is_equal_approx(Site.ground_color()), "hole fill is the same tan as the field")
		_assert(not fill.is_equal_approx(Site.clear_color()), "hole fill is not the pale letterbox wash")
		_assert(not fill.is_equal_approx(Color.WHITE), "hole fill is not white")
	var main_src: String = FileAccess.get_file_as_string("res://main.gd")
	_assert(main_src.find("play_view_size") >= 0, "_sync_view stays in design space")
	_assert(main_src.find("Tuning.view_w = get_viewport().get_visible_rect()") < 0, "window pixels do not become the pit world")
	var dim: ColorRect = card.get("_dim") if card != null else null
	_assert(dim != null and bool(card.visible), "dim overlay still sits over the site and pit")
	main.free()


func _assert(ok: bool, label: String) -> void:
	if ok:
		_passed += 1
		print("PASS  %s" % label)
	else:
		_failed += 1
		print("FAIL  %s" % label)
