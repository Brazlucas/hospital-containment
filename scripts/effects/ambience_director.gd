class_name AmbienceDirector
extends Node
## Gives each wave its own atmosphere (AmbiencePreset): the room's base light, the lamps' colour and flicker
## style, the fog and the strength of the player's torch. Changes fade over the preset's `transition`.
## The room's light also dips for a blink now and then, like failing fluorescent tubes.

var target := Color.WHITE  ## the ambient colour the current preset asks for (tweened)

var _ambient: CanvasModulate
var _lamps: Array[Lamp] = []
var _fog: Fog
var _torch: PointLight2D
var _preset: AmbiencePreset
var _flick := 1.0
var _tween: Tween


func setup(ambient: CanvasModulate, lamps: Array[Lamp], fog: Fog, torch: PointLight2D) -> void:
	_ambient = ambient
	_lamps = lamps
	_fog = fog
	_torch = torch


func apply(preset: AmbiencePreset, instant := false) -> void:
	if preset == null:
		return
	_preset = preset
	for lamp in _lamps:
		lamp.style = preset.light_style
	if _tween:
		_tween.kill()
	if instant or preset.transition <= 0.0:
		target = preset.ambient
		for lamp in _lamps:
			lamp.tint = preset.light_tint
			lamp.energy_mult = preset.light_energy
		_fog.density = preset.fog_density
		_fog.color = preset.fog_color
		_torch.energy = preset.torch_energy
		_torch.texture_scale = preset.torch_scale
	else:
		var t := preset.transition
		_tween = create_tween().set_parallel()
		_tween.tween_property(self, "target", preset.ambient, t)
		for lamp in _lamps:
			_tween.tween_property(lamp, "tint", preset.light_tint, t)
			_tween.tween_property(lamp, "energy_mult", preset.light_energy, t)
		_tween.tween_property(_fog, "density", preset.fog_density, t)
		_tween.tween_property(_fog, "color", preset.fog_color, t)
		_tween.tween_property(_torch, "energy", preset.torch_energy, t)
		_tween.tween_property(_torch, "texture_scale", preset.torch_scale, t)
	AudioManager.play_ambient_loop(preset.loop_sfx, preset.loop_volume_db, preset.transition)
	Events.weather_changed.emit(preset.rain, preset.lightning)
	Events.ambience_changed.emit(preset.display_name)


func _process(delta: float) -> void:
	if _ambient == null:
		return
	if _preset and _preset.ambient_flicker and randf() < 0.03:
		_flick = randf_range(0.75, 1.0)
	_flick = lerpf(_flick, 1.0, minf(1.0, delta * 12.0))
	_ambient.color = Color(target.r * _flick, target.g * _flick, target.b * _flick, 1.0)
