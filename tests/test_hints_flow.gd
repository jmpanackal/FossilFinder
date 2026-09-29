extends SceneTree

## The real game scene teaches as you play: the first shift shows the dig tip on
## the ribbon under the pit; the museum and upgrade screens show theirs as toasts.
## Run: godot --headless --path <project> -s res://tests/test_hints_flow.gd

var _failed: int = 0
var _passed: int = 0
var GS: Node
var H: Node


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	GS = root.get_node("GameState")
	H = root.get_node("Hints")
	for key in GS.hints_seen.keys():
		if str(key).begins_with("tip_"):
			GS.hints_seen.erase(key)
	H.pending.clear()
	root.get_node("Settings").tips_enabled = true
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	## The game loads the real save when it starts, which may hold tips the player
	## has already seen. Forget them (in memory only) so this test starts fresh.
	for key in GS.hints_seen.keys():
		if str(key).begins_with("tip_"):
			GS.hints_seen.erase(key)
	H.pending.clear()
	await _frames(2)
	_assert(H.pending.is_empty() and not bool(H.seen("dig")), "nothing is taught on the title screen")
	## The title's start button begins the first shift.
	main._begin_from_title()
	await _frames(6)
	_assert(bool(H.seen("dig")), "the first shift teaches how to dig")
	_assert(bool(main.hud.ribbon_busy()), "and shows it on the ribbon under the pit, not over the cells")
	_assert(not bool(H.seen("shop")) and not bool(H.seen("museum")), "tips for screens you have not opened wait")

	## The dig teaches why it pays, and what the agate pocket is, the first time each shows up.
	_assert(main.dig_site.has_signal("lucky_appeared"), "the dig announces an agate pocket")
	main.dig_site._spawn_lucky()
	_assert(H.is_pending("pocket") or bool(H.seen("pocket")), "the first agate pocket explains itself")
	main.dig_site._matrix_juice = [{"name": "pebble", "amount": 3, "rarity": 0}]
	main._on_layer_cleared(3, Vector2(600, 300))
	_assert(H.is_pending("sifted") or bool(H.seen("sifted")), "the first sifted find explains why digging pays")

	## Another tip never cuts one that is still up.
	H.teach("collect")
	await _frames(6)
	_assert(H.is_pending("collect") and not bool(H.seen("collect")), "a second tip waits while the first is showing")

	main._end_round()
	## On the shift-over screen a tip goes inside the card (a toast would sit under
	## its dim overlay), and it never lands as a toast there.
	Engine.time_scale = 12.0
	for _i in 120:
		await _frames(20)
		if bool(main.summary._tip.visible):
			break
	Engine.time_scale = 1.0
	_assert(bool(main.summary._tip.visible) and str(main.summary._tip.text).begins_with("TIP"), "a tip on the shift-over screen shows inside the card")
	main.show_screen("museum")
	await _frames(4)
	_assert(H.is_pending("museum") or bool(H.seen("museum")), "opening the museum asks for its tip")
	main.show_screen("shop")
	await _frames(4)
	var paused: bool = paused_now()
	_assert(H.is_pending("shop") or bool(H.seen("shop")), "opening upgrades asks for its tip")

	## With time, everything waiting gets shown, one at a time. The shop and museum
	## pause the game, so this also proves tips keep flowing while it is paused.
	_assert(bool(paused), "the shop/museum screens pause the game")
	Engine.time_scale = 12.0
	for _i in 90:
		await _frames(30)
		if H.pending.is_empty():
			break
	Engine.time_scale = 1.0
	_assert(H.pending.is_empty(), "every waiting tip is eventually shown")
	_assert(bool(H.seen("collect")) and bool(H.seen("shop")), "including the ones that had to wait")

	## Turning tips off silences everything.
	root.get_node("Settings").tips_enabled = false
	H.reset_seen()
	main.show_screen("museum")
	await _frames(20)
	_assert(H.pending.is_empty() and not bool(H.seen("museum")), "with tips off nothing is queued or shown")

	root.get_node("Settings").tips_enabled = true
	for key in GS.hints_seen.keys():
		if str(key).begins_with("tip_"):
			GS.hints_seen.erase(key)
	main.queue_free()
	print("hints_flow %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func paused_now() -> bool:
	return paused


func _frames(n: int) -> void:
	for _i in n:
		await process_frame


func _assert(ok: bool, label: String) -> void:
	if ok:
		_passed += 1
		print("PASS  %s" % label)
	else:
		_failed += 1
		print("FAIL  %s" % label)
