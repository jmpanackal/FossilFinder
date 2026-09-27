extends SceneTree

## Web audio unlock must exist and stay a no-op on desktop.
## Run: godot --headless --path <project> -s res://tests/test_sfx_web_unlock.gd

var _failed: int = 0
var _passed: int = 0
var SfxNode: Node


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	SfxNode = root.get_node("Sfx")
	_test_unlock_exists_and_is_desktop_safe()
	_test_play_stays_wav()
	print("sfx_web_unlock %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _test_unlock_exists_and_is_desktop_safe() -> void:
	_assert(SfxNode.has_method("unlock_web_audio"), "Sfx.unlock_web_audio exists")
	if not SfxNode.has_method("unlock_web_audio"):
		return
	SfxNode.unlock_web_audio()
	var master: int = AudioServer.get_bus_index("Master")
	_assert(master >= 0, "Master bus still exists after unlock")
	_assert(not AudioServer.is_bus_mute(master), "desktop unlock does not mute Master")
	SfxNode.ensure_bus()
	var sfx_idx: int = AudioServer.get_bus_index("SFX")
	_assert(sfx_idx >= 0, "SFX bus still exists on desktop")
	_assert(not AudioServer.is_bus_mute(sfx_idx), "desktop unlock does not mute SFX")


func _test_play_stays_wav() -> void:
	SfxNode.play("ui")
	var players: Dictionary = SfxNode.get("_players") as Dictionary
	var player: AudioStreamPlayer = players.get("ui") as AudioStreamPlayer
	_assert(player != null, "play creates an AudioStreamPlayer")
	if player == null:
		return
	_assert(player.stream is AudioStreamWAV, "SFX stays on AudioStreamWAV buffers")
	_assert(player.bus == "SFX", "desktop SFX still uses the SFX bus")
	_assert(
		player.playback_type == AudioServer.PLAYBACK_TYPE_DEFAULT,
		"desktop keeps default playback type"
	)


func _assert(ok: bool, label: String) -> void:
	if ok:
		_passed += 1
		print("PASS  %s" % label)
	else:
		_failed += 1
		print("FAIL  %s" % label)
