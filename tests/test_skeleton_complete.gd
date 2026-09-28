extends SceneTree

## Completing every piece of a stand is the big payoff: cash + visitors x2.
## Run: godot --headless --path <project> -s res://tests/test_skeleton_complete.gd

var _failed: int = 0
var _passed: int = 0
var GS: Node
var TN: Node
var _events: Array = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	GS = root.get_node("GameState")
	TN = root.get_node("Tuning")
	GS.skeleton_completed.connect(func(stand_id: String, bonus: int) -> void: _events.append([stand_id, bonus]))
	_test_last_piece_completes_once()
	_reset()
	print("skeleton_complete %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _reset() -> void:
	GS.pieces.clear()
	GS.pending_unveils.clear()
	GS.featured_stand_id = ""
	GS.money = 0
	for item in GS.catalog:
		GS.levels[item["id"]] = 0
	GS.apply_upgrades()
	_events.clear()


func _fill(piece_id: String) -> void:
	while bool(GS.piece_needs_more(piece_id)):
		GS.install_find(piece_id, piece_id, 1.0, true)


func _test_last_piece_completes_once() -> void:
	_reset()
	var stand: String = "velociraptor"
	var ids: PackedStringArray = GS.stand_piece_ids(stand)
	_assert(ids.size() >= 3, "the raptor stand has several pieces")
	for i in ids.size() - 1:
		_fill(ids[i])
	_assert(_events.is_empty(), "an unfinished skeleton does not celebrate")
	_assert(not bool(GS.stand_is_complete(stand)), "stand is not complete yet")
	var raw_before: int = int(GS.stand_visitors(stand))
	var money_before: int = int(GS.money)
	_fill(ids[ids.size() - 1])
	_assert(bool(GS.stand_is_complete(stand)), "the last piece completes the stand")
	_assert(_events.size() == 1 and str(_events[0][0]) == stand, "completion fires once for that stand")
	var bonus: int = int(_events[0][1]) if not _events.is_empty() else 0
	_assert(bonus > 0 and bonus == int(GS.skeleton_bonus(stand)), "completion pays the skeleton bonus")
	_assert(int(GS.money) - money_before >= bonus, "the bonus lands in the wallet")
	var raw_sum: int = 0
	for id in ids:
		raw_sum += int(GS.piece_visitors(id))
	_assert(int(GS.stand_visitors(stand)) == int(round(float(raw_sum) * float(TN.complete_stand_mult))), "a finished skeleton draws x2 visitors")
	_assert(int(GS.stand_visitors(stand)) > raw_before, "finishing raises the stand's crowd")
	GS.install_find(ids[0], ids[0], 1.0, true)
	_assert(_events.size() == 1, "extra copies after completion do not re-celebrate")


func _assert(ok: bool, label: String) -> void:
	if ok:
		_passed += 1
		print("PASS  %s" % label)
	else:
		_failed += 1
		print("FAIL  %s" % label)
