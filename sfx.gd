extends Node

## Call Sfx.play("hit_dirt"). Placeholder beeps until real audio lands.

const _TONES := {
	"hit_dirt": Vector3(190.0, 0.045, 0.22),
	"hit_packed": Vector3(150.0, 0.05, 0.24),
	"hit_clay": Vector3(120.0, 0.06, 0.26),
	"hit_rock": Vector3(80.0, 0.08, 0.30),
	"layer_clear": Vector3(310.0, 0.04, 0.16),
	"fossil_ping": Vector3(880.0, 0.16, 0.28),
	"extract": Vector3(523.0, 0.28, 0.32),
	"ui": Vector3(440.0, 0.05, 0.18),
	"crack": Vector3(70.0, 0.07, 0.2),
}

var _players: Dictionary = {}


func play(id: String) -> void:
	var tone: Vector3 = _TONES.get(id, Vector3(220.0, 0.05, 0.2))
	var player: AudioStreamPlayer = _players.get(id)
	if player == null:
		player = AudioStreamPlayer.new()
		player.stream = _make_beep(tone.x, tone.y, tone.z)
		add_child(player)
		_players[id] = player
	player.pitch_scale = randf_range(0.94, 1.06)
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
