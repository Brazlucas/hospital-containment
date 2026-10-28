extends Node
## One-shot SFX (and, later, music). Missing files are ignored, so content can be added before its sound exists.
## Drop files in assets/audio/ and call play_sfx("file_name_without_extension").

const AUDIO_DIR := "res://assets/audio/"
const EXTENSIONS := ["ogg", "wav", "mp3"]
const MAX_VOICES := 24  ## SFX playing at once; extra ones are dropped (rapid fire, many deaths)
const SILENT_DB := -60.0
const SFX_BUS_DB := -4.0  ## master level of every SFX (shots, blows, deaths, UI)

var _cache := {}
var _voices := 0
var _music: AudioStreamPlayer
var _ambient_loop: AudioStreamPlayer  ## a wave's background sound (the alarm siren)
var _ambient_name := ""
var _ambient_tween: Tween


func _ready() -> void:
	for bus in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), SFX_BUS_DB)
	Events.run_ended.connect(func(_victory: bool): play_ambient_loop(""))


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
func play_sfx(sound: String, volume_db := 0.0, pitch_variation := 0.0, pitch := 1.0) -> void:
	var stream := find_stream(sound)
	if stream == null or _voices >= MAX_VOICES:
		return
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch * (1.0 + randf_range(-pitch_variation, pitch_variation))
	p.bus = &"SFX"
	add_child(p)
	_voices += 1
	p.finished.connect(func():
		_voices -= 1
		p.queue_free())
	p.play()


## Loops a track from assets/audio/ on the Music bus. Calling it again with the same track does nothing,
## so restarting the run does not restart the music.
func play_music(sound: String, volume_db := -16.0) -> void:
	var stream := find_stream(sound)
	if stream == null:
		return
	if _music == null:
		_music = AudioStreamPlayer.new()
		_music.bus = &"Music"
		add_child(_music)
	if _music.stream == stream and _music.playing:
		return
	_music.stream = _looped(stream)
	_music.volume_db = volume_db
	_music.play()


## Fades a looping background sound in (replacing the previous one); "" fades it out. Same sound again does nothing.
func play_ambient_loop(sound: String, volume_db := -12.0, fade := 1.5) -> void:
	if sound == _ambient_name:
		return
	_ambient_name = sound
	if _ambient_tween:
		_ambient_tween.kill()
	if _ambient_loop == null:
		_ambient_loop = AudioStreamPlayer.new()
		_ambient_loop.bus = &"SFX"
		add_child(_ambient_loop)
	_ambient_tween = create_tween()
	if _ambient_loop.playing:
		_ambient_tween.tween_property(_ambient_loop, "volume_db", SILENT_DB, maxf(fade, 0.05) * 0.5)
	var stream := find_stream(sound) if sound != "" else null
	if stream == null:
		_ambient_tween.tween_callback(_ambient_loop.stop)
		return
	_ambient_tween.tween_callback(func():
		_ambient_loop.stream = _looped(stream)
		_ambient_loop.volume_db = SILENT_DB
		_ambient_loop.play())
	_ambient_tween.tween_property(_ambient_loop, "volume_db", volume_db, maxf(fade, 0.05))


## Imported WAVs do not loop by default.
func _looped(stream: AudioStream) -> AudioStream:
	if stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		var bytes_per_frame := (2 if wav.format == AudioStreamWAV.FORMAT_16_BITS else 1) * (2 if wav.stereo else 1)
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = wav.data.size() / bytes_per_frame
	return stream

