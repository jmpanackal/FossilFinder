extends SceneTree

## Find celebrations live on a ribbon at the top edge of the Finds tray:
## visible, off the dig cells, never blocking clicks, and louder for better finds.
## Run: godot --headless --path <project> -s res://tests/test_reward_ribbon.gd

var _failed: int = 0
var _passed: int = 0
var TN: Node


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	TN = root.get_node("Tuning")
	var hud_script: GDScript = load("res://hud.gd") as GDScript
	var hud: CanvasLayer = hud_script.new()
	root.add_child(hud)
	await process_frame
	var ribbon: Control = hud.call("ribbon")
	_assert(ribbon != null, "the HUD owns a reward ribbon")
	_assert(not ribbon.visible, "the ribbon is hidden until something is found")
	_assert(ribbon.mouse_filter == Control.MOUSE_FILTER_IGNORE, "the ribbon never blocks digging clicks")
	hud.call("celebrate", -1, "Great condition!", "Condition = how well it survived underground.", 4, 2)
	await process_frame
	_assert(ribbon.visible, "celebrate shows the ribbon")
	_assert(ribbon.position.y >= float(TN.pit_face_bottom()), "the ribbon sits below the dig cells")
	_assert(ribbon.position.x >= 0.0 and ribbon.position.x + ribbon.size.x <= float(TN.view_w), "the ribbon stays on screen")
	hud.call("celebrate", -1, "Exhibit upgraded!", "", 5, 3)
	_assert(int(ribbon.get("_queue").size()) == 1, "a second celebration waits its turn")
	var main_script: GDScript = load("res://main.gd") as GDScript
	_assert(int(main_script.call("condition_tier", 1)) < int(main_script.call("condition_tier", 4)), "Great finds celebrate louder than Poor ones")
	_assert(int(main_script.call("condition_tier", 5)) == 3, "Perfect gets the biggest ribbon")
	hud.queue_free()
	print("reward_ribbon %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _assert(ok: bool, label: String) -> void:
	if ok:
		_passed += 1
		print("PASS  %s" % label)
	else:
		_failed += 1
		print("FAIL  %s" % label)
