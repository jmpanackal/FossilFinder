extends Node

## Call Sfx.play("hit_dirt"). Placeholder beeps until real audio lands.
## Web browsers start AudioContext suspended; unlock_web_audio() resumes it.

const _TONES := {
	"hit_dirt": Vector3(190.0, 0.05, 0.34),
	"hit_packed": Vector3(150.0, 0.055, 0.36),
	"hit_clay": Vector3(120.0, 0.065, 0.38),
	"hit_rock": Vector3(80.0, 0.09, 0.42),
	"tool_refuse": Vector3(210.0, 0.045, 0.46),
	"layer_clear": Vector3(310.0, 0.05, 0.24),
	"fossil_ping": Vector3(880.0, 0.18, 0.40),
	"extract": Vector3(523.0, 0.30, 0.42),
	"ui": Vector3(440.0, 0.05, 0.18),
	"crack": Vector3(70.0, 0.08, 0.34),
	"dust": Vector3(620.0, 0.04, 0.16),
	"sense": Vector3(740.0, 0.09, 0.20),
}

const _FANFARES := {
	"tool_refuse": [Vector3(240.0, 0.035, 0.44), Vector3(92.0, 0.09, 0.48)],
	"buy": [Vector3(523.0, 0.08, 0.30), Vector3(659.0, 0.14, 0.34)],
	"unlock": [Vector3(523.0, 0.07, 0.28), Vector3(659.0, 0.07, 0.30), Vector3(784.0, 0.20, 0.36)],
	"unveil": [Vector3(523.0, 0.07, 0.30), Vector3(659.0, 0.08, 0.32), Vector3(784.0, 0.10, 0.34), Vector3(1046.0, 0.22, 0.38)],
}

const BUS_SFX := "SFX"
const HIT_GAP_MSEC := 55
const _THROTTLED_IDS: PackedStringArray = [
	"hit_dirt",
	"hit_packed",
	"hit_clay",
	"hit_rock",
	"layer_clear",
]

var _players: Dictionary = {}
var hit_plays: int = 0
var last_id: String = ""
var _last_hit_msec: int = -99999
var _silent_player: AudioStreamPlayer


func reset_throttle() -> void:
	_last_hit_msec = -99999


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	ensure_bus()
	if not OS.has_feature("web"):
		return
	_silent_player = AudioStreamPlayer.new()
	_silent_player.bus = "Master"
	_silent_player.volume_db = -80.0
	_silent_player.process_mode = Node.PROCESS_MODE_ALWAYS
	_apply_web_playback(_silent_player)
	_silent_player.stream = _make_beep(40.0, 0.02, 0.0001)
	add_child(_silent_player)


func _input(event: InputEvent) -> void:
	if not OS.has_feature("web"):
		return
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.pressed:
			unlock_web_audio()
	elif event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo:
			unlock_web_audio()
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			unlock_web_audio()
	elif event is InputEventJoypadButton:
		var pad := event as InputEventJoypadButton
		if pad.pressed:
			unlock_web_audio()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_IN or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		unlock_web_audio()


func unlock_web_audio() -> void:
	if not OS.has_feature("web"):
		return
	_resume_audio_context()
	var master_idx: int = AudioServer.get_bus_index("Master")
	if master_idx >= 0:
		AudioServer.set_bus_mute(master_idx, false)
	ensure_bus()
	var sfx_idx: int = AudioServer.get_bus_index(BUS_SFX)
	if sfx_idx >= 0:
		AudioServer.set_bus_mute(sfx_idx, false)
	if _silent_player != null and not _silent_player.playing:
		_silent_player.play()


func _resume_audio_context() -> void:
	if not Engine.has_singleton("JavaScriptBridge"):
		return
	var js: Object = Engine.get_singleton("JavaScriptBridge")
	if js == null:
		return
	js.call(
		"eval",
		"(function(){var ctx=typeof GodotAudio!=='undefined'?GodotAudio.ctx:null;if(ctx&&ctx.state!=='running'&&ctx.resume){ctx.resume();}})();",
		true
	)


func _apply_web_playback(player: AudioStreamPlayer) -> void:
	if OS.has_feature("web"):
		player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM


func ensure_bus() -> void:
	if AudioServer.get_bus_index(BUS_SFX) >= 0:
		return
	var idx: int = AudioServer.bus_count
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, BUS_SFX)
	AudioServer.set_bus_send(idx, "Master")


func play(id: String, pitch: float = 1.0) -> void:
	last_id = id
	unlock_web_audio()
	ensure_bus()
	if _THROTTLED_IDS.has(id):
		var now: int = Time.get_ticks_msec()
		if now - _last_hit_msec < HIT_GAP_MSEC:
			return
		_last_hit_msec = now
		hit_plays += 1
	var player: AudioStreamPlayer = _players.get(id) as AudioStreamPlayer
	if player == null:
		player = AudioStreamPlayer.new()
		player.bus = BUS_SFX
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		_apply_web_playback(player)
		if _FANFARES.has(id):
			var notes: Array = _FANFARES[id]
			player.stream = _make_fanfare(notes)
		else:
			var tone: Vector3 = _TONES.get(id, Vector3(220.0, 0.05, 0.2))
			player.stream = _make_beep(tone.x, tone.y, tone.z)
		add_child(player)
		_players[id] = player
	player.pitch_scale = (randf_range(0.97, 1.03) if _FANFARES.has(id) else randf_range(0.94, 1.06)) * maxf(pitch, 0.1)
	player.play()


func _make_beep(freq: float, duration: float, volume: float) -> AudioStreamWAV:
	var sample_rate := 22050
	var count := int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		var t := float(i) / float(sample_rate)
		var envelope := 1.0 - t / duration
		var sample := int(sin(t * TAU * freq) * 32767.0 * volume * envelope)
		data[i * 2] = sample & 255
		data[i * 2 + 1] = (sample >> 8) & 255
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = data
	return stream


func _make_fanfare(notes: Array) -> AudioStreamWAV:
	var sample_rate := 22050
	var data := PackedByteArray()
	for raw in notes:
		var note: Vector3 = raw
		var freq: float = note.x
		var duration: float = note.y
		var volume: float = note.z
		var count := int(sample_rate * duration)
		var start := data.size()
		data.resize(start + count * 2)
		for i in count:
			var t := float(i) / float(sample_rate)
			var envelope := 1.0 - t / maxf(duration, 0.001)
			var attack := clampf(t / 0.012, 0.0, 1.0)
			var sample := int(sin(t * TAU * freq) * 32767.0 * volume * envelope * attack)
			data[start + i * 2] = sample & 255
			data[start + i * 2 + 1] = (sample >> 8) & 255
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = data
	return stream
