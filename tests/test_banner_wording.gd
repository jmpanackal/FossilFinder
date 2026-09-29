extends SceneTree

## Every explanation on a banner fits on ONE line of the ribbon (and stays up long
## enough to read). Long, two-line explainers flashed past too fast.
## Run: godot --headless --path <project> -s res://tests/test_banner_wording.gd

var _failed: int = 0
var _passed: int = 0
var TN: Node
var _font: Font
var _size: int = 13
var _limit: float = 440.0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	TN = root.get_node("Tuning")
	_font = (load("res://ui_style.gd") as GDScript).call("display_font")
	var consts: Dictionary = (load("res://reward_ribbon.gd") as GDScript).get_script_constant_map()
	_size = int(consts["SUB_SIZE"])
	_limit = float(consts["SUB_MAX_W"]) - 20.0
	_test_bone_kind_hints()
	_test_wording_in_main()
	print("banner_wording %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _fits(text: String) -> bool:
	return _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, _size).x <= _limit


func _test_bone_kind_hints() -> void:
	for kind in [TN.BONE_FRAGILE, TN.BONE_OPAL]:
		var text: String = str(TN.BONE_KIND_HINTS[kind])
		_assert(_fits(text), "the %s hint fits on one line (%s)" % [TN.BONE_KIND_NAMES[kind], text])


func _test_wording_in_main() -> void:
	var src: String = FileAccess.get_file_as_string("res://main.gd")
	## The fixed sentences that banners are built from: subtitles handed to the ribbon,
	## the first-time explainers and the repeat-Opal line.
	var patterns: Array = [
		"return \"([^\"]+)\"",
		"var sub: String = \"([^\"]+)\"",
		"sub = \"([^\"]+)\"",
		"else \"([^\"]+)\"",
	]
	var checked: int = 0
	var too_long: PackedStringArray = PackedStringArray()
	var teach_fn: int = src.find("func _teach_on_reveal")
	var teach_end: int = src.find("\nfunc ", teach_fn + 10)
	var teach_body: String = src.substr(teach_fn, teach_end - teach_fn)
	for hit in RegEx.create_from_string("return \"([^\"]+)\"").search_all(teach_body):
		checked += 1
		if not _fits(hit.get_string(1)):
			too_long.append(hit.get_string(1))
	for pattern in patterns.slice(1):
		for hit in RegEx.create_from_string(str(pattern)).search_all(src):
			var text: String = hit.get_string(1)
			if text.contains("%"):
				continue
			checked += 1
			if not _fits(text):
				too_long.append(text)
	_assert(checked >= 5, "the banner sentences in main.gd are found (%d)" % checked)
	_assert(too_long.is_empty(), "each fits on one line (%s)" % ", ".join(too_long))
	var teach: RegExMatch = RegEx.create_from_string("const TEACH_HOLD := ([0-9.]+)").search(src)
	_assert(teach != null and float(teach.get_string(1)) >= 6.0, "explainer banners are held long enough to read")


func _assert(ok: bool, label: String) -> void:
	if ok:
		_passed += 1
		print("PASS  %s" % label)
	else:
		_failed += 1
		print("FAIL  %s" % label)
