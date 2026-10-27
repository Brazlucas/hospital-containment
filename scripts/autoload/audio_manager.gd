extends Node
## One-shot SFX (and, later, music). Missing files are ignored, so content can be added before its sound exists.
## Drop files in assets/audio/ and call play_sfx("file_name_without_extension").

const AUDIO_DIR := "res://assets/audio/"
const EXTENSIONS := ["ogg", "wav", "mp3"]
const MAX_VOICES := 24  ## SFX playing at once; extra ones are dropped (rapid fire, many deaths)

var _cache := {}
var _voices := 0


func _ready() -> void:
	for bus in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)


func find_stream(sound: String) -> AudioStream:
	if _cache.has(sound):
		return _cache[sound]
	var stream: AudioStream = null
	for ext in EXTENSIONS:
		var path := "%s%s.%s" % [AUDIO_DIR, sound, ext]
		if ResourceLoader.exists(path):
			stream = load(path)
			break
	_cache[sound] = stream
	return stream


## `pitch_variation` = +/- fraction of random pitch, so repeated sounds do not feel machine-gunned.
func play_sfx(sound: String, volume_db := 0.0, pitch_variation := 0.0) -> void:
	var stream := find_stream(sound)
	if stream == null or _voices >= MAX_VOICES:
		return
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
	p.bus = &"SFX"
	add_child(p)
	_voices += 1
	p.finished.connect(func():
		_voices -= 1
		p.queue_free())
	p.play()
