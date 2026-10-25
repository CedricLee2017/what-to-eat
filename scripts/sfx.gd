extends Node

## 即時合成嘅小音效，唔需要外部音檔，HTML5 都用得。

const RATE := 22050
const VOICES := 8

var muted := false

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	for i in VOICES:
		var player := AudioStreamPlayer.new()
		player.bus = "Master"
		add_child(player)
		_players.append(player)
	_load_settings()


func _build() -> void:
	_streams["click"] = _make([880.0], 0.10, 30.0, 0.22)
	_streams["open"] = _make([523.0, 784.0], 0.26, 16.0, 0.26)
	_streams["perfect"] = _make([784.0, 988.0, 1319.0], 0.55, 7.0, 0.30)
	_streams["good"] = _make([659.0, 880.0], 0.32, 11.0, 0.25)
	_streams["burnt"] = _make([150.0, 110.0], 0.42, 6.0, 0.30, 0.16)
	_streams["coin"] = _make([1047.0, 1568.0], 0.28, 14.0, 0.24)
	_streams["day"] = _make([523.0, 659.0, 784.0, 1047.0], 0.75, 5.0, 0.28)
	_streams["start"] = _make([392.0, 523.0, 659.0, 784.0], 0.65, 5.0, 0.26)


func _make(notes: Array, length: float, decay: float, volume: float, noise: float = 0.0) -> AudioStreamWAV:
	var count := int(RATE * length)
	var data := PackedByteArray()
	data.resize(count * 2)
	var random := RandomNumberGenerator.new()
	random.seed = 1234
	for i in count:
		var t := float(i) / RATE
		var sample := 0.0
		var fade_in := minf(1.0, t * 120.0)
		var fade_out := clampf((length - t) / 0.05, 0.0, 1.0)
		for n in range(notes.size()):
			var start := float(n) * 0.065
			var local := t - start
			if local >= 0.0 and local < 0.4:
				var frequency: float = notes[n]
				var envelope := exp(-local * decay)
				sample += sin(TAU * frequency * local) * envelope / float(notes.size())
		if noise > 0.0:
			sample += random.randf_range(-1.0, 1.0) * noise * exp(-t * 11.0)
		sample = clampf(sample * volume * fade_in * fade_out, -1.0, 1.0)
		data.encode_s16(i * 2, int(sample * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = data
	return stream


func play(sound_id: String) -> void:
	if muted or not _streams.has(sound_id):
		return
	var player := _players[_next]
	_next = (_next + 1) % _players.size()
	player.stream = _streams[sound_id]
	player.play()


func toggle_mute() -> bool:
	muted = not muted
	_save_settings()
	return muted


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load("user://settings.cfg") == OK:
		muted = bool(config.get_value("audio", "muted", false))


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "muted", muted)
	config.save("user://settings.cfg")
