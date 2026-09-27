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
	_test_summary_finds_show_icon_and_label()
	_test_empty_shift_has_no_find_icons()
	_test_empty_haul_card_hugs_actions()
	_test_filled_haul_lists_finds_and_grows()
	_test_shift_over_copy_keeps_word_spaces()
	_test_shift_over_nav_reuses_header_glyphs()
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


func _test_summary_finds_show_icon_and_label() -> void:
	var script: GDScript = load("res://summary.gd") as GDScript
	var panel: Node = script.new()
	root.add_child(panel)
	var finds: Array = [
		{"name": "Triceratops Brow Horns", "piece_id": "triceratops_brow_horns", "grade": "Well preserved", "dirt": "", "fate": ""},
		{"name": "Triceratops Vertebra", "piece_id": "triceratops_vertebra", "grade": "Well preserved", "dirt": "", "fate": "sold extra"},
		{"name": "Stegosaurus Plate", "piece_id": "stegosaurus_plate", "grade": "Well preserved", "dirt": "", "fate": "1/3 on display"},
	]
	_assert(panel.get_method_argument_count("show_summary") >= 5, "show_summary accepts the extracted finds")
	if panel.get_method_argument_count("show_summary") >= 5:
		panel.call("show_summary", 142, 89559, "", 5, finds)
	_assert(str(panel._pay.text) == "$89701", "icon list keeps one shift total")
	_assert(str(panel._breakdown.text).find("Finds $89559") >= 0, "icon list keeps the quiet Finds split")
	_assert(str(panel._breakdown.text).find("Fossils $142") >= 0, "icon list keeps the quiet Fossils split")
	var rows: Array = panel.get("_find_rows") if panel.get("_find_rows") != null else []
	_assert(rows.size() == 3, "each extracted find becomes a summary row")
	if rows.size() >= 3:
		var first: Control = rows[0] as Control
		var last: Control = rows[2] as Control
		var first_icon: Control = first.get("_icon") as Control if first != null else null
		var first_label: Label = first.get("_label") as Label if first != null else null
		var last_label: Label = last.get("_label") as Label if last != null else null
		_assert(first_icon != null, "first find shows the bone doodle")
		_assert(first_label != null and first_label.text.find("Triceratops Brow Horns") >= 0, "first find keeps its name")
		_assert(first_label != null and first_label.text.find("Well preserved") >= 0, "first find keeps its grade")
		_assert(last.get("_icon") != null, "last find shows the bone doodle")
		_assert(last_label != null and last_label.text.find("Stegosaurus Plate") >= 0, "last find keeps its name")
		_assert(last_label != null and last_label.text.find("1/3 on display") >= 0, "last find keeps its fate")
	_assert(not bool(panel._body.visible) or str(panel._body.text).is_empty(), "finds are rows, not a wall of names")
	var row_src: String = FileAccess.get_file_as_string("res://summary_find_row.gd")
	_assert(not row_src.is_empty(), "summary_find_row.gd paints each find")
	_assert(row_src.find("draw_silhouette") >= 0, "summary rows fall back to the part silhouette")
	_assert(row_src.find("ArtCatalog") >= 0 or row_src.find("art_catalog") >= 0, "summary rows reuse ArtCatalog bone art")
	var main_src: String = FileAccess.get_file_as_string("res://main.gd")
	_assert(main_src.find("\"piece_id\"") >= 0, "extracted finds keep their piece id for the doodle")
	_assert(main_src.find("show_summary") >= 0 and main_src.find("_round_finds") >= 0, "shift-over hands the finds to the card")
	panel.free()


func _test_empty_shift_has_no_find_icons() -> void:
	var panel: Node = (load("res://summary.gd") as GDScript).new() as Node
	root.add_child(panel)
	panel.show_summary(0, 0, "Left in the ground.", 0)
	var rows: Array = panel.get("_find_rows") if panel.get("_find_rows") != null else []
	_assert(rows.is_empty(), "an empty shift has no fossil icons")
	_assert(str(panel._body.text) == "Left in the ground.", "empty shift still says left in the ground")
	panel.free()


func _test_empty_haul_card_hugs_actions() -> void:
	var panel: Node = (load("res://summary.gd") as GDScript).new() as Node
	root.add_child(panel)
	panel.show_summary(0, 0, "Left in the ground.", 0)
	var card: Control = panel._panel as Control
	var finds: Control = panel._finds_box as Control
	var rows: Array = panel.get("_find_rows") if panel.get("_find_rows") != null else []
	_assert(card != null, "shift-over exposes the card")
	_assert(rows.is_empty(), "empty haul has no find rows")
	_assert(finds == null or not finds.visible, "empty haul hides the find list")
	if finds != null:
		_assert(finds.get_combined_minimum_size().y <= 1.0, "empty haul does not reserve a finds well")
	if card != null:
		var height: float = card.offset_bottom - card.offset_top
		_assert(height > 160.0, "empty card still fits the pay and actions")
		_assert(height < 340.0, "empty haul card hugs Dig again, not a 400px well")
		var box: Control = panel.get("_box") as Control
		if box != null:
			var content_h: float = box.get_combined_minimum_size().y
			_assert(height <= content_h + 48.0, "empty card height tracks the copy, not leftover brown")
	panel.free()


func _test_filled_haul_lists_finds_and_grows() -> void:
	var script: GDScript = load("res://summary.gd") as GDScript
	var empty: Node = script.new()
	root.add_child(empty)
	empty.show_summary(0, 0, "Left in the ground.", 0)
	var empty_h: float = _card_height(empty)
	empty.free()
	var panel: Node = script.new()
	root.add_child(panel)
	var finds: Array = [
		{"name": "Triceratops Brow Horns", "piece_id": "triceratops_brow_horns", "grade": "Well preserved", "dirt": "", "fate": ""},
		{"name": "Triceratops Vertebra", "piece_id": "triceratops_vertebra", "grade": "Well preserved", "dirt": "", "fate": "sold extra"},
		{"name": "Stegosaurus Plate", "piece_id": "stegosaurus_plate", "grade": "Well preserved", "dirt": "", "fate": "1/3 on display"},
	]
	panel.call("show_summary", 142, 89559, "", 5, finds)
	var rows: Array = panel.get("_find_rows") if panel.get("_find_rows") != null else []
	_assert(rows.size() == 3, "non-empty haul still lists each find")
	_assert(bool(panel._finds_box.visible), "filled haul shows the find list")
	var filled_h: float = _card_height(panel)
	_assert(filled_h > empty_h + 8.0, "a real haul grows the card past the empty hug")
	var list_h: float = 0.0
	var host: Control = panel.get("_finds_scroll") as Control
	if host == null:
		host = panel._finds_box as Control
	if host != null:
		list_h = maxf(host.get_combined_minimum_size().y, host.size.y)
	var rows_h: float = 0.0
	for raw in rows:
		var row: Control = raw as Control
		if row != null:
			rows_h += maxf(row.custom_minimum_size.y, row.get_combined_minimum_size().y)
	_assert(list_h + 1.0 >= rows_h, "three finds are not clipped by a short well")
	if rows.size() >= 3:
		var first_label: Label = rows[0].get("_label") as Label if rows[0] != null else null
		var last_label: Label = rows[2].get("_label") as Label if rows[2] != null else null
		_assert(first_label != null and first_label.text.find("Triceratops Brow Horns") >= 0, "filled haul still names the first find")
		_assert(last_label != null and last_label.text.find("Stegosaurus Plate") >= 0, "filled haul still names the last find")
	panel.free()


func _test_shift_over_copy_keeps_word_spaces() -> void:
	var panel: Node = (load("res://summary.gd") as GDScript).new() as Node
	root.add_child(panel)
	panel.show_summary(0, 0, "Left in the ground.", 0)
	var title: Label = panel._title as Label
	var body: Label = panel._body as Label
	var dig: Button = panel._button as Button
	var museum: Button = _find_button(panel, "Museum")
	var upgrades: Button = _find_button(panel, "Upgrades")
	_assert(title != null and str(title.text) == "Shift over", "title is Shift over")
	_assert(str(title.text).find("Shiftover") < 0, "title is not jammed into Shiftover")
	_assert(body != null and str(body.text) == "Left in the ground.", "body is Left in the ground.")
	_assert(str(body.text).find("Leftintheground") < 0, "body is not jammed into Leftintheground")
	_assert(dig != null and str(dig.text) == "Dig again", "primary action is Dig again")
	_assert(str(dig.text).find("Digagain") < 0, "Dig again keeps its space")
	_assert(museum != null and str(museum.text) == "Museum", "nav still says Museum")
	_assert(upgrades != null and str(upgrades.text) == "Upgrades", "nav still says Upgrades")
	if title != null:
		_assert(not title.clip_text, "title does not clip its space")
		_assert(_copy_fits(title), "Shift over is wide enough to keep its space")
	if body != null:
		_assert(not body.clip_text, "body does not clip its spaces")
		_assert(_copy_fits(body), "Left in the ground. is wide enough to keep its spaces")
	if dig != null:
		_assert(not dig.clip_text, "Dig again does not clip its space")
		_assert(_copy_fits(dig), "Dig again is wide enough to keep its space")
	if museum != null:
		_assert(not museum.clip_text, "Museum does not clip its letters")
		_assert(_copy_fits(museum), "Museum is wide enough to stay Museum")
	if upgrades != null:
		_assert(not upgrades.clip_text, "Upgrades does not clip its letters")
		_assert(_copy_fits(upgrades), "Upgrades is wide enough to stay Upgrades")
	panel.free()


func _test_shift_over_nav_reuses_header_glyphs() -> void:
	var panel: Node = (load("res://summary.gd") as GDScript).new() as Node
	root.add_child(panel)
	panel.show_summary(0, 0, "Left in the ground.", 0)
	var dig: Button = panel._button as Button
	var museum: Button = _find_button(panel, "Museum")
	var upgrades: Button = _find_button(panel, "Upgrades")
	_assert(dig != null and str(dig.text) == "Dig again", "Dig again stays the word-only primary")
	_assert(str(dig.text).find(" ") >= 0, "Dig again keeps its space")
	_assert(_find_shop_icon(dig) == null, "Dig again has no glyph")
	_assert(_find_tool_icon(dig) == null, "Dig again does not borrow a tool glyph")
	_assert(museum != null and str(museum.text) == "Museum", "Museum still says Museum")
	_assert(upgrades != null and str(upgrades.text) == "Upgrades", "Upgrades still says Upgrades")
	_assert(_action_glyph(museum) == "exhibit", "shift-over Museum uses the same hall/plinth mark")
	_assert(_action_glyph(upgrades) == "wrench", "shift-over Upgrades uses the same wrench mark")
	_assert_action_icon_spec(museum, "shift-over Museum")
	_assert_action_icon_spec(upgrades, "shift-over Upgrades")
	panel.free()


func _assert_action_icon_spec(button: Button, where: String) -> void:
	var mark: Control = _find_shop_icon(button) as Control
	_assert(mark != null, "%s has an action glyph" % where)
	if mark == null or button == null:
		return
	_assert(is_equal_approx(mark.size.x, 18.0) and is_equal_approx(mark.size.y, 18.0), "%s glyph is the shared 18px action box" % where)
	_assert(_mark_uses_icon_gap(button, mark, 8.0), "%s keeps an 8px gap before the word" % where)
	_assert(_mark_vcenters_to_label_line(button, mark), "%s glyph is vertically centered to the word" % where)
	_assert(mark.position.x + 1.0 < button.size.x * 0.5, "%s glyph stays left, not centered in the pill" % where)


func _mark_uses_icon_gap(button: Button, mark: Control, gap: float) -> bool:
	var text_x: float = _button_text_left(button)
	if text_x < 0.0:
		return false
	return absf(text_x - (mark.position.x + mark.size.x) - gap) <= 1.5


func _mark_vcenters_to_label_line(button: Button, mark: Control) -> bool:
	var font: Font = button.get_theme_font("font")
	var sized: int = button.get_theme_font_size("font_size")
	if font == null:
		return false
	var line_h: float = font.get_height(sized)
	var line_mid: float = (button.size.y - line_h) * 0.5 + line_h * 0.5
	return absf((mark.position.y + mark.size.y * 0.5) - line_mid) <= 2.0


func _button_text_left(button: Button) -> float:
	if button == null:
		return -1.0
	var font: Font = button.get_theme_font("font")
	var sized: int = button.get_theme_font_size("font_size")
	if font == null:
		return -1.0
	var box: StyleBox = button.get_theme_stylebox("normal")
	var pad_l: float = box.content_margin_left if box != null else 12.0
	var pad_r: float = box.content_margin_right if box != null else 12.0
	var text_w: float = font.get_string_size(str(button.text), HORIZONTAL_ALIGNMENT_LEFT, -1, sized).x
	var inner: float = maxf(button.size.x - pad_l - pad_r, 1.0)
	if button.alignment == HORIZONTAL_ALIGNMENT_LEFT:
		return pad_l
	if button.alignment == HORIZONTAL_ALIGNMENT_RIGHT:
		return pad_l + maxf(inner - text_w, 0.0)
	return pad_l + maxf(inner - text_w, 0.0) * 0.5


func _action_glyph(node: Node) -> String:
	var mark: Node = _find_shop_icon(node)
	if mark != null and "glyph" in mark:
		return str(mark.glyph)
	return ""


func _find_shop_icon(node: Node) -> Node:
	if node == null:
		return null
	var script: Script = node.get_script() as Script
	if script != null and str(script.resource_path).ends_with("shop_icon.gd"):
		return node
	for child in node.get_children():
		var found: Node = _find_shop_icon(child)
		if found != null:
			return found
	return null


func _find_tool_icon(node: Node) -> Node:
	if node == null:
		return null
	var script: Script = node.get_script() as Script
	if script != null and str(script.resource_path).ends_with("tool_icon.gd"):
		return node
	for child in node.get_children():
		var found: Node = _find_tool_icon(child)
		if found != null:
			return found
	return null


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


func _card_height(panel: Node) -> float:
	var card: Control = panel.get("_panel") as Control if panel != null else null
	if card == null:
		return 0.0
	return card.offset_bottom - card.offset_top


func _find_button(node: Node, text: String) -> Button:
	if node is Button and str((node as Button).text) == text:
		return node as Button
	for child in node.get_children():
		var found: Button = _find_button(child, text)
		if found != null:
			return found
	return null


func _copy_fits(control: Control) -> bool:
	if control == null:
		return false
	var font: Font = control.get_theme_font("font")
	var sized: int = control.get_theme_font_size("font_size")
	if font == null:
		return false
	var text: String = str(control.get("text"))
	var need: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, sized).x
	var have: float = maxf(control.custom_minimum_size.x, control.size.x)
	return have + 0.5 >= need


func _assert(ok: bool, label: String) -> void:
	if ok:
		_passed += 1
		print("PASS  %s" % label)
	else:
		_failed += 1
		print("FAIL  %s" % label)
