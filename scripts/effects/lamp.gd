class_name Lamp
extends PointLight2D
## A ceiling lamp: a soft light that flickers in one of several styles. The AmbienceDirector retints it and
## switches its style per wave (steady, flickering, frantic, or a pulsing alarm siren).

enum Style { STEADY, FLICKER, FRANTIC, SIREN }

const LIGHT_TEX: Texture2D = preload("res://resources/textures/light_radial.tres")
## Brightness of one FLICKER burst as {time: factor}, linearly interpolated: dips to 30%, recovers, dips again.
const BURST: Array[Vector2] = [Vector2(0.0, 1.0), Vector2(0.05, 0.3), Vector2(0.13, 1.0), Vector2(0.17, 0.55), Vector2(0.27, 1.0)]

var style := Style.FLICKER
var base_color := Color(0.82, 0.95, 0.88)
var base_energy := 0.7
var tint := Color.WHITE  ## multiplied into base_color
var energy_mult := 1.0

var _t := 0.0  ## game time since the lamp was made (the siren must follow the game's clock, not the wall clock)
var _next_burst := 0.0
var _burst_t := -1.0
var _frantic_left := 0.0
var _frantic_factor := 1.0


func configure(light: ArenaLight, art_scale: float) -> void:
	texture = LIGHT_TEX
	position = light.position * art_scale
	base_color = light.color
	base_energy = light.energy
	texture_scale = light.texture_scale
	_next_burst = randf_range(0.5, 4.0)


func _process(delta: float) -> void:
	color = base_color * tint
	energy = base_energy * energy_mult * _factor(delta)


func _factor(delta: float) -> float:
	_t += delta
	match style:
		Style.FLICKER:
			if _burst_t < 0.0:
				_next_burst -= delta
				if _next_burst <= 0.0:
					_burst_t = 0.0
				return 1.0
			_burst_t += delta
			if _burst_t >= BURST.back().x:
				_burst_t = -1.0
				_next_burst = randf_range(0.5, 4.0)
				return 1.0
			for i in range(1, BURST.size()):
				if _burst_t < BURST[i].x:
					return lerpf(BURST[i - 1].y, BURST[i].y, (_burst_t - BURST[i - 1].x) / (BURST[i].x - BURST[i - 1].x))
			return 1.0
		Style.FRANTIC:  # non-stop violent flicker: random, never settles
			_frantic_left -= delta
			if _frantic_left <= 0.0:
				_frantic_left = randf_range(0.02, 0.12)
				_frantic_factor = randf_range(0.0, 0.15) if randf() < 0.45 else randf_range(0.6, 1.3)
			return _frantic_factor
		Style.SIREN:  # every lamp pulses together, like an emergency light
			var s := 0.5 + 0.5 * sin(_t * TAU * 0.8)
			return 0.12 + 0.88 * s * s
	return 1.0
